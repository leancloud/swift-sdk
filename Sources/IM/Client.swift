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
#elseif os(macOS)
import IOKit
#endif

/**
 An LCClient represents an entity which can send and receive messages in IM system.
 
 Clients and messages are organized by conversation, that is, a client can only send and receive messages in context of conversation.
 */
public final class LCClient {
    
    /// length range of client ID.
    public static let lengthRangeOfClientID = 1...64
    
    /// reserved value of tag
    public static let reservedValueOfTag: String = "default"
    
    #if DEBUG
    /// for unit test
    internal static let TestReportDeviceTokenNotification = Notification.Name.init("TestReportDeviceTokenNotification")
    #endif
    
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
     Options that can modify behaviors of session open operation.
     */
    public struct SessionOpenOptions: OptionSet {
        
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Default options is forced.
        public static let `default`: SessionOpenOptions = [.forced]
        
        /// For two sessions of one client with same tag, the later one will force to make previous one offline.
        public static let forced = SessionOpenOptions(rawValue: 1 << 0)
        
        var r: Bool { return !contains(.forced) }
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
    
    /// The client identifier.
    public let id: String
    
    /// The client tag, which represents what kind of session that current client will open.
    /// @related `SessionOpenOptions`
    public let tag: String?
    
    /// The client options.
    public let options: Options
    
    /// The application that the client belongs to.
    public let application: LCApplication
    
    /// Application's current installation
    internal let installation: LCInstallation
    
    /// The delegate object.
    public weak var delegate: LCClientDelegate?
    
    /// The dispatch queue on which the event about IM are called. Default is main.
    public let eventQueue: DispatchQueue
    
    /// The custom server URL.
    public let customServer: URL?
    
    /// The client session state.
    public private(set) var sessionState: SessionState {
        set(newValue) {
            self.mutex.lock()
            self.underlyingSessionState = newValue
            self.mutex.unlock()
        }
        get {
            let value: SessionState
            self.mutex.lock()
            value = self.underlyingSessionState
            self.mutex.unlock()
            return value
        }
    }
    private var underlyingSessionState: SessionState = .closed
    private var isSessionOpened: Bool {
        return self.sessionState == .opened
    }
    
    /// The client serial dispatch queue.
    private let serialQueue = DispatchQueue(label: "LeanCloud.LCClient.serialQueue", qos: .userInitiated)
    
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
    
    /// Internal mutex
    private let mutex = NSLock()
    
    /// Initialize client with identifier and tag.
    ///
    /// - Parameters:
    ///   - id: The client identifier. Length should in [1...64].
    ///   - tag: The client tag. "default" string should not be used.
    ///   - options: @see `LCClient.Options`.
    ///   - delegate: @see `LCClientDelegate`.
    ///   - eventQueue: @see property `eventQueue`, default is main.
    ///   - timeoutInterval: timeout interval of command.
    ///   - customServer: The custom server URL for private deployment.
    ///   - application: The application that the client belongs to.
    /// - Throws: if `id` or `tag` invalid, then throw error.
    public init(
        id: String,
        tag: String? = nil,
        options: Options = .default,
        delegate: LCClientDelegate? = nil,
        eventQueue: DispatchQueue = .main,
        timeoutInterval: TimeInterval = 30.0,
        customServer: URL? = nil,
        application: LCApplication = .default)
        throws
    {
        guard LCClient.lengthRangeOfClientID.contains(id.count) else {
            throw LCError(
                code: .inconsistency,
                reason: "Length of client ID should in \(LCClient.lengthRangeOfClientID)"
            )
        }
        guard tag != LCClient.reservedValueOfTag else {
            throw LCError(
                code: .inconsistency,
                reason: "\"\(LCClient.reservedValueOfTag)\" string should not be used on tag"
            )
        }
        #if DEBUG
        self.serialQueue.setSpecific(key: self.specificKey, value: self.specificValue)
        #endif
        self.id = id
        self.tag = tag
        self.options = options
        self.delegate = delegate
        self.eventQueue = eventQueue
        self.customServer = customServer
        self.application = application
        self.installation = application.currentInstallation
        // directly init `connection` is better, lazy init is not a good choice.
        // because connection should get App State in main thread.
        self.connection = Connection(
            application: application,
            lcimProtocol: options.lcimProtocol,
            delegateQueue: self.serialQueue,
            commandTTL: timeoutInterval,
            customRTMServerURL: customServer
        )
        self.deviceTokenObservation = self.installation.observe(
            \.deviceToken,
            options: [.old, .new, .initial]
        ) { [weak self] (_, change) in
            let oldToken: String? = change.oldValue??.value
            let newToken: String? = change.newValue??.value
            guard let token: String = newToken, oldToken != newToken else {
                return
            }
            self?.serialQueue.async {
                guard let self = self, self.currentDeviceToken != token else {
                    return
                }
                self.currentDeviceToken = token
                self.report(deviceToken: token)
            }
        }
    }
    
    /// Session Token & Opening Config
    private var sessionToken: String?
    private var sessionTokenExpiration: Date?
    private var openingCompletion: ((LCBooleanResult) -> Void)?
    private var openingOptions: SessionOpenOptions?
    
    /// Device Token and fallback-UDID
    private var deviceTokenObservation: NSKeyValueObservation?
    private var currentDeviceToken: String?
    private lazy var fallbackUDID: String = {
        var udid: String = UUID().uuidString
        #if os(iOS) || os(tvOS)
        if let identifierForVendor: String = UIDevice.current.identifierForVendor?.uuidString {
            udid = identifierForVendor
        }
        #elseif os(macOS)
        let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice") )
        if let serialNumber: String = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String {
            udid = serialNumber
        }
        IOObjectRelease(platformExpert)
        #endif
        return udid
    }()
    
    // MARK: - Open & Close
    
    /**
     Open a session to IM system.
     
     - parameter options: @see `LCClient.SessionOpenOptions`.
     - parameter completion: The completion handler.
     */
    public func open(options: SessionOpenOptions = .default, completion: @escaping (LCBooleanResult) -> Void) {
        self.serialQueue.async {
            guard self.openingCompletion == nil && self.sessionToken == nil else {
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
            self.openingOptions = options
            
            /* Enable auto-reconnection for opening WebSocket connection to send session command. */
            self.connection.delegate = self
            self.connection.connect()
        }
    }
    
    /**
     Close with completion handler.
     
     - parameter completion: The completion handler.
     */
    public func close(completion: @escaping (LCBooleanResult) -> Void) {
        self.serialQueue.async {
            guard self.isSessionOpened else {
                var error: LCError
                if self.sessionState == .closing {
                    error = LCError(
                        code: .inconsistency,
                        reason: "In closing, cannot do repetitive operation."
                    )
                } else {
                    error = LCError(code: .clientNotOpen)
                }
                self.eventQueue.async {
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
                    if inCommand.check(type: .session, op: .closed) {
                        self.sessionClosed(with: .success, completion: completion)
                    } else {
                        self.eventQueue.async {
                            let error = LCError(code: .commandInvalid)
                            completion(.failure(error: error))
                        }
                    }
                case .error(let error):
                    self.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            }
        }
    }
    
    // MARK: - Create Conversation

    /**
     Create a normal conversation.

     - parameter clientIds: An array of client ID.
     - parameter attributes: The initial conversation attributes.
     - parameter isUnique: A flag indicates whether create an unique conversation.
     - parameter completion: The completion handler.
     */
    public func createConversation(
        clientIds: [String],
        attributes: LCDictionary? = nil,
        isUnique: Bool = true,
        completion: @escaping (LCGenericResult<LCConversation>) -> Void)
    {
        createConversation(
            clientIds: clientIds,
            attributes: attributes,
            option: isUnique ? .normalAndUnique : .normal,
            completion: completion)
    }

    /**
     Create a chat room conversation.

     - parameter clientIds: An array of client ID.
     - parameter attributes: The initial conversation attributes.
     - parameter completion: The completion handler.
     */
    public func createChatRoomConversation(
        clientIds: [String],
        attributes: LCDictionary? = nil,
        completion: @escaping (LCGenericResult<LCChatRoomConversation>) -> Void)
    {
        createConversation(
            clientIds: clientIds,
            attributes: attributes,
            option: .transient,
            completion: completion)
    }

    /**
     Create a temporary conversation.

     - parameter clientIds: An array of client ID.
     - parameter attributes: The initial conversation attributes.
     - parameter timeToLive: The time to live, in seconds.
     - parameter completion: The completion handler.
     */
    public func createTemporaryConversation(
        clientIds: [String],
        attributes: LCDictionary? = nil,
        timeToLive: Int32,
        completion: @escaping (LCGenericResult<LCTemporaryConversation>) -> Void)
    {
        createConversation(
            clientIds: clientIds,
            attributes: attributes,
            option: .temporary(ttl: timeToLive),
            completion: completion)
    }

    /**
     Conversation creation option.
     */
    private enum ConversationCreationOption {

        /// Normal conversation.
        case normal

        /// Normal and unique conversation.
        case normalAndUnique

        /// Transient conversation.
        case transient

        /// Temporary conversation.
        case temporary(ttl: Int32)

    }

    /**
     Create a conversation with creation option.

     - parameter clientIds: An array of client ID.
     - parameter attributes: The initial conversation attributes.
     - parameter option: The conversation creation option.
     - parameter completion: The completion handler.
     */
    private func createConversation<T: LCConversation>(
        clientIds: [String],
        attributes: LCDictionary? = nil,
        option: ConversationCreationOption,
        completion: @escaping (LCGenericResult<T>) -> Void)
    {
        let clientIds = Array(Set(clientIds))

        // Validate each client ID.
        for clientId in clientIds {
            guard LCClient.lengthRangeOfClientID.contains(clientId.count) else {
                eventQueue.async {
                    let error = LCError(code: .malformedData, reason: "Invalid client ID.")
                    completion(.failure(error: error))
                }
                return
            }
        }

        sendCommand(
        constructor: { (client, command) in
            command.cmd = .conv
            command.op = .start

            var convMessage = IMConvCommand()

            switch option {
            case .normal:
                break
            case .normalAndUnique:
                convMessage.unique = true
            case .transient:
                convMessage.transient = true
            case .temporary(let ttl):
                convMessage.tempConv = true

                if ttl > 0 {
                    convMessage.tempConvTtl = ttl
                }
            }

            convMessage.m = clientIds

            if let attributes = attributes {
                var attrMessage = IMJsonObjectMessage()

                attrMessage.data = attributes.jsonString
                convMessage.attr = attrMessage
            }

            command.convMessage = convMessage
        },
        completion: { (client, result, outcomingCommand) in
            switch result {
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            case .inCommand(let incomingCommand):
                do {
                    let conversation: T = try client.createConversation(
                        incomingConvCommand: incomingCommand.convMessage,
                        outcomingConvCommand: outcomingCommand.convMessage,
                        attributes: attributes)

                    client.eventQueue.async {
                        completion(.success(value: conversation))
                    }
                } catch let error as LCError {
                    client.eventQueue.async {
                        completion(.failure(error: error))
                    }
                } catch let error {
                    let error = LCError(underlyingError: error)

                    client.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            }
        })
    }

    /**
     Create conversation object.
     */
    func createConversation<T: LCConversation>(
        incomingConvCommand: IMConvCommand,
        outcomingConvCommand: IMConvCommand,
        attributes: LCDictionary?) throws -> T
    {
        guard incomingConvCommand.hasCid else {
            throw LCError(
                code: .commandInvalid,
                reason: "Failed to create conversation.")
        }

        let conversation: LCConversation
        let objectId = incomingConvCommand.cid

        if outcomingConvCommand.transient {
            conversation = LCChatRoomConversation(id: objectId)
        } else if outcomingConvCommand.tempConv {
            conversation = LCTemporaryConversation(id: objectId)
        } else {
            conversation = LCConversation(id: objectId)
        }

        conversation.client = self

        if incomingConvCommand.hasCdate {
            conversation.createdAt = LCDate(isoString: incomingConvCommand.cdate)?.value
        }

        // TODO: Assign attributes to conversation.

        guard let result = conversation as? T else {
            throw LCError(
                code: .inconsistency,
                reason: "Failed to create conversation.")
        }

        return result
    }
    
}

extension LCClient {
    
    /**
     Enqueue serial task asynchronously.
     
     - parameter task: The task to be enqueued.
     */
    func enqueueSerialTask(_ task: @escaping (LCClient) -> Void) {
        serialQueue.async { [weak self] in
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
        completion: @escaping (LCClient, Connection.CommandCallback.Result, IMGenericCommand) -> Void)
    {
        enqueueSerialTask { client in
            
            var command = IMGenericCommand()

            command.appID = client.application.id
            command.peerID = client.id
            
            constructor(client, &command)

            guard client.isSessionOpened else {
                let error = LCError(code: .clientNotOpen)
                completion(client, .error(error), command)
                return
            }
            
            client.connection.send(command: command) { [weak client] result in
                guard let client = client else {
                    return
                }
                completion(client, result, command)
            }
        }
    }
    
}

private extension LCClient {
    
    private func newOpenCommand() -> IMGenericCommand {
        assert(self.specificAssertion)
        var outCommand = IMGenericCommand()
        outCommand.cmd = .session
        outCommand.op = .open
        outCommand.appID = self.application.id
        outCommand.peerID = self.id
        var sessionCommand = IMSessionCommand()
        sessionCommand.deviceToken = self.currentDeviceToken ?? self.fallbackUDID
        sessionCommand.ua = HTTPClient.default.configuration.userAgent
        if let tag: String = self.tag {
            sessionCommand.tag = tag
        }
        outCommand.sessionMessage = sessionCommand
        return outCommand
    }
    
    private func send(reopenCommand command: IMGenericCommand) {
        assert(self.specificAssertion)
        self.connection.send(command: command) { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .inCommand(let inCommand):
                self.handle(openCommandCallback: inCommand)
            case .error(let error):
                if error.code == LCError.InternalErrorCode.commandTimeout.rawValue {
                    self.send(reopenCommand: command)
                } else if error.code == LCError.ServerErrorCode.sessionTokenExpired.rawValue {
                    var openCommand = self.newOpenCommand()
                    openCommand.sessionMessage.r = true
                    self.send(reopenCommand: openCommand)
                } else {
                    Logger.shared.debug(error)
                }
            }
        }
    }
    
    private func report(deviceToken token: String?, openCommand: IMGenericCommand? = nil) {
        assert(self.specificAssertion)
        guard let token: String = token, self.isSessionOpened else {
            return
        }
        if let openCommand = openCommand {
            // if Device-Token changed in Opening-Period, reporting after open success.
            guard openCommand.sessionMessage.deviceToken != token else {
                return
            }
        }
        var outCommand = IMGenericCommand()
        outCommand.cmd = .report
        outCommand.op = .upload
        var reportCommand = IMReportCommand()
        reportCommand.initiative = true
        reportCommand.type = "token"
        reportCommand.data = token
        outCommand.reportMessage = reportCommand
        self.connection.send(command: outCommand) { result in
            #if DEBUG
            /// for unit test
            NotificationCenter.default.post(
                name: LCClient.TestReportDeviceTokenNotification,
                object: self,
                userInfo: ["result" : result]
            )
            #endif
        }
    }
    
    private func handle(openCommandCallback command: IMGenericCommand, completion: ((LCBooleanResult) -> Void)? = nil) {
        assert(self.specificAssertion)
        switch (command.cmd, command.op) {
        case (.session, .opened):
            let sessionMessage = command.sessionMessage
            if sessionMessage.hasSt && sessionMessage.hasStTtl {
                self.sessionToken = sessionMessage.st
                self.sessionTokenExpiration = Date(timeIntervalSinceNow: TimeInterval(sessionMessage.stTtl))
            }
            if let _ = completion {
                self.connection.setAutoReconnectionEnabled(true)
            }
            self.sessionState = .opened
            self.eventQueue.async {
                if let completion = completion {
                    completion(.success)
                } else {
                    self.delegate?.client(didOpenSession: self)
                }
            }
        case (.session, .closed):
            let sessionMessage = command.sessionMessage
            self.process(sessionClosedCommand: sessionMessage, completion: completion)
        default:
            let error = LCError(code: .commandInvalid)
            self.sessionClosed(with: .failure(error: error), completion: completion)
        }
    }
    
    private func sessionClosed(with result: LCBooleanResult, completion: ((LCBooleanResult) -> Void)? = nil) {
        assert(self.specificAssertion)
        self.connection.delegate = nil
        self.connection.setAutoReconnectionEnabled(false)
        self.connection.disconnect()
        self.sessionToken = nil
        self.sessionTokenExpiration = nil
        self.openingCompletion = nil
        self.openingOptions = nil
        self.sessionState = .closed
        self.eventQueue.async {
            if let completion = completion {
                completion(result)
            } else if let error = result.error {
                self.delegate?.client(self, didCloseSession: error)
            }
        }
    }
    
    private func process(sessionClosedCommand sessionCommand: IMSessionCommand, completion: ((LCBooleanResult) -> Void)? = nil) {
        assert(self.specificAssertion)
        let code: Int = Int(sessionCommand.code)
        let reason: String? = (sessionCommand.hasReason ? sessionCommand.reason : nil)
        let userInfo: LCError.UserInfo? = (sessionCommand.hasDetail ? ["detail" : sessionCommand.detail] : nil)
        let error = LCError(code: code, reason: reason, userInfo: userInfo)
        self.sessionClosed(with: .failure(error: error), completion: completion)
    }
    
}

extension LCClient: ConnectionDelegate {
    
    func connection(inConnecting connection: Connection) {
        assert(self.specificAssertion)
        guard let _ = self.sessionToken, self.sessionState != .resuming else {
            return
        }
        self.sessionState = .resuming
        self.eventQueue.async {
            self.delegate?.client(didBecomeResumeSession: self)
        }
    }
    
    func connection(didConnect connection: Connection) {
        assert(self.specificAssertion)
        var openCommand = self.newOpenCommand()
        if let openingCompletion = self.openingCompletion,
            let openingOptions = self.openingOptions
        {
            openCommand.sessionMessage.r = openingOptions.r
            self.connection.send(command: openCommand) { [weak self] (result) in
                guard let self = self else { return }
                self.openingCompletion = nil
                self.openingOptions = nil
                switch result {
                case .inCommand(let inCommand):
                    self.handle(openCommandCallback: inCommand, completion: openingCompletion)
                    self.report(deviceToken: self.currentDeviceToken, openCommand: openCommand)
                case .error(let error):
                    self.eventQueue.async {
                        openingCompletion(.failure(error: error))
                    }
                }
            }
        }
        else if let sessionToken = self.sessionToken
        {
            openCommand.sessionMessage.r = true
            openCommand.sessionMessage.st = sessionToken
            self.send(reopenCommand: openCommand)
        }
    }
    
    func connection(_ connection: Connection, didDisconnect error: LCError) {
        assert(self.specificAssertion)
        let routerError = LCError.malformedRTMRouterResponse
        if error.code == routerError.code, error.reason == routerError.reason {
            self.sessionClosed(with: .failure(error: error), completion: self.openingCompletion)
        } else if let openingCompletion = self.openingCompletion {
            self.sessionClosed(with: .failure(error: error), completion: openingCompletion)
        } else if let _ = self.sessionToken, self.sessionState != .paused {
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
                self.process(sessionClosedCommand: inCommand.sessionMessage)
            default:
                break
            }
        default:
            break
        }
    }
    
}

public protocol LCClientDelegate: class {
    
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
