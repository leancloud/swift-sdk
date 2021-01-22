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

enum RTMService: Int32 {
    case liveQuery = 1
    case instantMessaging = 2
}

class RTMConnectionManager {
    static let `default` = RTMConnectionManager()
    private init() {}
    
    private let mutex = NSLock()
    
    typealias InstantMessagingRegistry = [LCApplication.Identifier: [IMClient.Identifier: RTMConnection]]
    typealias LiveQueryRegistry = [LCApplication.Identifier: RTMConnection]
    
    var imProtobuf1Registry: InstantMessagingRegistry = [:]
    var imProtobuf3Registry: InstantMessagingRegistry = [:]
    var liveQueryRegistry: LiveQueryRegistry = [:]
    var connectingDelayIntervalMap: [LCApplication.Identifier: Int] = [:]
    
    private func getRegistry(
        lcimProtocol: RTMConnection.LCIMProtocol) -> InstantMessagingRegistry
    {
        let registry: InstantMessagingRegistry
        switch lcimProtocol {
        case .protobuf3:
            registry = self.imProtobuf3Registry
        case .protobuf1:
            registry = self.imProtobuf1Registry
        }
        return registry
    }
    
    private func setRegistry(
        _ registry: InstantMessagingRegistry,
        lcimProtocol: RTMConnection.LCIMProtocol)
    {
        switch lcimProtocol {
        case .protobuf3:
            self.imProtobuf3Registry = registry
        case .protobuf1:
            self.imProtobuf1Registry = registry
        }
    }
    
    private func connectionForLiveQueryFromRegistry(
        applicationID: LCApplication.Identifier) -> RTMConnection?
    {
        if let connection = self.liveQueryRegistry[applicationID] {
            return connection
        } else {
            return (self.getRegistry(lcimProtocol: .protobuf3)[applicationID]?.values.first)
                ?? (self.getRegistry(lcimProtocol: .protobuf1)[applicationID]?.values.first)
        }
    }
    
    func register(
        application: LCApplication,
        service: RTMConnection.Service) throws -> RTMConnection
    {
        self.mutex.lock()
        defer {
            self.mutex.unlock()
        }
        let appID: LCApplication.Identifier = application.id
        let connection: RTMConnection
        switch service {
        case let .instantMessaging(ID: clientID, protocol: lcimProtocol):
            var registry = self.getRegistry(lcimProtocol: lcimProtocol)
            if var connectionMap = registry[appID],
               let existConnection = connectionMap.values.first {
                if let _ = connectionMap[clientID] {
                    throw LCError(
                        code: .inconsistency,
                        reason: "Duplicate registration for connection.")
                } else {
                    connectionMap[clientID] = existConnection
                    registry[appID] = connectionMap
                    connection = existConnection
                }
            } else if let existConnection = self.liveQueryRegistry[appID],
                      existConnection.lcimProtocol == lcimProtocol {
                registry[appID] = [clientID: existConnection]
                connection = existConnection
            } else {
                connection = try RTMConnection(
                    application: application,
                    lcimProtocol: lcimProtocol)
                registry[appID] = [clientID: connection]
            }
            self.setRegistry(registry, lcimProtocol: lcimProtocol)
        case .liveQuery:
            if let existConnection = self.connectionForLiveQueryFromRegistry(applicationID: appID) {
                connection = existConnection
            } else {
                connection = try RTMConnection(
                    application: application,
                    lcimProtocol: .protobuf3)
            }
            self.liveQueryRegistry[appID] = connection
        }
        return connection
    }
    
    func unregister(
        application: LCApplication,
        service: RTMConnection.Service)
    {
        self.mutex.lock()
        defer {
            self.mutex.unlock()
        }
        let appID: LCApplication.Identifier = application.id
        switch service {
        case let .instantMessaging(ID: clientID, protocol: lcimProtocol):
            var registry = self.getRegistry(lcimProtocol: lcimProtocol)
            if var connectionMap = registry[appID] {
                connectionMap.removeValue(forKey: clientID)
                registry[appID] = connectionMap
            }
            self.setRegistry(registry, lcimProtocol: lcimProtocol)
        case .liveQuery:
            self.liveQueryRegistry.removeValue(forKey: appID)
        }
    }
    
    func nextConnectingDelayInterval(application: LCApplication) -> Int {
        self.mutex.lock()
        defer {
            self.mutex.unlock()
        }
        let appID: LCApplication.Identifier = application.id
        var interval = (self.connectingDelayIntervalMap[appID] ?? -2)
        if interval < 1 {
            interval += 1
        } else if interval > 15 {
            interval = 30
        } else {
            interval *= 2
        }
        self.connectingDelayIntervalMap[appID] = interval
        return interval
    }
    
    func resetConnectingDelayInterval(application: LCApplication) {
        self.mutex.lock()
        defer {
            self.mutex.unlock()
        }
        let appID: LCApplication.Identifier = application.id
        self.connectingDelayIntervalMap[appID] = -2
    }
}

protocol RTMConnectionDelegate: class {
    
    func connection(inConnecting connection: RTMConnection)
    
    func connection(didConnect connection: RTMConnection)
    
    func connection(_ connection: RTMConnection, didDisconnect error: LCError)
    
    func connection(_ connection: RTMConnection, didReceiveCommand inCommand: IMGenericCommand)
}

class RTMConnection {
    #if DEBUG
    static let TestGoawayCommandReceivedNotification = Notification.Name(
        "\(RTMConnection.self).TestGoawayCommandReceivedNotification")
    #endif
    
    /// ref: https://github.com/leancloud/avoscloud-push/tree/master/doc/protocols
    enum LCIMProtocol: String {
        case protobuf1 = "lc.protobuf2.1"
        case protobuf3 = "lc.protobuf2.3"
    }
    
    enum Service {
        case instantMessaging(ID: IMClient.Identifier, protocol: RTMConnection.LCIMProtocol)
        case liveQuery(ID: LiveQueryClient.Identifier)
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
        
        let peerID: String
        let command: IMGenericCommand
        let callingQueue: DispatchQueue
        var closures: [(Result) -> Void]
        let expiration: TimeInterval
        
        init(
            timeoutInterval: TimeInterval,
            peerID: String,
            command: IMGenericCommand,
            callingQueue: DispatchQueue,
            closure: @escaping (Result) -> Void)
        {
            self.peerID = peerID
            self.command = command
            self.callingQueue = callingQueue
            self.closures = [closure]
            self.expiration = Date().timeIntervalSince1970 + timeoutInterval
        }
    }
    
    class Timer {
        let pingpongInterval: TimeInterval = 180.0
        let pingTimeout: TimeInterval = 20.0
        let queue: DispatchQueue
        var source: DispatchSourceTimer?
        var socket: WebSocket?
        private(set) var index: Int32 = 0
        private(set) var commandIndexSequence: [Int32] = []
        private(set) var commandCallbackCollection: [Int32: CommandCallback] = [:]
        private(set) var lastPingSentTimestamp: TimeInterval = 0
        private(set) var lastPongReceivedTimestamp: TimeInterval = 0
        
        #if DEBUG
        private(set) var specificKey: DispatchSpecificKey<Int>?
        private(set) var specificValue: Int?
        #endif
        private var specificAssertion: Bool {
            #if DEBUG
            if let key = self.specificKey,
               let value = self.specificValue {
                return DispatchQueue.getSpecific(key: key) == value
            } else {
                return false
            }
            #else
            return true
            #endif
        }
        
        init(connection: RTMConnection, socket: WebSocket) {
            #if DEBUG
            self.specificKey = connection.specificKey
            self.specificValue = connection.specificValue
            #endif
            self.socket = socket
            self.queue = connection.serialQueue
            self.source = DispatchSource.makeTimerSource(queue: connection.serialQueue)
            self.source?.schedule(
                deadline: .now(),
                repeating: .seconds(1),
                leeway: .seconds(1))
            self.source?.setEventHandler {
                let currentTimestamp = Date().timeIntervalSince1970
                self.check(commandTimeout: currentTimestamp)
                self.check(pingPong: currentTimestamp)
            }
            self.source?.resume()
        }
        
        deinit {
            Logger.shared.verbose("""
                \n\(type(of: self))
                    - deinit
                """)
        }
        
        func insert(
            commandCallback: CommandCallback,
            index: Int32)
        {
            assert(self.specificAssertion)
            self.commandIndexSequence.append(index)
            self.commandCallbackCollection[index] = commandCallback
        }
        
        func handle(callbackCommand command: IMGenericCommand) {
            assert(self.specificAssertion)
            guard let indexKey = (command.hasI ? command.i : nil),
                  let commandCallback = self.commandCallbackCollection.removeValue(forKey: indexKey) else {
                return
            }
            if let index = self.commandIndexSequence.firstIndex(of: indexKey) {
                self.commandIndexSequence.remove(at: index)
            }
            let result: CommandCallback.Result
            if let error = command.lcEncounteredError {
                result = .error(error)
            } else {
                result = .inCommand(command)
            }
            for closure in commandCallback.closures {
                commandCallback.callingQueue.async {
                    closure(result)
                }
            }
        }
        
        private func check(commandTimeout currentTimestamp: TimeInterval) {
            assert(self.specificAssertion)
            var length: Int = 0
            for indexKey in self.commandIndexSequence {
                if let commandCallback = self.commandCallbackCollection[indexKey] {
                    if commandCallback.expiration > currentTimestamp  {
                        break
                    } else {
                        self.commandCallbackCollection.removeValue(forKey: indexKey)
                        let result = CommandCallback.Result.error(LCError(code: .commandTimeout))
                        for closure in commandCallback.closures {
                            commandCallback.callingQueue.async {
                                closure(result)
                            }
                        }
                        length += 1
                    }
                } else {
                    length += 1
                }
            }
            if length > 0 {
                self.commandIndexSequence.removeSubrange(0..<length)
            }
        }
        
        private func check(pingPong currentTimestamp: TimeInterval) {
            assert(self.specificAssertion)
            let isPingSentAndPongNotReceived: Bool = (self.lastPingSentTimestamp > self.lastPongReceivedTimestamp)
            let lastPingTimeout: Bool = (isPingSentAndPongNotReceived
                                            && (currentTimestamp > self.lastPingSentTimestamp + self.pingTimeout))
            let shouldNextPingPong: Bool = (!isPingSentAndPongNotReceived &&
                                                (currentTimestamp > self.lastPongReceivedTimestamp + self.pingpongInterval))
            if lastPingTimeout || shouldNextPingPong {
                if let socket = self.socket {
                    socket.write(ping: Data()) {
                        Logger.shared.verbose("""
                            \n\(socket)
                                - ping sent
                            """)
                    }
                }
                self.lastPingSentTimestamp = currentTimestamp
            }
        }
        
        func receivePong() {
            assert(self.specificAssertion)
            if let socket = self.socket {
                Logger.shared.verbose("""
                    \n\(socket)
                        - pong received
                    """)
            }
            self.lastPongReceivedTimestamp = Date().timeIntervalSince1970
        }
        
        func tryThrottling(
            command: IMGenericCommand,
            peerID: String,
            queue: DispatchQueue,
            callback: @escaping (CommandCallback.Result) -> Void) -> Bool
        {
            assert(self.specificAssertion)
            if command.cmd == .direct ||
                (command.cmd == .conv &&
                    (command.op == .start ||
                        command.op == .update ||
                        command.op == .members)) {
                return false
            }
            for i in self.commandIndexSequence.reversed() {
                if let commandCallback = self.commandCallbackCollection[i] {
                    guard commandCallback.command.cmd == command.cmd,
                          commandCallback.command.op == command.op,
                          commandCallback.peerID == peerID,
                          commandCallback.callingQueue === queue,
                          commandCallback.command == command else {
                        continue
                    }
                    commandCallback.closures.append(callback)
                    return true
                }
            }
            return false
        }
        
        func nextIndex() -> Int32 {
            assert(self.specificAssertion)
            if self.index == Int32.max {
                self.index = 0
            }
            self.index += 1
            return self.index
        }
        
        func clean(inCurrentQueue: Bool = true) {
            let cleaning = {
                assert(self.specificAssertion)
                if let source = self.source {
                    source.cancel()
                    self.source = nil
                }
                self.socket = nil
                if !self.commandIndexSequence.isEmpty {
                    let result = CommandCallback.Result.error(LCError(code: .connectionLost))
                    for index in self.commandIndexSequence {
                        if let commandCallback = self.commandCallbackCollection[index] {
                            for closure in commandCallback.closures {
                                commandCallback.callingQueue.async {
                                    closure(result)
                                }
                            }
                        }
                    }
                }
                self.commandIndexSequence.removeAll()
                self.commandCallbackCollection.removeAll()
            }
            if inCurrentQueue {
                cleaning()
            } else {
                self.queue.async {
                    cleaning()
                }
            }
        }
    }
    
    class Delegator {
        let queue: DispatchQueue
        weak var delegate: RTMConnectionDelegate?
        
        init(queue: DispatchQueue) {
            self.queue = queue
        }
    }
    
    let application: LCApplication
    let lcimProtocol: LCIMProtocol
    let rtmRouter: RTMRouter?
    let serialQueue = DispatchQueue(
        label: "LC.Swift.\(RTMConnection.self).serialQueue")
    
    private(set) var instantMessagingDelegatorMap: [IMClient.Identifier: Delegator] = [:]
    private(set) var liveQueryDelegatorMap: [LiveQueryClient.Identifier: Delegator] = [:]
    var allDelegators: [Delegator] {
        return Array(self.instantMessagingDelegatorMap.values)
            + Array(self.liveQueryDelegatorMap.values)
    }
    private(set) var socket: WebSocket?
    private(set) var timer: Timer?
    private(set) var defaultInstantMessagingPeerID: String?
    private(set) var needPeerIDForEveryCommandOfInstantMessaging: Bool = false
    private(set) var previousConnectingWorkItem: DispatchWorkItem?
    private(set) var useSecondaryServer: Bool = false
    private(set) var isInRouting: Bool = false
    
    #if os(iOS) || os(tvOS)
    enum AppState {
        case background
        case foreground
    }
    private(set) var previousAppState: AppState = .foreground
    private(set) var enterBackgroundObserver: NSObjectProtocol?
    private(set) var enterForegroundObserver: NSObjectProtocol?
    #endif
    
    #if !os(watchOS)
    private(set) var previousReachabilityStatus: NetworkReachabilityManager.NetworkReachabilityStatus = .unknown
    private(set) var reachabilityManager: NetworkReachabilityManager?
    #endif
    
    #if DEBUG
    let specificKey = DispatchSpecificKey<Int>()
    let specificValue: Int = Int.random(in: 100...999) // whatever random int is OK.
    #endif
    private var specificAssertion: Bool {
        #if DEBUG
        return self.specificValue == DispatchQueue.getSpecific(key: self.specificKey)
        #else
        return true
        #endif
    }
    let debugUUID = Utility.compactUUID
    
    init(application: LCApplication, lcimProtocol: LCIMProtocol) throws {
        #if DEBUG
        self.serialQueue.setSpecific(key: self.specificKey, value: self.specificValue)
        #endif
        self.application = application
        self.lcimProtocol = lcimProtocol
        if let _ = self.application.configuration.RTMCustomServerURL {
            self.rtmRouter = nil
        } else {
            self.rtmRouter = try RTMRouter(application: application)
        }
        #if os(iOS) || os(tvOS)
        self.previousAppState = mainQueueSync {
            (UIApplication.shared.applicationState == .background ? .background : .foreground)
        }
        Logger.shared.verbose("""
            \n\(type(of: self)): \(self.debugUUID)
                - application state: \(self.previousAppState)
            """)
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = self.serialQueue
        self.enterBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: operationQueue)
        { [weak self] _ in
            self?.applicationStateChanged(with: .background)
        }
        self.enterForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: operationQueue)
        { [weak self] _ in
            self?.applicationStateChanged(with: .foreground)
        }
        #endif
        #if !os(watchOS)
        self.reachabilityManager = NetworkReachabilityManager()
        self.previousReachabilityStatus = self.reachabilityManager?.status ?? .unknown
        self.reachabilityManager?.startListening(
            onQueue: self.serialQueue)
        { [weak self] newStatus in
            self?.networkReachabilityStatusChanged(with: newStatus)
        }
        #endif
    }
    
    deinit {
        Logger.shared.verbose("""
            \n\(type(of: self)): \(self.debugUUID)
                - deinit
            """)
        #if os(iOS) || os(tvOS)
        if let observer = self.enterBackgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            self.enterBackgroundObserver = nil
        }
        if let observer = self.enterForegroundObserver {
            NotificationCenter.default.removeObserver(observer)
            self.enterForegroundObserver = nil
        }
        #endif
        #if !os(watchOS)
        self.reachabilityManager?.stopListening()
        #endif
        self.timer?.clean(inCurrentQueue: false)
        self.timer = nil
        self.socket?.disconnect()
        self.socket = nil
    }
    
    func removeDelegator(service: Service) {
        self.serialQueue.async {
            switch service {
            case let .instantMessaging(ID: ID, protocol: _):
                self.instantMessagingDelegatorMap.removeValue(forKey: ID)
            case let .liveQuery(ID: ID):
                self.liveQueryDelegatorMap.removeValue(forKey: ID)
            }
        }
    }
    
    func connect(
        service: Service? = nil,
        delegator: Delegator? = nil)
    {
        self.serialQueue.async {
            if let service = service,
               let delegator = delegator {
                switch service {
                case let .instantMessaging(ID: ID, protocol: _):
                    self.instantMessagingDelegatorMap[ID] = delegator
                case let .liveQuery(ID: ID):
                    self.liveQueryDelegatorMap[ID] = delegator
                }
            }
            if let _ = self.socket,
               let _ = self.timer {
                delegator?.queue.async {
                    delegator?.delegate?.connection(didConnect: self)
                }
            } else if self.socket == nil,
                      self.timer == nil {
                if let error = self.checkEnvironment() {
                    delegator?.queue.async {
                        delegator?.delegate?.connection(self, didDisconnect: error)
                    }
                } else {
                    self.tryConnecting()
                }
            } else {
                // means in connecting, just wait.
            }
        }
    }
    
    func disconnect() {
        self.serialQueue.async {
            self.tryClearConnection(with: LCError.RTMConnectionClosedByLocal)
        }
    }
    
    func send(
        command: IMGenericCommand,
        service: RTMService,
        peerID: String,
        callingQueue: DispatchQueue? = nil,
        callback: ((CommandCallback.Result) -> Void)? = nil)
    {
        self.serialQueue.async {
            guard let socket = self.socket,
                  let timer = self.timer else {
                callingQueue?.async {
                    let error = LCError(code: .connectionLost)
                    callback?(.error(error))
                }
                return
            }
            var outCommand = command
            if service == .instantMessaging,
               let commandWithPeerID = self.tryPadding(peerID: peerID, for: outCommand) {
                outCommand = commandWithPeerID
            }
            let outCommandWithoutIndex = outCommand
            if let callback = callback,
               let callingQueue = callingQueue {
                if timer.tryThrottling(
                    command: outCommandWithoutIndex,
                    peerID: peerID,
                    queue: callingQueue,
                    callback: callback) {
                    return
                }
                outCommand.i = timer.nextIndex()
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
            guard serializedData.count <= (1024 * 5) else {
                callingQueue?.async {
                    let error = LCError(
                        code: .commandDataLengthTooLong,
                        userInfo: ["bytesCount": serializedData.count])
                    callback?(.error(error))
                }
                return
            }
            if let callback = callback,
               let callingQueue = callingQueue {
                let commandCallback = CommandCallback(
                    timeoutInterval: self.application.configuration
                        .RTMCommandTimeoutInterval,
                    peerID: peerID,
                    command: outCommandWithoutIndex,
                    callingQueue: callingQueue,
                    closure: callback)
                timer.insert(commandCallback: commandCallback, index: outCommand.i)
            }
            let defaultPeerID = self.defaultInstantMessagingPeerID
            socket.write(data: serializedData) {
                Logger.shared.debug(closure: { () -> String in
                    var log = "\n------ BEGIN LeanCloud Out Command\n\(socket)\n"
                    if service == .instantMessaging,
                       let defaultPeerID = defaultPeerID {
                        log += "<DPID: \(defaultPeerID)>\n"
                    }
                    log += "Service: \(service.rawValue)\n\(outCommand)\n------ END"
                    return log
                })
            }
        }
    }
}

extension RTMConnection {
    
    // MARK: Internal
    
    #if os(iOS) || os(tvOS)
    private func applicationStateChanged(
        with newState: RTMConnection.AppState)
    {
        assert(self.specificAssertion)
        Logger.shared.verbose("""
            \n\(type(of: self)): \(self.debugUUID)
                - application state: \(newState)
            """)
        let oldState = self.previousAppState
        self.previousAppState = newState
        switch (oldState, newState) {
        case (.background, .foreground):
            self.tryConnecting()
        case (.foreground, .background):
            self.tryClearConnection(with: LCError.RTMConnectionAppInBackground)
            self.resetConnectingDelayInterval()
        default:
            break
        }
    }
    #endif
    
    #if !os(watchOS)
    private func networkReachabilityStatusChanged(
        with newStatus: NetworkReachabilityManager.NetworkReachabilityStatus)
    {
        assert(self.specificAssertion)
        Logger.shared.verbose("""
            \n\(type(of: self)): \(self.debugUUID)
                - network reachability status: \(newStatus)
            """)
        let oldStatus = self.previousReachabilityStatus
        self.previousReachabilityStatus = newStatus
        if oldStatus != .notReachable &&
            newStatus == .notReachable {
            self.tryClearConnection(with: LCError.RTMConnectionNetworkUnavailable)
            self.resetConnectingDelayInterval()
        } else if oldStatus != newStatus &&
                    newStatus != .notReachable {
            self.tryClearConnection(with: LCError.RTMConnectionNetworkChanged)
            self.resetConnectingDelayInterval()
            self.tryConnecting()
        }
    }
    #endif
    
    private func checkEnvironment() -> LCError? {
        assert(self.specificAssertion)
        #if os(iOS) || os(tvOS)
        guard self.previousAppState == .foreground else {
            return LCError.RTMConnectionAppInBackground
        }
        #endif
        #if !os(watchOS)
        guard self.previousReachabilityStatus != .notReachable else {
            return LCError.RTMConnectionNetworkUnavailable
        }
        #endif
        return nil
    }
    
    private func canConnecting() -> Bool {
        assert(self.specificAssertion)
        return self.socket == nil
            && !self.allDelegators.isEmpty
            && self.checkEnvironment() == nil
    }
    
    private func connectingWorkItem() -> DispatchWorkItem {
        return DispatchWorkItem { [weak self] in
            guard let ss = self else {
                return
            }
            assert(ss.specificAssertion)
            ss.previousConnectingWorkItem = nil
            ss.getRTMServer { (result: LCGenericResult<URL>) in
                guard let self = self else {
                    return
                }
                assert(self.specificAssertion)
                guard self.canConnecting() else {
                    return
                }
                switch result {
                case .success(value: let url):
                    var request = URLRequest(url: url)
                    request.timeoutInterval = self.application.configuration.RTMConnectingTimeoutInterval
                    let socket = WebSocket(request: request, protocols: [self.lcimProtocol.rawValue])
                    socket.request.setValue(nil, forHTTPHeaderField: "Origin")
                    socket.advancedDelegate = self
                    socket.pongDelegate = self
                    socket.callbackQueue = self.serialQueue
                    socket.connect()
                    self.socket = socket
                case .failure(error: let error):
                    for item in self.allDelegators {
                        item.queue.async {
                            item.delegate?.connection(self, didDisconnect: error)
                        }
                    }
                    if error.code != 404 {
                        self.tryConnecting()
                    }
                }
            }
        }
    }
    
    private func tryConnecting() {
        assert(self.specificAssertion)
        guard self.canConnecting() else {
            return
        }
        for item in self.allDelegators {
            item.queue.async {
                item.delegate?.connection(inConnecting: self)
            }
        }
        if let workItem = self.previousConnectingWorkItem {
            workItem.cancel()
            self.previousConnectingWorkItem = nil
        }
        let workItem = self.connectingWorkItem()
        self.previousConnectingWorkItem = workItem
        let delay = self.nextConnectingDelayInterval()
        if delay > 0 {
            self.serialQueue.asyncAfter(
                deadline: .now() + .seconds(delay),
                execute: workItem)
        } else {
            workItem.perform()
        }
    }
    
    private func tryClearConnection(with error: LCError) {
        assert(self.specificAssertion)
        if let workItem = self.previousConnectingWorkItem {
            workItem.cancel()
            self.previousConnectingWorkItem = nil
        }
        if let socket = self.socket {
            socket.advancedDelegate = nil
            socket.pongDelegate = nil
            socket.disconnect()
            self.socket = nil
        }
        for item in self.allDelegators {
            item.queue.async {
                item.delegate?.connection(self, didDisconnect: error)
            }
        }
        if let timer = self.timer {
            timer.clean()
            self.timer = nil
        }
    }
    
    private func getRTMServer(callback: @escaping (LCGenericResult<URL>) -> Void) {
        assert(self.specificAssertion)
        if let customRTMServerURL = self.application.configuration.RTMCustomServerURL {
            callback(.success(value: customRTMServerURL))
        } else if let rtmRouter = self.rtmRouter,
                  !self.isInRouting {
            self.isInRouting = true
            rtmRouter.route { [weak self] (direct, result) in
                guard let self = self else {
                    return
                }
                let completion: () -> Void = {
                    self.isInRouting = false
                    switch result {
                    case .success(value: let table):
                        if let url = (self.useSecondaryServer ? table.secondaryURL : table.primaryURL) ?? table.primaryURL {
                            callback(.success(value: url))
                        } else {
                            callback(.failure(error: LCError.RTMRouterResponseDataMalformed))
                        }
                    case .failure(error: let error):
                        callback(.failure(error: error))
                    }
                }
                if direct {
                    completion()
                } else {
                    self.serialQueue.async { completion() }
                }
            }
        }
    }
    
    private func handleGoaway(inCommand: IMGenericCommand) {
        assert(self.specificAssertion)
        guard inCommand.cmd == .goaway else {
            return
        }
        if let rtmRouter = self.rtmRouter {
            rtmRouter.clearTableCache()
            self.tryClearConnection(with: LCError.RTMConnectionClosedByRemote)
            self.tryConnecting()
        }
        #if DEBUG
        NotificationCenter.default.post(
            name: RTMConnection.TestGoawayCommandReceivedNotification,
            object: self
        )
        #endif
    }
    
    private func tryPadding(
        peerID: String,
        for command: IMGenericCommand) -> IMGenericCommand?
    {
        assert(self.specificAssertion)
        if command.cmd == .session,
           command.op == .open {
            return nil
        }
        if self.needPeerIDForEveryCommandOfInstantMessaging {
            var commandWithPeerID = command
            commandWithPeerID.peerID = peerID
            return commandWithPeerID
        } else {
            return nil
        }
    }
    
    private func checkSessionOpenedPeerID(command: IMGenericCommand) {
        assert(self.specificAssertion)
        guard command.cmd == .session,
              command.op == .opened,
              let peerID = (command.hasPeerID ? command.peerID : nil) else {
            return
        }
        if let defaultPeerID = self.defaultInstantMessagingPeerID {
            if !self.needPeerIDForEveryCommandOfInstantMessaging {
                self.needPeerIDForEveryCommandOfInstantMessaging = (defaultPeerID != peerID)
            }
        } else {
            self.defaultInstantMessagingPeerID = peerID
        }
    }
    
    private func resetDefaultInstantMessagingPeerID() {
        assert(self.specificAssertion)
        self.defaultInstantMessagingPeerID = nil
        self.needPeerIDForEveryCommandOfInstantMessaging = false
    }
    
    func nextConnectingDelayInterval() -> Int {
        return RTMConnectionManager.default.nextConnectingDelayInterval(
            application: self.application)
    }
    
    func resetConnectingDelayInterval() {
        RTMConnectionManager.default.resetConnectingDelayInterval(
            application: self.application)
    }
}

extension RTMConnection: WebSocketAdvancedDelegate, WebSocketPongDelegate {
    
    // MARK: WebSocketDelegate
    
    func websocketDidConnect(socket: WebSocket) {
        assert(self.specificAssertion)
        assert(self.socket === socket && self.timer == nil)
        Logger.shared.verbose("""
            \n\(socket)
                - did connect
            """)
        self.resetDefaultInstantMessagingPeerID()
        self.resetConnectingDelayInterval()
        self.timer = Timer(connection: self, socket: socket)
        for item in self.allDelegators {
            item.queue.async {
                item.delegate?.connection(didConnect: self)
            }
        }
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: Error?) {
        assert(self.specificAssertion)
        assert(self.socket === socket)
        Logger.shared.error("""
            \n\(socket)
                - did disconnect with error: \(String(describing: error))
            """)
        self.tryClearConnection(with: LCError(error: error ?? LCError.RTMConnectionClosedByRemote))
        self.useSecondaryServer.toggle()
        self.tryConnecting()
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String, response: WebSocket.WSResponse) {
        Logger.shared.error("should never happen")
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: Data, response: WebSocket.WSResponse) {
        assert(self.specificAssertion)
        assert(self.socket === socket && self.timer != nil)
        do {
            let inCommand = try IMGenericCommand(serializedData: data)
            self.checkSessionOpenedPeerID(command: inCommand)
            Logger.shared.debug(closure: { () -> String in
                var log = "\n------ BEGIN LeanCloud In Command\n\(socket)\n"
                if inCommand.service == RTMService.instantMessaging.rawValue,
                   let defaultPeerID = self.defaultInstantMessagingPeerID {
                    log += "<DPID: \(defaultPeerID)>\n"
                }
                log += "\(inCommand)\n------ END"
                return log
            })
            if inCommand.hasI {
                self.timer?.handle(callbackCommand: inCommand)
            } else {
                var delegator: Delegator?
                if inCommand.hasService {
                    if inCommand.service == RTMService.instantMessaging.rawValue {
                        if let peerID = (inCommand.hasPeerID ? inCommand.peerID : self.defaultInstantMessagingPeerID) {
                            delegator = self.instantMessagingDelegatorMap[peerID]
                        }
                    } else if inCommand.service == RTMService.liveQuery.rawValue {
                        if let installationID = (inCommand.hasInstallationID ? inCommand.installationID : nil) {
                            delegator = self.liveQueryDelegatorMap[installationID]
                        }
                    }
                }
                delegator?.queue.async {
                    delegator?.delegate?.connection(self, didReceiveCommand: inCommand)
                }
            }
            self.handleGoaway(inCommand: inCommand)
        } catch {
            Logger.shared.error(error)
        }
    }
    
    func websocketDidReceivePong(socket: WebSocketClient, data: Data?) {
        assert(self.specificAssertion)
        assert(self.socket === socket && self.timer != nil)
        self.timer?.receivePong()
    }
    
    func websocketHttpUpgrade(socket: WebSocket, request: String) {
        Logger.shared.verbose("""
            \n\(socket)
            \(request)
            """)
    }
    
    func websocketHttpUpgrade(socket: WebSocket, response: String) {
        Logger.shared.verbose("""
            \n\(socket)
            \(response)
            """)
    }
}

private extension IMGenericCommand {
    
    var lcEncounteredError: LCError? {
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
        var userInfo: LCError.UserInfo = [:]
        if self.hasAppCode {
            userInfo["appCode"] = self.appCode
        }
        if self.hasAppMsg {
            userInfo["appMsg"] = self.appMsg
        }
        if self.hasDetail {
            userInfo["detail"] = self.detail
        }
        if !userInfo.isEmpty {
            do {
                userInfo = try userInfo.jsonObject() ?? userInfo
            } catch {
                Logger.shared.error(error)
            }
        }
        return LCError(
            code: Int(self.code),
            reason: self.hasReason ? self.reason : nil,
            userInfo: userInfo.isEmpty ? nil : userInfo)
    }
}

extension IMSessionCommand {
    
    var lcError: LCError? {
        if self.hasCode {
            var userInfo: LCError.UserInfo = [:]
            if self.hasDetail {
                userInfo["detail"] = self.detail
            }
            if !userInfo.isEmpty {
                do {
                    userInfo = try userInfo.jsonObject() ?? userInfo
                } catch {
                    Logger.shared.error(error)
                }
            }
            return LCError(
                code: Int(self.code),
                reason: self.hasReason ? self.reason : nil,
                userInfo: userInfo.isEmpty ? nil : userInfo)
        } else {
            return nil
        }
    }
}

extension IMAckCommand {
    
    var lcError: LCError? {
        if self.hasCode || self.hasAppCode {
            var userInfo: LCError.UserInfo = [:]
            if self.hasAppCode {
                userInfo["appCode"] = self.appCode
            }
            if self.hasAppMsg {
                userInfo["appMsg"] = self.appMsg
            }
            if !userInfo.isEmpty {
                do {
                    userInfo = try userInfo.jsonObject() ?? userInfo
                } catch {
                    Logger.shared.error(error)
                }
            }
            return LCError(
                code: Int(self.code),
                reason: self.hasReason ? self.reason : nil,
                userInfo: userInfo.isEmpty ? nil : userInfo)
        } else {
            return nil
        }
    }
}

private extension LCError {
    
    // MARK: Connection Lost Error
    
    static var RTMConnectionAppInBackground: LCError {
        return RTMConnectionLostError(
            reason: "application did enter background, connection lost.")
    }
    
    static var RTMConnectionNetworkUnavailable: LCError {
        return RTMConnectionLostError(
            reason: "network unavailable, connection lost.")
    }
    
    static var RTMConnectionNetworkChanged: LCError {
        return RTMConnectionLostError(
            reason: "network interface changed, connection lost.")
    }
    
    static var RTMConnectionClosedByLocal: LCError {
        return RTMConnectionLostError(
            reason: "connection did close by local peer.")
    }
    
    static var RTMConnectionClosedByRemote: LCError {
        return RTMConnectionLostError(
            reason: "connection did close by remote peer.")
    }
    
    static func RTMConnectionLostError(reason: String) -> LCError {
        return LCError(
            code: .connectionLost,
            reason: reason)
    }
}
