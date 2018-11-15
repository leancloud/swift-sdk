//
//  Connection.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2018/10/17.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif
import Alamofire

protocol ConnectionDelegate: class {
    
    /// Invoked when websocket is connecting server.
    func connectionInConnecting(connection: Connection)
    
    /// Invoked when websocket connected server.
    func connectionDidConnect(connection: Connection)
    
    /// Invoked when encounter some can't-start-websocket-connecting event or websocket connecting failed.
    ///
    /// - Parameters:
    ///   - event: @see Connection.Event
    func connection(connection: Connection, didFailInConnecting event: Connection.Event)
    
    /// Invoked when the connected websocket encounter some should-disconnect event or other network error.
    ///
    /// - Parameters:
    ///   - event: @see Connection.Event
    func connection(connection: Connection, didDisconnect event: Connection.Event)
    
    /// Invoked when the connected websocket receive direct-in-protobuf-command.
    ///
    /// - Parameters:
    ///   - inCommand: protobuf-command without serial ID.
    func connection(connection: Connection, didReceiveCommand inCommand: IMGenericCommand)
}

class Connection {
    
    /// ref: https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md#传输协议
    enum LCIMProtocol: String {
        case protobuf1 = "lc.protobuf2.1"
        case protobuf3 = "lc.protobuf2.3"
    }
    
    /// Event for ConnectionDelegate
    ///
    /// - disconnectInvoked: The connected or in-connecting Connection-Instance was invoked disconnect().
    /// - appInBackground: The connected or in-connecting Connection-Instance was disconencted due to APP enter background, or Connection-Instance can't start connecting.
    /// - networkNotReachable: The connected or in-connecting Connection-Instance was disconencted due to network not reachable, or Connection-Instance can't start connecting.
    /// - networkChanged: The connected or in-connecting Connection-Instance was disconencted due to network's primary interface changed.
    /// - error: maybe LeanCloud error, websocket error or other network error.
    enum Event {
        case disconnectInvoked
        case appInBackground
        case networkNotReachable
        case networkChanged
        case error(Error)
    }
    
    /// private for Connection Class but internal for test, so should never use it.
    class CommandCallback {
        
        enum Result {
            case inCommand(IMGenericCommand)
            case error(LCError)
        }
        
        let closure: ((Result) -> Void)
        let timeoutTimestamp: TimeInterval
        
        init(closure: @escaping ((Result) -> Void), timeToLive: TimeInterval) {
            self.closure = closure
            self.timeoutTimestamp = Date().timeIntervalSince1970 + timeToLive
        }
        
    }
    
    /// private for Connection Class but internal for test, so should never use it.
    class Timer {
        
        let pingpongInterval: TimeInterval
        let pingTimeout: TimeInterval
        
        private let source: DispatchSourceTimer
        private let commandCallbackQueue: DispatchQueue
        
        init(timerQueue: DispatchQueue,
             commandCallbackQueue: DispatchQueue,
             pingpongInterval: TimeInterval = 180.0,
             pingTimeout: TimeInterval = 20.0,
             pingSentClosure: @escaping ((Timer) -> Void))
        {
            self.pingpongInterval = pingpongInterval
            self.pingTimeout = pingTimeout
            self.source = DispatchSource.makeTimerSource(queue: timerQueue)
            self.commandCallbackQueue = commandCallbackQueue
            self.pingSentClosure = pingSentClosure
            self.source.schedule(deadline: .now(), repeating: .seconds(1))
            self.source.setEventHandler { [weak self] in
                let currentTimestamp: TimeInterval = Date().timeIntervalSince1970
                self?.check(commandTimeout: currentTimestamp)
                self?.check(pingPong: currentTimestamp)
            }
            self.source.resume()
        }
        
        func cancel() {
            self.source.cancel()
            let values: Dictionary<UInt16, CommandCallback>.Values = self.commandCallbackCollection.values
            if values.count > 0 {
                self.commandCallbackQueue.async {
                    let error = LCError(code: .connectionLost)
                    for item in values {
                        item.closure(.error(error))
                    }
                }
            }
        }
        
        private(set) var commandIndexSequence: [UInt16] = []
        private(set) var commandCallbackCollection: [UInt16 : CommandCallback] = [:]
        
        func insert(commandCallback: CommandCallback, index: UInt16) {
            self.commandIndexSequence.append(index)
            self.commandCallbackCollection[index] = commandCallback
        }
        
        func handle(callbackCommand command: IMGenericCommand) {
            let i: Int32 = (command.hasI ? command.i : 0)
            guard i > 0 && i <= UInt16.max else {
                return
            }
            let indexKey: UInt16 = UInt16(i)
            guard let commandCallback: CommandCallback = self.commandCallbackCollection.removeValue(forKey: indexKey) else {
                return
            }
            if let index: Int = self.commandIndexSequence.firstIndex(of: indexKey) {
                self.commandIndexSequence.remove(at: index)
            }
            self.commandCallbackQueue.async {
                commandCallback.closure(.inCommand(command))
            }
        }
        
        private func check(commandTimeout currentTimestamp: TimeInterval) {
            var length: Int = 0
            for indexKey in self.commandIndexSequence {
                length += 1
                guard let commandCallback: CommandCallback = self.commandCallbackCollection[indexKey] else {
                    continue
                }
                if commandCallback.timeoutTimestamp > currentTimestamp  {
                    length -= 1
                    break
                } else {
                    self.commandCallbackCollection.removeValue(forKey: indexKey)
                    self.commandCallbackQueue.async {
                        let error = LCError(code: .commandTimeout)
                        commandCallback.closure(.error(error))
                    }
                }
            }
            if length > 0 {
                self.commandIndexSequence.removeSubrange(0..<length)
            }
        }
        
        private(set) var lastPingSentTimestamp: TimeInterval = 0
        var lastPongReceivedTimestamp: TimeInterval = 0
        private let pingSentClosure: ((Timer) -> Void)
        
        private func check(pingPong currentTimestamp: TimeInterval) {
            let isPingSentAndPongNotReceived: Bool = (self.lastPingSentTimestamp > self.lastPongReceivedTimestamp)
            let lastPingTimeout: Bool = (isPingSentAndPongNotReceived && currentTimestamp > self.lastPingSentTimestamp + self.pingTimeout)
            let shouldNextPingPong: Bool = (!isPingSentAndPongNotReceived && currentTimestamp > self.lastPongReceivedTimestamp + self.pingpongInterval)
            if lastPingTimeout || shouldNextPingPong {
                self.pingSentClosure(self)
                self.lastPingSentTimestamp = currentTimestamp
            }
        }
        
    }
    
    let application: LCApplication
    weak var delegate: ConnectionDelegate?
    let lcimProtocol: LCIMProtocol
    let customRTMServer: String?
    let delegateQueue: DispatchQueue
    let commandTTL: TimeInterval
    
    let rtmRouter: RTMRouter
    
    private let serialQueue: DispatchQueue = DispatchQueue(label: "LeanCloud.Connection.serialQueue")
    private var socket: WebSocket? = nil
    private var timer: Timer? = nil
    private var isAutoReconnectionEnabled: Bool = false
    private var useSecondaryServer: Bool = false
    private var serialIndex: UInt16 = 1
    private var nextSerialIndex: UInt16 {
        let index: UInt16 = self.serialIndex
        if index == UInt16.max {
            self.serialIndex = 1
        } else {
            self.serialIndex += 1
        }
        return index
    }
    
    #if os(iOS) || os(tvOS)
    private enum AppState {
        case background
        case foreground
    }
    private var previousAppState: AppState = .foreground
    private var enterBackgroundObserver: NSObjectProtocol!
    private var enterForegroundObserver: NSObjectProtocol!
    #endif
    #if !os(watchOS)
    private var previousReachabilityStatus: NetworkReachabilityManager.NetworkReachabilityStatus = .unknown
    private var reachabilityManager: NetworkReachabilityManager? = nil
    #endif
    
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
    
    /// Initialization function.
    ///
    /// - Parameters:
    ///   - application: LeanCloud Application, @see LCApplication.
    ///   - delegate: @see ConnectionDelegate.
    ///   - lcimProtocol: @see LCIMProtocol.
    ///   - customRTMServer: The custom RTM server, if set, Connection will ignore RTM Router, if not set, Connection will use the server return by RTM Router.
    ///   - delegateQueue: The queue where ConnectionDelegate's fuctions and command's callback be invoked.
    ///   - commandTTL: Time-To-Live of command's callback.
    init(application: LCApplication,
         delegate: ConnectionDelegate,
         lcimProtocol: LCIMProtocol,
         customRTMServer: String? = nil,
         delegateQueue: DispatchQueue = .main,
         commandTTL: TimeInterval = 30.0,
         isAutoReconnectionEnabled: Bool = true)
    {
        #if DEBUG
        self.serialQueue.setSpecific(key: self.specificKey, value: self.specificValue)
        #endif
        self.application = application
        self.delegate = delegate
        self.lcimProtocol = lcimProtocol
        self.customRTMServer = customRTMServer
        self.delegateQueue = delegateQueue
        self.commandTTL = commandTTL
        self.isAutoReconnectionEnabled = isAutoReconnectionEnabled
        
        self.rtmRouter = RTMRouter(application: application)
        
        #if os(iOS) || os(tvOS)
        self.previousAppState = mainQueueSync {
            (UIApplication.shared.applicationState == .background ? .background : .foreground)
        }
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = self.serialQueue
        self.enterBackgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: operationQueue) { [weak self] _ in
            Logger.shared.verbose("Application did enter background")
            self?.applicationStateChanged(with: .background)
        }
        self.enterForegroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: operationQueue) { [weak self] _ in
            Logger.shared.verbose("Application will enter foreground")
            self?.applicationStateChanged(with: .foreground)
        }
        #endif
        
        #if !os(watchOS)
        self.reachabilityManager = NetworkReachabilityManager()
        self.previousReachabilityStatus = self.reachabilityManager?.networkReachabilityStatus ?? .unknown
        self.reachabilityManager?.listenerQueue = self.serialQueue
        self.reachabilityManager?.listener = { [weak self] newStatus in
            Logger.shared.verbose("Network status change to \(newStatus)")
            self?.networkReachabilityStatusChanged(with: newStatus)
        }
        self.reachabilityManager?.startListening()
        #endif
    }
    
    deinit {
        #if os(iOS) || os(tvOS)
        NotificationCenter.default.removeObserver(self.enterBackgroundObserver)
        NotificationCenter.default.removeObserver(self.enterForegroundObserver)
        #endif
        #if !os(watchOS)
        self.reachabilityManager?.stopListening()
        #endif
        self.socket?.disconnect()
        self.timer?.cancel()
    }
    
    /// Try connecting RTM server, if websocket exists and auto reconnection is enabled, then this action will be ignored.
    func connect() {
        self.serialQueue.async {
            if self.socket != nil && self.isAutoReconnectionEnabled {
                return
            }
            self.tryConnecting()
        }
    }
    
    /// Switch for auto reconnection.
    func setAutoReconnectionEnabled(with enabled: Bool) {
        self.serialQueue.async {
            self.isAutoReconnectionEnabled = enabled
        }
    }
    
    /// Try close websocket, cancel timer and purge command callback.
    func disconnect() {
        self.serialQueue.async {
            self.tryClearConnection(with: .disconnectInvoked)
        }
    }
    
    /// Send Command.
    ///
    /// - Parameters:
    ///   - command: Out Command.
    ///   - callback: If set, the out command will has a serial-ID and callback will be added into waiting queue.
    func send(command: IMGenericCommand, callback: ((CommandCallback.Result) -> Void)? = nil) {
        self.serialQueue.async {
            guard let socket: WebSocket = self.socket, let timer: Timer = self.timer else {
                if let callback = callback {
                    self.delegateQueue.async {
                        let error = LCError(code: .connectionLost)
                        callback(.error(error))
                    }
                }
                return
            }
            var outCommand = command
            if callback != nil {
                outCommand.i = Int32(self.nextSerialIndex)
            }
            let serializedData: Data
            do {
                serializedData = try outCommand.serializedData()
            } catch {
                Logger.shared.error(error)
                if let callback = callback {
                    self.delegateQueue.async {
                        let serializingError = LCError(underlyingError: error)
                        callback(.error(serializingError))
                    }
                }
                return
            }
            guard serializedData.count <= 5000 else {
                if let callback = callback {
                    self.delegateQueue.async {
                        let error = LCError(code: .commandDataLengthTooLong)
                        callback(.error(error))
                    }
                }
                return
            }
            if let callback = callback {
                let commandCallback = CommandCallback(closure: callback, timeToLive: self.commandTTL)
                let index: UInt16 = UInt16(outCommand.i)
                timer.insert(commandCallback: commandCallback, index: index)
            }
            socket.write(data: serializedData) {
                Logger.shared.debug("\n\n------ BEGIN LeanCloud Out Command\n\(socket)\n\(outCommand)------ END\n")
            }
        }
    }
    
}

// MARK: - Private

extension Connection {
    
    #if os(iOS) || os(tvOS)
    private func applicationStateChanged(with newState: Connection.AppState) {
        assert(self.specificAssertion)
        let oldState: AppState = self.previousAppState
        self.previousAppState = newState
        switch (oldState, newState) {
        case (.background, .foreground):
            if self.isAutoReconnectionEnabled {
                self.tryConnecting()
            }
        case (.foreground, .background):
            self.tryClearConnection(with: .appInBackground)
        default:
            break
        }
    }
    #endif
    
    #if !os(watchOS)
    private func networkReachabilityStatusChanged(with newStatus: NetworkReachabilityManager.NetworkReachabilityStatus) {
        assert(self.specificAssertion)
        let oldStatus = self.previousReachabilityStatus
        self.previousReachabilityStatus = newStatus
        if oldStatus != .notReachable && newStatus == .notReachable {
            self.tryClearConnection(with: .networkNotReachable)
        } else if oldStatus != newStatus && newStatus != .notReachable {
            self.tryClearConnection(with: .networkChanged)
            if self.isAutoReconnectionEnabled {
                self.tryConnecting()
            }
        }
    }
    #endif
    
    private func checkIfCanDoConnecting() -> Event? {
        assert(self.specificAssertion)
        #if os(iOS) || os(tvOS)
        guard self.previousAppState == .foreground else {
            return Event.appInBackground
        }
        #endif
        #if !os(watchOS)
        guard self.previousReachabilityStatus != .notReachable else {
            return Event.networkNotReachable
        }
        #endif
        return nil
    }
    
    private func tryConnecting() {
        assert(self.specificAssertion)
        self.getRTMServer { (result: LCGenericResult<URL>) in
            assert(self.specificAssertion)
            guard self.socket == nil else {
                // if socket exists, means in connecting or did connect.
                return
            }
            if let cannotEvent: Event = self.checkIfCanDoConnecting() {
                self.delegateQueue.async {
                    self.delegate?.connection(connection: self, didFailInConnecting: cannotEvent)
                }
            } else {
                switch result {
                case .success(value: let url):
                    let socket = WebSocket(url: url, protocols: [self.lcimProtocol.rawValue])
                    socket.delegate = self
                    socket.pongDelegate = self
                    socket.callbackQueue = self.serialQueue
                    socket.connect()
                    self.socket = socket
                    self.delegateQueue.async {
                        self.delegate?.connectionInConnecting(connection: self)
                    }
                    Logger.shared.verbose("\(socket) connecting URL<\"\(url)\"> with protocol<\"\(self.lcimProtocol.rawValue)\">")
                case .failure(error: let error):
                    Logger.shared.verbose("Get RTM server URL failed: \(error)")
                    self.delegateQueue.async {
                        self.delegate?.connection(connection: self, didFailInConnecting: .error(error))
                    }
                    if (error as NSError).domain == NSURLErrorDomain && self.isAutoReconnectionEnabled {
                        self.tryConnecting()
                    }
                }
            }
        }
    }
    
    private func tryClearConnection(with event: Event) {
        assert(self.specificAssertion)
        if let socket: WebSocket = self.socket {
            socket.delegate = nil
            socket.pongDelegate = nil
            socket.disconnect()
            self.socket = nil
            self.delegateQueue.async {
                self.delegate?.connection(connection: self, didDisconnect: event)
            }
        }
        if let timer: Timer = self.timer {
            timer.cancel()
            self.timer = nil
        }
    }
    
    private func getRTMServer(_ callback: @escaping (LCGenericResult<URL>) -> Void) {
        assert(self.specificAssertion)
        if let server: String = self.customRTMServer {
            if let url = URL(string: server), url.scheme != nil {
                callback(.success(value: url))
            } else {
                let error = LCError(code: .inconsistency, reason: "Custom RTM URL invalid")
                callback(.failure(error: error))
            }
        } else {
            self.rtmRouter.route { (result: LCGenericResult<RTMRoutingTable>) in
                self.serialQueue.async {
                    switch result {
                    case .success(value: let table):
                        let url: URL = (self.useSecondaryServer ? table.secondary : table.primary) ?? table.primary
                        callback(.success(value: url))
                    case .failure(error: let error):
                        callback(.failure(error: error))
                    }
                }
            }
        }
    }
    
}

// MARK: - WebSocketDelegate

extension Connection: WebSocketDelegate, WebSocketPongDelegate {
    
    func websocketDidConnect(socket: WebSocketClient) {
        assert(self.specificAssertion)
        assert(self.socket === socket && self.timer == nil)
        Logger.shared.verbose("\(socket) connect success")
        self.timer = Timer(timerQueue: self.serialQueue, commandCallbackQueue: self.delegateQueue) { (timer) in
            socket.write(ping: Data()) {
                Logger.shared.verbose("\(socket) ping sent")
            }
        }
        self.delegateQueue.async {
            self.delegate?.connectionDidConnect(connection: self)
        }
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        assert(self.specificAssertion)
        assert(self.socket === socket)
        Logger.shared.verbose("\(socket) disconnect with error: \(String(describing: error))")
        let disconnectError: Error = error ?? LCError(code: .connectionLost)
        if let wsError: WSError = disconnectError as? WSError {
            if wsError.type == .protocolError {
                // unexpectation error or close by server.
                self.tryClearConnection(with: .error(disconnectError))
                return
            } else if wsError.type == .invalidSSLError || wsError.type == .upgradeError {
                // SSL or HTTP upgrade failed, maybe should use another server.
                self.useSecondaryServer.toggle()
            }
        }
        if self.timer != nil {
            // timer exists means the connected socket was disconnected.
            self.tryClearConnection(with: .error(disconnectError))
        } else {
            // timer not exists means connecting failed.
            self.delegateQueue.async {
                self.delegate?.connection(connection: self, didFailInConnecting: .error(disconnectError))
            }
            self.socket?.delegate = nil
            self.socket?.pongDelegate = nil
            self.socket = nil
        }
        if self.isAutoReconnectionEnabled {
            // all condition but 'error or closing of WebSocket-Protocol', should try reconnecting.
            self.tryConnecting()
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        assert(self.specificAssertion)
        assert(self.socket === socket && self.timer != nil)
        let inCommand: IMGenericCommand
        do {
            inCommand = try IMGenericCommand(serializedData: data)
        } catch {
            Logger.shared.error(error)
            return
        }
        Logger.shared.debug("\n\n------ BEGIN LeanCloud In Command\n\(socket)\n\(inCommand)------ END\n")
        if inCommand.hasI {
            self.timer?.handle(callbackCommand: inCommand)
        } else {
            self.delegateQueue.async {
                self.delegate?.connection(connection: self, didReceiveCommand: inCommand)
            }
        }
    }
    
    func websocketDidReceivePong(socket: WebSocketClient, data: Data?) {
        assert(self.specificAssertion)
        assert(self.socket === socket && self.timer != nil)
        Logger.shared.verbose("\(socket) pong received")
        self.timer?.lastPongReceivedTimestamp = Date().timeIntervalSince1970
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        fatalError("should never be invoked.")
    }
    
}
