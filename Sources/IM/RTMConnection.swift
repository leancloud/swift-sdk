//
//  RTMConnection.swift
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

public var RTMConnectingTimeoutInterval: TimeInterval = 5.0
public var RTMTimeoutInterval: TimeInterval = 30.0

private let RTMMutex = NSLock()

var RTMConnectionRefMap_protobuf1: [String: [String: RTMConnection]] = [:]
var RTMConnectionRefMap_protobuf3: [String: [String: RTMConnection]] = [:]

func RTMConnectionRefering(
    application: LCApplication,
    peerID: String,
    lcimProtocol: RTMConnection.LCIMProtocol,
    customServerURL: URL? = nil)
    throws -> RTMConnection
{
    RTMMutex.lock()
    defer { RTMMutex.unlock() }
    var value: RTMConnection
    let appID: String = application.id
    var connectionRefMap: [String: [String: RTMConnection]]
    switch lcimProtocol {
    case .protobuf1:
        connectionRefMap = RTMConnectionRefMap_protobuf1
    case .protobuf3:
        connectionRefMap = RTMConnectionRefMap_protobuf3
    }
    if var oneConnectionForPeerIDsMap: [String: RTMConnection] = connectionRefMap[appID] {
        if let _ = oneConnectionForPeerIDsMap[peerID] {
            throw LCError(code: .inconsistency, reason: "has been registered.")
        } else {
            if let connection: RTMConnection = oneConnectionForPeerIDsMap.values.first {
                value = connection
                oneConnectionForPeerIDsMap[peerID] = value
            } else {
                value = RTMConnection(
                    application: application,
                    lcimProtocol: lcimProtocol,
                    customRTMServerURL: customServerURL
                )
                oneConnectionForPeerIDsMap[peerID] = value
            }
            connectionRefMap[appID] = oneConnectionForPeerIDsMap
        }
    } else {
        value = RTMConnection(
            application: application,
            lcimProtocol: lcimProtocol,
            customRTMServerURL: customServerURL
        )
        connectionRefMap[appID] = [peerID: value]
    }
    switch lcimProtocol {
    case .protobuf1:
        RTMConnectionRefMap_protobuf1 = connectionRefMap
    case .protobuf3:
        RTMConnectionRefMap_protobuf3 = connectionRefMap
    }
    return value
}

func RTMConnectionReleasing(
    application: LCApplication,
    peerID: String,
    lcimProtocol: RTMConnection.LCIMProtocol)
{
    RTMMutex.lock()
    defer { RTMMutex.unlock() }
    let appID: String = application.id
    var connectionRefMap: [String: [String: RTMConnection]]
    switch lcimProtocol {
    case .protobuf1:
        connectionRefMap = RTMConnectionRefMap_protobuf1
    case .protobuf3:
        connectionRefMap = RTMConnectionRefMap_protobuf3
    }
    if var oneConnectionForPeerIDsMap: [String: RTMConnection] = connectionRefMap[appID] {
        oneConnectionForPeerIDsMap.removeValue(forKey: peerID)
        connectionRefMap[appID] = oneConnectionForPeerIDsMap
        switch lcimProtocol {
        case .protobuf1:
            RTMConnectionRefMap_protobuf1 = connectionRefMap
        case .protobuf3:
            RTMConnectionRefMap_protobuf3 = connectionRefMap
        }
    }
}

protocol RTMConnectionDelegate: class {
    
    /// Invoked when websocket is connecting server or when geting RTM server.
    /// @note This function maybe be called multiple times in single-try-connecting.
    func connection(inConnecting connection: RTMConnection)
    
    /// Invoked when websocket connected server.
    func connection(didConnect connection: RTMConnection)
    
    /// Invoked when the connected websocket encounter some should-disconnect event or other network error.
    ///
    /// - Parameters:
    ///   - event: @see Connection.Event
    func connection(_ connection: RTMConnection, didDisconnect error: LCError)
    
    /// Invoked when the connected websocket receive direct-in-protobuf-command.
    ///
    /// - Parameters:
    ///   - inCommand: protobuf-command without serial ID.
    func connection(_ connection: RTMConnection, didReceiveCommand inCommand: IMGenericCommand)
}

class RTMConnection {
    
    #if DEBUG
    static let TestGoawayCommandReceivedNotification = Notification.Name.init("TestGoawayCommandReceivedNotification")
    #endif
    
    /// ref: https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md#传输协议
    enum LCIMProtocol: String {
        case protobuf1 = "lc.protobuf2.1"
        case protobuf3 = "lc.protobuf2.3"
    }
    
    class CommandCallback {
        enum Result {
            case inCommand(IMGenericCommand)
            case error(LCError)
            
            var command: IMGenericCommand? {
                switch self {
                case .inCommand(let command):
                    return command
                case .error:
                    return nil
                }
            }
            
            var error: LCError? {
                switch self {
                case .inCommand:
                    return nil
                case .error(let error):
                    return error
                }
            }
        }
        
        let closure: (Result) -> Void
        let expiration: TimeInterval
        let callingQueue: DispatchQueue
        
        init(callingQueue: DispatchQueue, closure: @escaping (Result) -> Void) {
            self.closure = closure
            self.expiration = Date().timeIntervalSince1970 + RTMTimeoutInterval
            self.callingQueue = callingQueue
        }
    }
    
    class Timer {
        
        let pingpongInterval: TimeInterval = 180.0
        let pingTimeout: TimeInterval = 20.0
        let source: DispatchSourceTimer
        let socket: WebSocketClient
        private(set) var commandIndexSequence: [UInt16] = []
        private(set) var commandCallbackCollection: [UInt16 : CommandCallback] = [:]
        private(set) var lastPingSentTimestamp: TimeInterval = 0
        private(set) var lastPongReceivedTimestamp: TimeInterval = 0
        
        #if DEBUG
        private(set) var specificKey: DispatchSpecificKey<Int>? = nil
        private(set) var specificValue: Int? = nil
        private var specificAssertion: Bool {
            if let key = self.specificKey, let value = self.specificValue {
                return DispatchQueue.getSpecific(key: key) == value
            } else {
                return false
            }
        }
        #else
        private var specificAssertion: Bool {
            return true
        }
        #endif
        
        init(connection: RTMConnection, socket: WebSocketClient) {
            #if DEBUG
            self.specificKey = connection.specificKey
            self.specificValue = connection.specificValue
            #endif
            self.source = DispatchSource.makeTimerSource(queue: connection.serialQueue)
            self.socket = socket
            self.source.schedule(deadline: .now(), repeating: .seconds(1))
            self.source.setEventHandler { [weak self] in
                let currentTimestamp: TimeInterval = Date().timeIntervalSince1970
                self?.check(commandTimeout: currentTimestamp)
                self?.check(pingPong: currentTimestamp)
            }
            self.source.resume()
        }
        
        deinit {
            self.source.cancel()
            let values = self.commandCallbackCollection.values
            if values.count > 0 {
                let error = LCError(code: .connectionLost)
                for item in values {
                    item.callingQueue.async {
                        item.closure(.error(error))
                    }
                }
            }
        }
        
        func insert(commandCallback: CommandCallback, index: UInt16) {
            assert(self.specificAssertion)
            self.commandIndexSequence.append(index)
            self.commandCallbackCollection[index] = commandCallback
        }
        
        func handle(callbackCommand command: IMGenericCommand) {
            assert(self.specificAssertion)
            let i: Int32 = (command.hasI ? command.i : 0)
            guard i > 0 && i <= UInt16.max else {
                Logger.shared.error("unexpected index<\(command.i)> of command has been found.")
                return
            }
            let indexKey: UInt16 = UInt16(i)
            guard let commandCallback: CommandCallback = self.commandCallbackCollection.removeValue(forKey: indexKey) else {
                Logger.shared.error("not found callback for in command with index<\(indexKey)>.")
                return
            }
            if let index: Int = self.commandIndexSequence.firstIndex(of: indexKey) {
                self.commandIndexSequence.remove(at: index)
            }
            commandCallback.callingQueue.async {
                if let error: LCError = command.encounteredError {
                    commandCallback.closure(.error(error))
                } else {
                    commandCallback.closure(.inCommand(command))
                }
            }
        }
        
        private func check(commandTimeout currentTimestamp: TimeInterval) {
            assert(self.specificAssertion)
            var length: Int = 0
            for indexKey in self.commandIndexSequence {
                length += 1
                guard let commandCallback: CommandCallback = self.commandCallbackCollection[indexKey] else {
                    continue
                }
                if commandCallback.expiration > currentTimestamp  {
                    length -= 1
                    break
                } else {
                    self.commandCallbackCollection.removeValue(forKey: indexKey)
                    commandCallback.callingQueue.async {
                        let error = LCError(code: .commandTimeout)
                        commandCallback.closure(.error(error))
                    }
                }
            }
            if length > 0 {
                self.commandIndexSequence.removeSubrange(0..<length)
            }
        }
        
        private func check(pingPong currentTimestamp: TimeInterval) {
            assert(self.specificAssertion)
            let isPingSentAndPongNotReceived: Bool = (self.lastPingSentTimestamp > self.lastPongReceivedTimestamp)
            let lastPingTimeout: Bool = (isPingSentAndPongNotReceived && currentTimestamp > self.lastPingSentTimestamp + self.pingTimeout)
            let shouldNextPingPong: Bool = (!isPingSentAndPongNotReceived && currentTimestamp > self.lastPongReceivedTimestamp + self.pingpongInterval)
            if lastPingTimeout || shouldNextPingPong {
                self.socket.write(ping: Data()) {
                    Logger.shared.verbose("\(self.socket) ping sent")
                }
                self.lastPingSentTimestamp = currentTimestamp
            }
        }
        
        func receivePong() {
            assert(self.specificAssertion)
            Logger.shared.verbose("\(self.socket) pong received")
            self.lastPongReceivedTimestamp = Date().timeIntervalSince1970
        }
        
    }
    
    class Delegator {
        let queue: DispatchQueue
        weak var delegate: RTMConnectionDelegate? = nil
        
        init(queue: DispatchQueue) {
            self.queue = queue
        }
    }
    
    let application: LCApplication
    let lcimProtocol: LCIMProtocol
    var customRTMServerURL: URL? = nil
    let rtmRouter: RTMRouter
    
    let serialQueue: DispatchQueue = DispatchQueue(label: "LeanCloud.Connection.serialQueue")
    private(set) var delegatorMap: [String: Delegator] = [:]
    private(set) var socket: WebSocket? = nil
    private(set) var timer: Timer? = nil
    private(set) var useSecondaryServer: Bool = false
    private(set) var continuousConnectingFailedFlag: UInt = 0
    var isAutoReconnectionEnabled: Bool {
        return !self.delegatorMap.isEmpty
    }
    
    private var nextSerialIndex: UInt16 {
        let index: UInt16 = self.underlyingSerialIndex
        if index == UInt16.max {
            self.underlyingSerialIndex = 1
        } else {
            self.underlyingSerialIndex += 1
        }
        return index
    }
    private(set) var underlyingSerialIndex: UInt16 = 1
    
    #if os(iOS) || os(tvOS)
    enum AppState {
        case background
        case foreground
    }
    private(set) var previousAppState: AppState = .foreground
    private(set) var enterBackgroundObserver: NSObjectProtocol!
    private(set) var enterForegroundObserver: NSObjectProtocol!
    #endif
    #if !os(watchOS)
    private(set) var previousReachabilityStatus: NetworkReachabilityManager.NetworkReachabilityStatus = .unknown
    private(set) var reachabilityManager: NetworkReachabilityManager? = nil
    #endif
    
    #if DEBUG
    let specificKey = DispatchSpecificKey<Int>()
    // whatever random Int is OK.
    let specificValue: Int = Int.random(in: 1...999)
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
    ///   - lcimProtocol: @see LCIMProtocol.
    ///   - delegate: @see RTMConnectionDelegate.
    ///   - delegateQueue: The queue where ConnectionDelegate's fuctions and command's callback be invoked.
    ///   - customRTMServerURL: The custom RTM server, if set, Connection will ignore RTM Router, if not set, Connection will use the server return by RTM Router.
    init(application: LCApplication, lcimProtocol: LCIMProtocol, customRTMServerURL: URL? = nil) {
        #if DEBUG
        self.serialQueue.setSpecific(key: self.specificKey, value: self.specificValue)
        #endif
        self.application = application
        self.lcimProtocol = lcimProtocol
        self.customRTMServerURL = customRTMServerURL
        self.rtmRouter = RTMRouter(application: application)
        
        #if os(iOS) || os(tvOS)
        self.previousAppState = mainQueueSync {
            (UIApplication.shared.applicationState == .background ? .background : .foreground)
        }
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = self.serialQueue
        self.enterBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: operationQueue)
        { [weak self] _ in
            Logger.shared.verbose("Application did enter background")
            self?.applicationStateChanged(with: .background)
        }
        self.enterForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: operationQueue)
        { [weak self] _ in
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
        self.socket = nil
        self.timer = nil
    }
    
    func removeDelegator(peerID: String) {
        self.serialQueue.async {
            self.delegatorMap.removeValue(forKey: peerID)
        }
    }
    
    /// Try connecting RTM server, if websocket exists, then this action will be ignored.
    func connect(peerID: String? = nil, delegator: Delegator? = nil) {
        self.serialQueue.async {
            if let peerID = peerID, let delegator = delegator {
                self.delegatorMap[peerID] = delegator
            }
            if let _ = self.socket, let _ = self.timer {
                delegator?.queue.async {
                    delegator?.delegate?.connection(didConnect: self)
                }
            } else if self.socket == nil, self.timer == nil {
                if let error: LCError = self.checkIfCanDoConnecting() {
                    self.tryClearConnection(with: error)
                } else {
                    self.tryConnecting(forcing: true)
                }
            }
        }
    }
    
    /// Try close websocket, cancel timer and purge command callback.
    func disconnect() {
        self.serialQueue.async {
            self.tryClearConnection(with: LCError.closedByLocal)
        }
    }
    
    /// Send Command.
    ///
    /// - Parameters:
    ///   - command: Out Command.
    ///   - callback: If set, the out command will has a serial-ID and callback will be added into waiting queue.
    func send(command: IMGenericCommand, callingQueue: DispatchQueue? = nil, callback: ((CommandCallback.Result) -> Void)? = nil) {
        self.serialQueue.async {
            guard let socket: WebSocket = self.socket, let timer: Timer = self.timer else {
                callingQueue?.async {
                    let error = LCError(code: .connectionLost)
                    callback?(.error(error))
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
                callingQueue?.async {
                    let serializingError = LCError(error: error)
                    callback?(.error(serializingError))
                }
                return
            }
            guard serializedData.count <= 5000 else {
                callingQueue?.async {
                    let error = LCError(code: .commandDataLengthTooLong)
                    callback?(.error(error))
                }
                return
            }
            if let callback = callback, let callingQueue = callingQueue {
                let commandCallback = CommandCallback(callingQueue: callingQueue, closure: callback)
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

extension RTMConnection {
    
    #if os(iOS) || os(tvOS)
    private func applicationStateChanged(with newState: RTMConnection.AppState) {
        assert(self.specificAssertion)
        let oldState: AppState = self.previousAppState
        self.previousAppState = newState
        switch (oldState, newState) {
        case (.background, .foreground):
            self.tryConnecting()
        case (.foreground, .background):
            self.tryClearConnection(with: LCError.appInBackground)
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
            self.tryClearConnection(with: LCError.networkUnavailable)
        } else if oldStatus != newStatus && newStatus != .notReachable {
            self.tryClearConnection(with: LCError.networkChanged)
            self.tryConnecting()
        }
    }
    #endif
    
    private func checkIfCanDoConnecting() -> LCError? {
        assert(self.specificAssertion)
        #if os(iOS) || os(tvOS)
        guard self.previousAppState == .foreground else {
            return LCError.appInBackground
        }
        #endif
        #if !os(watchOS)
        guard self.previousReachabilityStatus != .notReachable else {
            return LCError.networkUnavailable
        }
        #endif
        return nil
    }
    
    private func check(isServerError error: Error?) -> Bool {
        if error == nil {
            // Result: Stream end encountered, Socket Connection reset by remote peer.
            // Reason: Maybe due to Network Environment, maybe due to LeanCloud Server Error.
            // Handling: Anyway, SDK regrad it as LeanCloud Server Error.
            return true
        } else if let wsError: WSError = error as? WSError {
            switch wsError.type {
            case .protocolError, .invalidSSLError, .upgradeError:
                // 99.99% is LeanCloud Server Error.
                return true
            default:
                break
            }
        }
        return false
    }
    
    private func tryConnecting(forcing: Bool = false, delay: Int = 0) {
        assert(self.specificAssertion)
        let canConnecting: () -> Bool = {
            if
                (self.isAutoReconnectionEnabled || forcing),
                self.checkIfCanDoConnecting() == nil
            {
                return true
            } else {
                return false
            }
        }
        let tryNotifyingInConnecting: () -> Void = {
            if self.socket == nil {
                for item in self.delegatorMap.values {
                    item.queue.async {
                        item.delegate?.connection(inConnecting: self)
                    }
                }
            }
        }
        guard canConnecting() else {
            return
        }
        let workItem = DispatchWorkItem {
            assert(self.specificAssertion)
            guard canConnecting() else {
                return
            }
            tryNotifyingInConnecting()
            self.getRTMServer { (result: LCGenericResult<URL>) in
                assert(self.specificAssertion)
                guard
                    canConnecting(),
                    self.socket == nil
                    else
                { return }
                switch result {
                case .success(value: let url):
                    tryNotifyingInConnecting()
                    var request = URLRequest(url: url)
                    request.timeoutInterval = RTMConnectingTimeoutInterval
                    let socket = WebSocket(request: request, protocols: [self.lcimProtocol.rawValue])
                    socket.delegate = self
                    socket.pongDelegate = self
                    socket.callbackQueue = self.serialQueue
                    socket.connect()
                    self.socket = socket
                    Logger.shared.verbose("\(socket) connecting URL<\"\(url)\"> with protocol<\"\(self.lcimProtocol.rawValue)\">")
                case .failure(error: let error):
                    Logger.shared.verbose("Get RTM server URL failed: \(error)")
                    self.tryClearConnection(with: error)
                    if let nsError: NSError = error.underlyingError as NSError?,
                        nsError.domain == NSURLErrorDomain {
                        self.tryConnecting(delay: 1)
                    }
                }
            }
        }
        if delay <= 0 {
            workItem.perform()
        } else {
            tryNotifyingInConnecting()
            self.serialQueue.asyncAfter(
                deadline: .now() + .seconds(delay),
                execute: workItem
            )
        }
    }
    
    private func tryClearConnection(with error: LCError) {
        assert(self.specificAssertion)
        if let socket: WebSocket = self.socket {
            socket.delegate = nil
            socket.pongDelegate = nil
            socket.disconnect()
            self.socket = nil
        }
        for item in self.delegatorMap.values {
            item.queue.async {
                item.delegate?.connection(self, didDisconnect: error)
            }
        }
        self.timer = nil
    }
    
    private func getRTMServer(_ callback: @escaping (LCGenericResult<URL>) -> Void) {
        assert(self.specificAssertion)
        if let serverURL: URL = self.customRTMServerURL {
            callback(.success(value: serverURL))
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
    
    private func handleGoaway(inCommand: IMGenericCommand) {
        assert(self.specificAssertion)
        guard inCommand.cmd == .goaway else {
            return
        }
        var userInfo: [String: Any]? = nil
        do {
            try self.rtmRouter.cache.clear()
            self.tryClearConnection(with: LCError.closedByRemote)
            self.tryConnecting()
        } catch {
            Logger.shared.error(error)
            userInfo = ["error": error]
        }
        #if DEBUG
        NotificationCenter.default.post(
            name: RTMConnection.TestGoawayCommandReceivedNotification,
            object: self,
            userInfo: userInfo
        )
        #else
        _ = userInfo
        #endif
    }
    
}

// MARK: - WebSocketDelegate

extension RTMConnection: WebSocketDelegate, WebSocketPongDelegate {
    
    func websocketDidConnect(socket: WebSocketClient) {
        assert(self.specificAssertion)
        assert(self.socket === socket && self.timer == nil)
        Logger.shared.verbose("\(socket) connect success")
        self.continuousConnectingFailedFlag = 0
        self.timer = Timer(connection: self, socket: socket)
        for item in self.delegatorMap.values {
            item.queue.async {
                item.delegate?.connection(didConnect: self)
            }
        }
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        assert(self.specificAssertion)
        assert(self.socket === socket)
        Logger.shared.verbose("\(socket) disconnect with error: \(String(describing: error))")
        let isFailedInConnecting: Bool = (self.timer == nil)
        if isFailedInConnecting {
            self.continuousConnectingFailedFlag += 1
            if self.continuousConnectingFailedFlag >= 60 {
                do {
                    try self.rtmRouter.cache.clear()
                } catch {
                    Logger.shared.error(error)
                }
            }
        }
        self.tryClearConnection(with: LCError(error: error ?? LCError.closedByRemote))
        self.useSecondaryServer.toggle()
        let delay: Int = (isFailedInConnecting ? 1 : 0)
        self.tryConnecting(delay: delay)
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
            if inCommand.hasPeerID {
                let peerID = inCommand.peerID
                if let delegator: Delegator = self.delegatorMap[peerID] {
                    delegator.queue.async {
                        delegator.delegate?.connection(self, didReceiveCommand: inCommand)
                    }
                } else {
                    Logger.shared.error("\(type(of: self)) not found delegator for peer ID: \(peerID)")
                }
            } else {
                self.handleGoaway(inCommand: inCommand)
            }
        }
    }
    
    func websocketDidReceivePong(socket: WebSocketClient, data: Data?) {
        assert(self.specificAssertion)
        assert(self.socket === socket && self.timer != nil)
        self.timer?.receivePong()
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        fatalError("should never be invoked.")
    }
    
}

extension LCError {
    
    static var appInBackground: LCError {
        return LCError(
            code: .connectionLost,
            reason: "Due to application did enter background, connection lost."
        )
    }
    
    static var networkUnavailable: LCError {
        return LCError(
            code: .connectionLost,
            reason: "Due to network unavailable, connection lost."
        )
    }
    
    static var networkChanged: LCError {
        return LCError(
            code: .connectionLost,
            reason: "Due to network interface did change, connection lost."
        )
    }
    
    static var closedByLocal: LCError {
        return LCError(
            code: .connectionLost,
            reason: "Connection did close by local peer."
        )
    }
    
    static var closedByRemote: LCError {
        return LCError(
            code: .connectionLost,
            reason: "Connection did close by remote peer."
        )
    }
    
}

extension IMGenericCommand {
    
    fileprivate var encounteredError: LCError? {
        if self.cmd == .error {
            if self.hasErrorMessage {
                return self.errorMessage.lcError
            } else {
                return LCError(code: .commandInvalid)
            }
        } else {
            return nil
        }
    }
    
}

extension IMErrorCommand {
    
    var lcError: LCError {
        let code: Int = Int(self.code)
        let reason: String? = (self.hasReason ? self.reason : nil)
        var userInfo: LCError.UserInfo? = [:]
        if self.hasAppCode {
            userInfo?["appCode"] = self.appCode
        }
        if self.hasAppMsg {
            userInfo?["appMsg"] = self.appMsg
        }
        if self.hasDetail {
            userInfo?["detail"] = self.detail
        }
        if let ui = userInfo, ui.isEmpty {
            userInfo = nil
        } else {
            do {
                userInfo = try userInfo?.jsonObject()
            } catch {
                Logger.shared.error(error)
                userInfo = nil
            }
        }
        let error = LCError(code: code, reason: reason, userInfo: userInfo)
        return error
    }
    
}

extension IMSessionCommand {
    
    var lcError: LCError {
        let code: Int = Int(self.code)
        let reason: String? = (self.hasReason ? self.reason : nil)
        var userInfo: LCError.UserInfo? = [:]
        if self.hasDetail {
            userInfo?["detail"] = self.detail
        }
        if let ui = userInfo, ui.isEmpty {
            userInfo = nil
        } else {
            do {
                userInfo = try userInfo?.jsonObject()
            } catch {
                Logger.shared.error(error)
                userInfo = nil
            }
        }
        let error = LCError(code: code, reason: reason, userInfo: userInfo)
        return error
    }
    
}

extension IMAckCommand {
    
    var lcError: LCError? {
        if self.hasCode || self.hasAppCode {
            let code: Int = Int(self.code)
            let reason: String? = (self.hasReason ? self.reason : nil)
            var userInfo: LCError.UserInfo? = [:]
            if self.hasAppCode {
                userInfo?["appCode"] = self.appCode
            }
            if self.hasAppMsg {
                userInfo?["appMsg"] = self.appMsg
            }
            if let ui = userInfo, ui.isEmpty {
                userInfo = nil
            } else {
                do {
                    userInfo = try userInfo?.jsonObject()
                } catch {
                    Logger.shared.error(error)
                    userInfo = nil
                }
            }
            let error = LCError(code: code, reason: reason, userInfo: userInfo)
            return error
        } else {
            return nil
        }
    }
    
}
