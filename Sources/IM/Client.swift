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

        /// Session is about to open but not opened
        case opening

        /// Session is opened
        case opened

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

    private var isClosedByCaller = false

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

    /// The total count of opening completions.
    private var openingCompletionCount: UInt64 = 0

    /// A table of opening completion handler indexed by ID.
    private var openingCompletionTable: [UInt64: (LCBooleanResult) -> Void] = [:]

    /// Timeout interval of opening completion.
    private let openingCompletionTimeout: TimeInterval = 60

    /**
     Flush opening completions with result.

     - parameter result: The boolean result.
     */
    private func flushOpeningCompletions(with result: LCBooleanResult) {
        synchronize(on: self) {
            let openingCompletionTable = self.openingCompletionTable

            mainQueueAsync {
                openingCompletionTable.forEach { (_, completion) in
                    completion(result)
                }
            }

            self.openingCompletionTable = [:]
        }
    }

    /**
     Set timeout for an opening completion.

     - parameter id: The opening completion ID.
     */
    private func setTimeout(openingCompletionID id: UInt64) {
        let deadline: DispatchTime = .now() + openingCompletionTimeout

        sessionTimeoutDispatchQueue.asyncAfter(deadline: deadline) { [weak self] in
            guard let client = self else {
                return
            }
            client.fireTimeout(openingCompletionID: id)
        }
    }

    /**
     Fire timeout for an opening completion.

     - parameter id: The opening completion ID.
     */
    private func fireTimeout(openingCompletionID id: UInt64) {
        synchronize(on: self) {
            connection.setAutoReconnectionEnabled(with: false)

            guard let openingCompletion = openingCompletionTable.removeValue(forKey: id) else {
                return
            }
            mainQueueAsync {
                openingCompletion(.failure(error: SessionError.timedOut))
            }
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
            isClosedByCaller = false

            /* Enable auto-reconnection for opening WebSocket connection to send session command. */
            connection.setAutoReconnectionEnabled(with: true)

            let id = openingCompletionCount &+ 1

            /* Stash completion handler first. It will be called later. */
            openingCompletionTable[id] = completion
            openingCompletionCount = id

            /* Set timeout to ensure that completion handler can be called finally. */
            setTimeout(openingCompletionID: id)

            /* Flush completion handler if session is opened already.
               Otherwise, try to connect and open session. */
            switch sessionState {
            case .opened:
                flushOpeningCompletions(with: .success)
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
                resetAutoConnection()

                updateSessionState(.opened)

                if let delegate = delegate {
                    mainQueueAsync {
                        delegate.clientDidOpenSession(self)
                    }
                }

                processOpeningSessionIncomingCommand(command)

                flushOpeningCompletions(with: .success)
            }
        case .error(let error):
            let error = SessionError.error(error)

            synchronize(on: self) {
                /*
                 Disable auto-reconnection until session opened.
                 */
                connection.setAutoReconnectionEnabled(with: false)

                updateSessionState(.closed)

                if let delegate = delegate {
                    mainQueueAsync {
                        delegate.clientDidCloseSession(self, error: error)
                    }
                }

                flushOpeningCompletions(with: .failure(error: error))
            }
        }
    }

    /**
     Process incoming command for opening session.

     - parameter command: The opening session incoming command.
     */
    private func processOpeningSessionIncomingCommand(_ command: IMGenericCommand) {
        // TODO: Process Command
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

    /// Update session state.
    private func updateSessionState(_ sessionState: SessionState) {
        synchronize(on: self) {
            self.sessionState = sessionState
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

            switch error {
            case .closedByCaller:
                isClosedByCaller = true
                /*
                 Disable auto-reconnection if session is closed by caller.
                 The connection will closed by server after 1 minute.
                 */
                connection.setAutoReconnectionEnabled(with: false)
            default:
                break
            }

            updateSessionState(.closed)

            flushOpeningCompletions(with: .failure(error: error))

            if let delegate = delegate {
                mainQueueAsync {
                    delegate.clientDidCloseSession(self, error: error)
                }
            }
        }
    }

}

extension LCClient: ConnectionDelegate {

    func connectionInConnecting(connection: Connection) {
        synchronize(on: self) {
            if isClosedByCaller {
                return
            }
            updateSessionState(.opening)

            if let delegate = delegate {
                mainQueueAsync {
                    delegate.clientWillOpenSession(self)
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
     Notify that client will open session.

     - parameter client: The client who will open session.
     */
    func clientWillOpenSession(_ client: LCClient)

    /**
     Notify that client did open session.

     - parameter client: The client who did open session.
     */
    func clientDidOpenSession(_ client: LCClient)

    /**
     Notify that client did close session.

     - parameter client: The client who did close session.
     */
    func clientDidCloseSession(_ client: LCClient, error: LCClient.SessionError)

}

extension LCClientDelegate {

    func clientWillOpenSession(_ client: LCClient) {
        /* Nop */
    }

    func clientDidOpenSession(_ client: LCClient) {
        /* Nop */
    }

    func clientDidCloseSession(_ client: LCClient, error: LCClient.SessionError) {
        /* Nop */
    }

}
