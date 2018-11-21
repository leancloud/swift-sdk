//
//  Client.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/11/13.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

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

        /// Manage session state manually.
        public static let manageSessionStateManually = Options(rawValue: 1 << 0)

        /// Receive unread message count after session did open.
        public static let receiveUnreadMessageCountAfterSessionDidOpen = Options(rawValue: 1 << 1)

        /// Get IM protocol for current options.
        var lcimProtocol: Connection.LCIMProtocol {
            if contains(.receiveUnreadMessageCountAfterSessionDidOpen) {
                return .protobuf3
            } else {
                return .protobuf1
            }
        }

        /// Get if session should reconnect automatically.
        var isAutoReconnectionEnabled: Bool {
            if contains(.manageSessionStateManually) {
                return false
            } else {
                return true
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

        /// Session is closed
        case closed

    }

    /**
     Client session error.
     */
    public enum SessionError: Error {

        /// Closed by caller.
        case closedByCaller

        /// Network is unavailable.
        case networkUnavailable

        /// Application did enter background.
        case applicationDidEnterBackground

        /// The opening operation is timed out.
        case timedOut

        /// Other error, like websocket error or LeanCloud error.
        case error(Error)

        init(event: Connection.Event) {
            switch event {
            case .disconnectInvoked:
                self = .closedByCaller
            case .appInBackground:
                self = .applicationDidEnterBackground
            case .networkNotReachable, .networkChanged:
                self = .networkUnavailable
            case .error(let error):
                self = .error(error)
            }
        }

    }

    /// The client identifier.
    public let id: String

    /// The client tag, which represents what kind of session that current client will open.
    /// For two sessions of one client with same tag, the later one will force to make previous one offline.
    public let tag: String?

    /// The client options.
    public let options: Options

    /// The application that the client belongs to.
    public let application: LCApplication

    /// The custom server URL.
    public let customServer: URL?

    /// The client session state.
    public var sessionState: SessionState = .closed

    /// If session is closed by caller
    private var isClosedByCaller = false

    /// The incoming command of opening session.
    private var openingSessionIncomingCommand: IMGenericCommand?

    /// Should delegate session state.
    private var shouldDelegateSessionState: Bool {
        return synchronize(on: self) {
            /* Only delegate session state after session did open. */
            return openingSessionIncomingCommand != nil
        }
    }

    /// The delegate object.
    public weak var delegate: LCClientDelegate?

    /// The client serial dispatch queue.
    private let serialDispatchQueue = DispatchQueue(
        label: "LeanCloud.ClientSerialDispatchQueue",
        qos: .userInteractive)

    /// The timeout dispatch queue.
    private let sessionTimeoutDispatchQueue = DispatchQueue(
        label: "LeanCloud.ClientSessionTimeoutDispatchQueue",
        qos: .userInteractive,
        attributes: .concurrent)

    /// The session connection.
    private lazy var connection = Connection(
        application: application,
        delegate: self,
        lcimProtocol: options.lcimProtocol,
        customRTMServer: customServer?.absoluteString,
        delegateQueue: serialDispatchQueue,
        isAutoReconnectionEnabled: false)

    /**
     Initialize client with identifier and tag.

     - parameter id: The client identifier.
     - parameter tag: The client tag.
     - parameter options: The client options.
     - parameter customServer: The custom server URL for private deployment.
     - parameter application: The application that the client belongs to.
     */
    public init(
        id: String,
        tag: String? = nil,
        options: Options = .default,
        customServer: URL? = nil,
        application: LCApplication = .default)
    {
        self.id = id
        self.tag = tag
        self.options = options
        self.customServer = customServer
        self.application = application
    }

    /// The opening completion.
    private var openingCompletion: ((LCBooleanResult) -> Void)?

    /// Timeout interval of opening completion.
    private let openingCompletionTimeout: TimeInterval = 60

    /**
     Call opening completion with result.

     It will also reset the opening completion to ensure that it can be called only once.

     - parameter result: The boolean result.
     */
    private func callOpeningCompletion(with result: LCBooleanResult) {
        synchronize(on: self) {
            guard let openingCompletion = openingCompletion else {
                return
            }

            self.openingCompletion = nil

            mainQueueAsync {
                openingCompletion(result)
            }
        }
    }

    /**
     Set timeout for opening completion.
     */
    private func setTimeoutForOpeningCompletion() {
        let deadline: DispatchTime = .now() + openingCompletionTimeout

        sessionTimeoutDispatchQueue.asyncAfter(deadline: deadline) { [weak self] in
            guard let client = self else {
                return
            }
            client.fireTimeoutForOpeningCompletion()
        }
    }

    /**
     Fire timeout for opening completion.
     */
    private func fireTimeoutForOpeningCompletion() {
        synchronize(on: self) {
            connection.setAutoReconnectionEnabled(with: false)

            callOpeningCompletion(with: .failure(error: SessionError.timedOut))
        }
    }

    /**
     Reset auto-reconnection.
     */
    private func resetAutoConnection() {
        connection.setAutoReconnectionEnabled(with: options.isAutoReconnectionEnabled)
    }

    /**
     Open a session to IM system.

     A client cannot do anything before a session did open successfully.

     - parameter completion: The completion handler.
     */
    public func open(completion: @escaping (LCBooleanResult) -> Void) {
        synchronize(on: self) {
            guard openingCompletion == nil else {
                let error = LCError(
                    code: .inconsistency,
                    reason: "Cannot open session before previous operation finish.")

                mainQueueAsync {
                    completion(.failure(error: error))
                }

                return
            }

            openingCompletion = completion

            isClosedByCaller = false

            openingSessionIncomingCommand = nil

            /* Enable auto-reconnection for opening WebSocket connection to send session command. */
            connection.setAutoReconnectionEnabled(with: true)

            /* Set timeout to ensure that completion handler can be called finally. */
            setTimeoutForOpeningCompletion()

            /* Call completion handler directly if session is opened already.
               Otherwise, try to connect and open session. */
            switch sessionState {
            case .opened:
                callOpeningCompletion(with: .success)
            default:
                connection.connect()
            }
        }
    }

    /**
     Open a session to RTM server.

     - parameter completion: The completion handler.
     */
    private func openSession(completion: @escaping (LCClient, Connection.CommandCallback.Result) -> Void) {
        sendCommand(
        constructor: { (client, command) in
            command.cmd = .session
            command.op = .open

            var sessionCommand = IMSessionCommand()

            sessionCommand.deviceToken = UUID().uuidString
            sessionCommand.ua = HTTPClient.default.configuration.userAgent

            command.sessionMessage = sessionCommand
        },
        completion: completion)
    }

    /**
     Process the result of opening session.

     - parameter result: The result of opening session.
     */
    private func processOpeningSessionResult(_ result: Connection.CommandCallback.Result) {
        switch result {
        case .inCommand(let command):
            synchronize(on: self) {
                processOpeningSessionIncomingCommand(command)

                resetAutoConnection()

                if updateSessionState(.opened) {
                    if let delegate = delegate {
                        mainQueueAsync {
                            delegate.clientDidOpenSession(self)
                        }
                    }
                }

                callOpeningCompletion(with: .success)
            }
        case .error(let error):
            let error = SessionError.error(error)

            synchronize(on: self) {
                /*
                 Disable auto-reconnection until session opened.
                 */
                connection.setAutoReconnectionEnabled(with: false)

                if updateSessionState(.closed) {
                    if let delegate = delegate {
                        mainQueueAsync {
                            delegate.clientDidCloseSession(self, error: error)
                        }
                    }
                }

                callOpeningCompletion(with: .failure(error: error))
            }
        }
    }

    /**
     Process incoming command for opening session.

     - parameter command: The opening session incoming command.
     */
    private func processOpeningSessionIncomingCommand(_ command: IMGenericCommand) {
        synchronize(on: self) {
            openingSessionIncomingCommand = command
        }
    }

    /**
     Enqueue serial task asynchronously.

     - parameter task: The task to be enqueued.
     */
    private func enqueueSerialTask(_ task: @escaping (LCClient) -> Void) {
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
    private func sendCommand(
        constructor: @escaping (LCClient, inout IMGenericCommand) -> Void,
        completion: @escaping (LCClient, Connection.CommandCallback.Result) -> Void)
    {
        enqueueSerialTask { client in
            var command = IMGenericCommand()

            let application = client.application
            let connection = client.connection

            /*
             Set common fields that every command will carry.
             */
            command.appID = application.id
            command.peerID = client.id

            constructor(client, &command)

            connection.send(command: command) { [weak client] result in
                guard let client = client else {
                    return
                }
                completion(client, result)
            }
        }
    }

    /*
     Update session state.

     - parameter sessionState: The new session state.
     */
    private func updateSessionState(_ sessionState: SessionState) -> Bool {
        return synchronize(on: self) {
            guard shouldDelegateSessionState else {
                return false
            }

            // TODO: Validate State Transition

            self.sessionState = sessionState

            return true
        }
    }

    /**
     Close with completion handler.

     - parameter completion: The completion handler.
     */
    public func close(completion: @escaping (LCBooleanResult) -> Void) {
        sendCommand(
        constructor: { (client, command) in
            command.cmd = .session
            command.op = .close
        },
        completion: { (client, result) in
            client.processClosingSessionResult(result, completion: completion)
        })
    }

    /**
     Process closing session result.

     - parameter result: The closing session result.
     - parameter completion: The completion handler.
     */
    private func processClosingSessionResult(
        _ result: Connection.CommandCallback.Result,
        completion: @escaping (LCBooleanResult) -> Void)
    {
        switch result {
        case .error(let error):
            mainQueueAsync {
                completion(.failure(error: error))
            }
        case .inCommand:
            sessionDidCloseWithError(.closedByCaller)

            mainQueueAsync {
                completion(.success)
            }
        }
    }

    /**
     Notify closed state with error.

     - parameter error: The session error.
     */
    private func sessionDidCloseWithError(_ error: SessionError) {
        synchronize(on: self) {
            if isClosedByCaller {
                return
            }

            if updateSessionState(.closed) {
                if let delegate = delegate {
                    mainQueueAsync {
                        delegate.clientDidCloseSession(self, error: error)
                    }
                }
            }

            switch error {
            case .closedByCaller:
                isClosedByCaller = true

                openingSessionIncomingCommand = nil

                /* Disable auto-reconnection if session is closed by caller. */
                connection.setAutoReconnectionEnabled(with: false)
            default:
                break
            }

            callOpeningCompletion(with: .failure(error: error))
        }
    }

}

extension LCClient: ConnectionDelegate {

    func connectionInConnecting(connection: Connection) {
        synchronize(on: self) {
            if isClosedByCaller {
                return
            }
            if updateSessionState(.resuming) {
                if let delegate = delegate {
                    mainQueueAsync {
                        delegate.clientDidBecomeResumeSession(self)
                    }
                }
            }
        }
    }

    func connectionDidConnect(connection: Connection) {
        synchronize(on: self) {
            if isClosedByCaller {
                return
            }
            openSession { (client, result) in
                client.processOpeningSessionResult(result)
            }
        }
    }

    func connection(connection: Connection, didFailInConnecting event: Connection.Event) {
        sessionDidCloseWithError(SessionError(event: event))
    }

    func connection(connection: Connection, didDisconnect event: Connection.Event) {
        sessionDidCloseWithError(SessionError(event: event))
    }

    func connection(connection: Connection, didReceiveCommand inCommand: IMGenericCommand) {
        // TODO: Process Command
    }

}

public protocol LCClientDelegate: NSObjectProtocol {

    /**
     Notify that client did open session.

     - parameter client: The client who did open session.
     */
    func clientDidOpenSession(_ client: LCClient)

    /**
     Notify that client did become resume session.

     - parameter client: The client who did become resume session.
     */
    func clientDidBecomeResumeSession(_ client: LCClient)

    /**
     Notify that client did close session.

     - parameter client: The client who did close session.
     */
    func clientDidCloseSession(_ client: LCClient, error: LCClient.SessionError)

}

extension LCClientDelegate {

    func clientDidOpenSession(_ client: LCClient) {
        /* Nop */
    }

    func clientDidBecomeResumeSession(_ client: LCClient) {
        /* Nop */
    }

    func clientDidCloseSession(_ client: LCClient, error: LCClient.SessionError) {
        /* Nop */
    }

}
