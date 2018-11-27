//
//  Client.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/11/13.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif

/**
 An LCClient represents an entity which can send and receive messages in IM system.
 
 Clients and messages are organized by conversation, that is, a client can only send and receive messages in context of conversation.
 */
public final class LCClient: NSObject {
    
    /**
     Options that can modify behaviors of client.
     */
    public struct Options: OptionSet {
        
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Default options.
        public static let `default`: Options = []
        
        /// Receive unread message count after session did open.
        public static let receiveUnreadMessageCountAfterSessionDidOpen = Options(rawValue: 1 << 0)
        
        /// Get IM protocol for current options.
        var lcimProtocol: Connection.LCIMProtocol {
            if contains(.receiveUnreadMessageCountAfterSessionDidOpen) {
                return .protobuf3
            } else {
                return .protobuf1
            }
        }
        
    }
    
    /**
     Client session state.
     */
    public enum SessionState {
        
        /// Session is opened
        case opened
        
        /// Session is resuming
        case resuming
        
        /// Session is paused
        case paused
        
        /// Session is closing
        case closing
        
        /// Session is closed
        case closed
        
    }
    
    /**
     Client session open action for Single-Device-Login mode.
     @related tag property
     */
    public enum SessionOpenAction {
        
        /// In Single-Device-Online mode, this action always success
        case force
        
        /// In Single-Device-Online mode, this action may fail
        case resume
        
    }
    
    /// The client identifier.
    public let id: String
    
    /// The client tag, which represents what kind of session that current client will open.
    /// For two sessions of one client with same tag, the later one will force to make previous one offline.
    /// @related `SessionOpenAction`
    public let tag: String?
    
    /// The client options.
    public let options: Options
    
    /// The application that the client belongs to.
    public let application: LCApplication
    
    /// The delegate object.
    public weak var delegate: LCClientDelegate?
    
    /// The dispatch queue on which the event about IM are called. Default is main.
    public let eventQueue: DispatchQueue
    
    /// The custom server URL.
    public let customServer: URL?
    
    /// The client session state.
    public private(set) var sessionState: SessionState {
        set(newValue) {
            synchronize(on: self) {
                self.underlyingSessionState = newValue
            }
        }
        get {
            return self.underlyingSessionState
        }
    }
    private var underlyingSessionState: SessionState = .closed
    
    /// The client serial dispatch queue.
    private let serialDispatchQueue = DispatchQueue(
        label: "LeanCloud.ClientSerialDispatchQueue",
        qos: .userInteractive)
    
    #if DEBUG
    private let specificKey = DispatchSpecificKey<Int>()
    // whatever random Int is OK.
    private let specificValue: Int = Int.random(in: 1...999)
    private var specificAssertion: Bool {
        return self.specificValue == DispatchQueue.getSpecific(key: self.specificKey)
    }
    #else
    private var specificAssertion: Bool {
        return true
    }
    #endif
    
    /// The session connection.
    private let connection: Connection
    
    /**
     Initialize client with identifier and tag.
     
     - parameter id: The client identifier. Length should in [1...64].
     - parameter tag: The client tag. "default" string should not be used.
     - parameter options: The client options.
     - parameter eventQueue: @see property `eventQueue`, default is main.
     - parameter customServer: The custom server URL for private deployment.
     - parameter application: The application that the client belongs to.
     */
    public init(
        id: String,
        tag: String? = nil,
        options: Options = .default,
        delegate: LCClientDelegate? = nil,
        eventQueue: DispatchQueue = .main,
        customServer: URL? = nil,
        application: LCApplication = .default)
        throws
    {
        guard !id.isEmpty && id.count <= 64 else {
            throw LCError(code: .inconsistency, reason: "Length of client identifier should in [1...64]")
        }
        guard tag != "default" else {
            throw LCError(code: .inconsistency, reason: "\"default\" string should not be used on tag")
        }
        #if DEBUG
        self.serialDispatchQueue.setSpecific(key: self.specificKey, value: self.specificValue)
        #endif
        self.id = id
        self.tag = tag
        self.options = options
        self.delegate = delegate
        self.eventQueue = eventQueue
        self.customServer = customServer
        self.application = application
        self.connection = Connection(
            application: application,
            lcimProtocol: options.lcimProtocol,
            delegateQueue: serialDispatchQueue,
            customRTMServerURL: customServer)
    }
    
    /// The incoming command of opening session.
    private var sessionOpenedCommand: IMSessionCommand?
    
    /// Should delegate session state.
    private var shouldDelegateSessionState: Bool {
        assert(self.specificAssertion)
        return self.sessionOpenedCommand != nil
    }
    
    /// Some config about opening
    private var openingCompletion: ((LCBooleanResult) -> Void)?
    private var openingTimeoutWorkItem: DispatchWorkItem?
    private var openingAction: SessionOpenAction?
    
    /**
     Open a session to IM system.
     
     - parameter action: @see `SessionOpenAction`, default is force.
     - parameter timeout: Timeout for opening, default is 60 seconds.
     - parameter completion: The completion handler.
     */
    public func open(action: SessionOpenAction = .force, timeout: TimeInterval = 60.0, completion: @escaping (LCBooleanResult) -> Void) {
        self.serialDispatchQueue.async {
            guard self.openingCompletion == nil && self.sessionOpenedCommand == nil else {
                var reason: String = "cannot do repetitive operation."
                if let _ = self.openingCompletion {
                    reason = "In opening, \(reason)"
                } else {
                    reason = "Session did opened, \(reason)"
                }
                self.eventQueue.async {
                    let error = LCError(code: .inconsistency, reason: reason)
                    completion(.failure(error: error))
                }
                return
            }
            
            self.openingCompletion = completion
            self.openingAction = action
            
            let timeoutWorkItem = DispatchWorkItem() { [weak self] in
                guard let self = self, let openingCompletion = self.openingCompletion else {
                    return
                }
                self.clearOpeningConfig()
                let error = LCError(code: .commandTimeout, reason: "Session open operation timed out.")
                self.sessionClosed(with: .failure(error: error), completion: openingCompletion)
            }
            self.openingTimeoutWorkItem = timeoutWorkItem
            self.serialDispatchQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
            
            /* Enable auto-reconnection for opening WebSocket connection to send session command. */
            self.connection.delegate = self
            self.connection.setAutoReconnectionEnabled(true)
            self.connection.connect()
        }
    }
    
    /**
     Close with completion handler.
     
     - parameter completion: The completion handler.
     */
    public func close(completion: @escaping (LCBooleanResult) -> Void) {
        self.serialDispatchQueue.async {
            guard self.sessionState == .opened else {
                var reason: String
                if self.sessionState == .closing {
                    reason = "In closing, cannot do repetitive operation."
                } else {
                    reason = "Session not opened."
                }
                self.eventQueue.async {
                    let error = LCError(code: .inconsistency, reason: reason)
                    completion(.failure(error: error))
                }
                return
            }
            
            self.sessionState = .closing
            
            var outCommand = IMGenericCommand()
            outCommand.cmd = .session
            outCommand.op = .close
            outCommand.sessionMessage = IMSessionCommand()
            
            self.connection.send(command: outCommand) { [weak self] (result) in
                guard let self = self else {
                    return
                }
                switch result {
                case .inCommand(let inCommand):
                    if inCommand.cmd == .session && inCommand.op == .closed {
                        self.sessionClosed(with: .success, completion: completion)
                    } else {
                        let error = LCError(code: .commandInvalid)
                        self.sessionClosed(with: .failure(error: error), completion: completion)
                    }
                case .error(let error):
                    self.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            }
        }
    }
    
}

internal extension LCClient {
    
    /**
     Enqueue serial task asynchronously.
     
     - parameter task: The task to be enqueued.
     */
    func enqueueSerialTask(_ task: @escaping (LCClient) -> Void) {
        serialDispatchQueue.async { [weak self] in
            guard let client = self else {
                return
            }
            task(client)
        }
    }
    
    /**
     Send a command to server side.
     
     - parameter constructor: The command constructor.
     - parameter completion: The completion handler.
     */
    func sendCommand(
        constructor: @escaping (LCClient, inout IMGenericCommand) -> Void,
        completion: @escaping (LCClient, Connection.CommandCallback.Result) -> Void)
    {
        enqueueSerialTask { client in
            
            guard self.sessionState == .opened else {
                let error = LCError(code: .clientNotOpen)
                completion(client, .error(error))
                return
            }
            
            var command = IMGenericCommand()
            
            constructor(client, &command)
            
            client.connection.send(command: command) { [weak client] result in
                guard let client = client else {
                    return
                }
                completion(client, result)
            }
        }
    }
    
}

private extension LCClient {
    
    private func clearOpeningConfig() {
        assert(self.specificAssertion)
        self.openingTimeoutWorkItem?.cancel()
        self.openingTimeoutWorkItem = nil
        self.openingCompletion = nil
        self.openingAction = nil
    }
    
    private func newOpenCommand() -> IMGenericCommand {
        assert(self.specificAssertion)
        var outCommand = IMGenericCommand()
        outCommand.cmd = .session
        outCommand.op = .open
        outCommand.appID = self.application.id
        outCommand.peerID = self.id
        var sessionCommand = IMSessionCommand()
        outCommand.sessionMessage = sessionCommand
        #if os(iOS) || os(tvOS)
        sessionCommand.deviceToken = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        sessionCommand.deviceID = UUID().uuidString
        #endif
        sessionCommand.ua = HTTPClient.default.configuration.userAgent
        if let tag: String = self.tag {
            sessionCommand.tag = tag
        }
        return outCommand
    }
    
    private func handle(openCommandCallback inCommand: IMGenericCommand, openingCompletion: ((LCBooleanResult) -> Void)?) {
        assert(self.specificAssertion)
        if inCommand.cmd == .session && inCommand.hasSessionMessage {
            let sessionCommand: IMSessionCommand = inCommand.sessionMessage
            if inCommand.op == .opened && sessionCommand.hasSt && sessionCommand.hasStTtl {
                self.sessionOpenedCommand = sessionCommand
                self.sessionState = .opened
                self.eventQueue.async {
                    if let completion = openingCompletion {
                        completion(.success)
                    } else {
                        self.delegate?.client(didOpenSession: self)
                    }
                }
                return
            } else if inCommand.op == .closed {
                self.process(sessionClosedCommand: sessionCommand, completion: openingCompletion)
                return
            }
        }
        let error = LCError(code: .commandInvalid)
        self.sessionClosed(with: .failure(error: error), completion: openingCompletion)
    }
    
    private func sessionClosed(with result: LCBooleanResult, completion: ((LCBooleanResult) -> Void)?) {
        assert(self.specificAssertion)
        self.connection.delegate = nil
        self.connection.setAutoReconnectionEnabled(false)
        self.connection.disconnect()
        self.sessionOpenedCommand = nil
        self.sessionState = .closed
        self.eventQueue.async {
            if let completion = completion {
                completion(result)
            } else if let error = result.error {
                self.delegate?.client(self, didCloseSession: error)
            }
        }
    }
    
    private func process(sessionClosedCommand sessionCommand: IMSessionCommand, completion: ((LCBooleanResult) -> Void)?) {
        assert(self.specificAssertion)
        let code: Int = Int(sessionCommand.code)
        let reason: String = sessionCommand.reason
        let userInfo: LCError.UserInfo? = (sessionCommand.hasDetail ? ["detail" : sessionCommand.detail] : nil)
        let error = LCError(code: code, reason: reason, userInfo: userInfo)
        self.sessionClosed(with: .failure(error: error), completion: completion)
    }
    
}

extension LCClient: ConnectionDelegate {
    
    func connection(inConnecting connection: Connection) {
        assert(self.specificAssertion)
        guard shouldDelegateSessionState, self.sessionState != .resuming else {
            return
        }
        self.sessionState = .resuming
        self.eventQueue.async {
            self.delegate?.client(didBecomeResumeSession: self)
        }
    }
    
    func connection(didConnect connection: Connection) {
        assert(self.specificAssertion)
        var openCommand: IMGenericCommand = self.newOpenCommand()
        if let _ = self.openingCompletion, let openingAction = self.openingAction {
            openCommand.sessionMessage.r = (openingAction == .resume)
            self.connection.send(command: openCommand) { [weak self] (result) in
                guard let self = self, let openingCompletion = self.openingCompletion else {
                    return
                }
                switch result {
                case .inCommand(let inCommand):
                    self.clearOpeningConfig()
                    self.handle(openCommandCallback: inCommand, openingCompletion: openingCompletion)
                case .error(let error):
                    // no need handle it, just log info.
                    Logger.shared.debug(error)
                }
            }
        } else if let currentSessionOpenedCommand: IMSessionCommand = self.sessionOpenedCommand {
            openCommand.sessionMessage.r = true
            openCommand.sessionMessage.st = currentSessionOpenedCommand.st
            self.connection.send(command: openCommand) { [weak self] (result) in
                guard let self = self else {
                    return
                }
                switch result {
                case .inCommand(let inCommand):
                    self.handle(openCommandCallback: inCommand, openingCompletion: nil)
                case .error(let error):
                    // no need handle it, just log info.
                    Logger.shared.debug(error)
                }
            }
        }
    }
    
    func connection(_ connection: Connection, didDisconnect error: LCError) {
        assert(self.specificAssertion)
        let routerError = LCError.malformedRTMRouterResponse
        if error.code == routerError.code && error.reason == routerError.reason {
            let openingCompletion = self.openingCompletion
            self.clearOpeningConfig()
            self.sessionClosed(with: .failure(error: error), completion: openingCompletion)
        } else if self.shouldDelegateSessionState {
            self.sessionState = .paused
            self.eventQueue.async {
                self.delegate?.client(self, didPauseSession: error)
            }
        }
    }
    
    func connection(_ connection: Connection, didReceiveCommand inCommand: IMGenericCommand) {
        assert(self.specificAssertion)
        switch inCommand.cmd {
        case .session:
            switch inCommand.op {
            case .closed:
                self.process(sessionClosedCommand: inCommand.sessionMessage, completion: nil)
            default:
                break
            }
        default:
            break
        }
    }
    
}

public protocol LCClientDelegate: NSObjectProtocol {
    
    /**
     Notify that client did open session.
     
     - parameter client: The client who did open session.
     */
    func client(didOpenSession client: LCClient)
    
    /**
     Notify that client did become resume session.
     
     - parameter client: The client who did become resume session.
     */
    func client(didBecomeResumeSession client: LCClient)
    
    /**
     Notify that client did pause session.
     
     - parameter client: The client who did close session.
     - parameter error: Reason of pause.
     */
    func client(_ client: LCClient, didPauseSession error: LCError)
    
    /**
     Notify that client did close session.
     
     - parameter client: The client who did close session.
     - parameter error: Reason of close.
     */
    func client(_ client: LCClient, didCloseSession error: LCError)
    
}

extension LCClientDelegate {
    
    func client(didOpenSession client: LCClient) {
        /* Nop */
    }
    
    func client(didBecomeResumeSession client: LCClient) {
        /* Nop */
    }
    
    func client(_ client: LCClient, didPauseSession error: LCError) {
        /* Nop */
    }
    
    func client(_ client: LCClient, didCloseSession error: LCError) {
        /* Nop */
    }
    
}
