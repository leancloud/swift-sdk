//
//  Connection.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2018/10/17.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation
import UIKit
import Alamofire

class Command {
    
    enum Response {
        case data(IMGenericCommand)
        case error(LCError)
    }
    
    private(set) var data: IMGenericCommand
    private(set) var callback: ((Command.Response) -> Void)?
    
    init(data: IMGenericCommand, callback: ((Command.Response) -> Void)? = nil) {
        self.data = data
        self.callback = callback
    }
    
    /// for `Connection` to record send timestamp.
    fileprivate var sendTimestamp: TimeInterval = 0
    
    /// for `Connection` to set serial index.
    fileprivate func setSerialIndex(with index: Int32) {
        self.data.i = index
    }
    
    /// `Command`'s callback may retain itself,
    /// so must set callback to nil after invoking to avoid retain cycle.
    fileprivate func invokeCallback(with response: Command.Response) {
        self.callback?(response)
        self.callback = nil
    }
    
}

protocol ConnectionDelegate: class {
    func connectionDidReceiveCommand(connection: Connection, inCommand: Command)
    func connectionDidConnect(connection: Connection)
    func connectionConnectingFailed(connection: Connection, reason: Connection.Reason)
    func connectionDidDisconnect(connection: Connection, reason: Connection.Reason)
    func connectionInReconnecting(connection: Connection)
}

class Connection {
    
    enum AppState {
        case background
        case foreground
    }
    
    enum Reason {
        case userInvoked
        case networkChanged
        case networkNotReachable
        case appInBackground
        case other((error: LCError, isReconnectionOpen: Bool))
    }
    
    enum LCProtocol: String {
        case protobuf1 = "lc.protobuf2.1"
        case protobuf3 = "lc.protobuf2.3"
    }
    
    class Timer {
        
        static let pingRepeating: TimeInterval = 180.0
        static let pingTimeout: TimeInterval = 20.0
        static let repeating: Int = 1
        
        let source: DispatchSourceTimer
        private var lastPingSendTimestamp: TimeInterval = 0
        private var lastPongReceiveTimestamp: TimeInterval = 0
        
        #if DEBUG
        private let specificKey: DispatchSpecificKey<Int>
        private let specificValue: Int
        private var specificAssertion: Bool {
            return self.specificValue == DispatchQueue.getSpecific(key: self.specificKey)
        }
        #else
        private var specificAssertion: Bool {
            return true
        }
        #endif
        
        init(connection: Connection) {
            #if DEBUG
            self.specificKey = connection.specificKey
            self.specificValue = connection.specificValue
            #endif
            self.source = DispatchSource.makeTimerSource(queue: connection.serialQueue)
            self.source.setEventHandler { [weak self, weak connection] in
                guard let ss: Timer = self,
                    let conn: Connection = connection
                    else { return }
                ss.checkCommand(connection: conn)
                ss.checkPing(connection: conn)
            }
            self.source.schedule(
                deadline: .now(),
                repeating: .seconds(Timer.repeating)
            )
            self.source.resume()
        }
        
        deinit {
            self.source.cancel()
        }
        
        func setPongTimestamp() {
            assert(self.specificAssertion)
            self.lastPongReceiveTimestamp = NSDate().timeIntervalSince1970
        }
        
        private func checkCommand(connection: Connection) {
            assert(self.specificAssertion)
            let currentTS: TimeInterval = NSDate().timeIntervalSince1970
            var stopIndex: Int = 0
            for (index, commandIndex) in connection.commandIndexes.enumerated() {
                stopIndex = index + 1
                guard let command: Command = connection.commandMap[commandIndex] else {
                    continue
                }
                if currentTS < command.sendTimestamp + connection.commandTTL {
                    stopIndex = index
                    break
                }
                connection.commandMap.removeValue(forKey: commandIndex)
                connection.delegateQueue.async {
                    // TODO: error
                    command.invokeCallback(with: .error(LCError(code: 0)))
                }
            }
            if stopIndex > 0 {
                connection.commandIndexes.removeSubrange(0..<stopIndex)
            }
        }
        
        private func checkPing(connection: Connection) {
            assert(self.specificAssertion)
            let currentTS: TimeInterval = NSDate().timeIntervalSince1970
            if (self.lastPingSendTimestamp == 0) ||
                (self.lastPingSendTimestamp > self.lastPongReceiveTimestamp
                    && currentTS > self.lastPingSendTimestamp + Timer.pingTimeout) ||
                (self.lastPingSendTimestamp < self.lastPongReceiveTimestamp
                    && currentTS > self.lastPongReceiveTimestamp + Timer.pingRepeating)
            {
                connection.websocket?.write(ping: Data())
                self.lastPingSendTimestamp = currentTS
            }
        }
        
    }
    
    #if os(iOS) || os(tvOS)
    private var appState: Connection.AppState = .foreground
    private var enterBackgroundObserver: NSObjectProtocol? = nil
    private var enterForegroundObserver: NSObjectProtocol? = nil
    #endif
    #if !os(watchOS)
    private var reachabilityStatus: NetworkReachabilityManager.NetworkReachabilityStatus = .unknown
    private var reachabilityManager: NetworkReachabilityManager? = nil
    #endif
    
    private let application: LCApplication
    private weak var delegate: ConnectionDelegate?
    private let lcProtocol: Connection.LCProtocol
    private let delegateQueue: DispatchQueue
    private let commandTTL: TimeInterval
    
    private let serialQueue: DispatchQueue = DispatchQueue(label: "LeanCloud.Connection.serialQueue")
    private var websocket: WebSocket? = nil
    private var timer: Connection.Timer? = nil
    private var isReconnectionOpen: Bool = false
    private var useSecondaryServer: Bool = false
    private var commandMap: [UInt16: Command] = [:]
    private var commandIndexes: [UInt16] = []
    private var serialIndex: UInt16 = 1
    private var nextSerialIndex: UInt16 {
        let current: UInt16 = self.serialIndex
        assert(current != 0)
        if current == UInt16.max {
            self.serialIndex = 1
        } else {
            self.serialIndex += 1
        }
        return current
    }
    
    #if DEBUG
    private let specificKey = DispatchSpecificKey<Int>()
    private let specificValue: Int = Int.random(in: 1...9999999)
    private var specificAssertion: Bool {
        return self.specificValue == DispatchQueue.getSpecific(key: self.specificKey)
    }
    #else
    private var specificAssertion: Bool {
        return true
    }
    #endif
    
    init(application: LCApplication,
         delegate: ConnectionDelegate,
         lcProtocol: Connection.LCProtocol,
         delegateQueue: DispatchQueue = .main,
         commandTTL: TimeInterval = 30.0)
    {
        #if DEBUG
        self.serialQueue.setSpecific(key: self.specificKey, value: self.specificValue)
        #endif
        self.application = application
        self.delegate = delegate
        self.lcProtocol = lcProtocol
        self.delegateQueue = delegateQueue
        self.commandTTL = commandTTL
        
        #if os(iOS) || os(tvOS)
        self.appState = (UIApplication.shared.applicationState == .background ? .background : .foreground)
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = self.serialQueue
        self.enterBackgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: operationQueue) { [weak self] _ in
            guard let ss = self else { return }
            ss.applicationStateChanged(with: .background)
        }
        self.enterForegroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: operationQueue) { [weak self] _ in
            guard let ss = self else { return }
            ss.applicationStateChanged(with: .foreground)
        }
        #endif
        
        #if !os(watchOS)
        self.reachabilityManager = NetworkReachabilityManager()
        self.reachabilityStatus = self.reachabilityManager?.networkReachabilityStatus ?? .unknown
        self.reachabilityManager?.listenerQueue = self.serialQueue
        self.reachabilityManager?.listener = { [weak self] newStatus in
            guard let ss = self else { return }
            let oldStatus = ss.reachabilityStatus
            ss.reachabilityStatus = newStatus
            if oldStatus != .notReachable && newStatus == .notReachable {
                ss.internalDisconnect(with: .networkNotReachable)
            } else if oldStatus == .notReachable && newStatus != .notReachable {
                ss.tryReconnect()
            } else if oldStatus == newStatus {
                // do nothing.
            } else {
                // example: 'ethernetOrWiFi <--> wwan' ...
                ss.internalDisconnect(with: .networkChanged)
                ss.tryReconnect()
            }
        }
        self.reachabilityManager?.startListening()
        #endif
    }
    
    deinit {
        #if os(iOS) || os(tvOS)
        for item in [self.enterBackgroundObserver, self.enterForegroundObserver] {
            if let observer: NSObjectProtocol = item {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        #endif
        #if !os(watchOS)
        self.reachabilityManager?.stopListening()
        #endif
    }
    
    func connect() {
        self.serialQueue.async {
            guard self.websocket == nil && !self.isReconnectionOpen else {
                // ignore connect action when websocket exists or reconnection is opened.
                return
            }
            #if os(iOS) || os(tvOS)
            guard self.appState == .foreground else {
                self.delegateQueue.async {
                    self.delegate?.connectionConnectingFailed(connection: self, reason: .appInBackground)
                }
                return
            }
            #endif
            #if !os(watchOS)
            guard self.reachabilityStatus != .notReachable else {
                self.delegateQueue.async {
                    self.delegate?.connectionConnectingFailed(connection: self, reason: .networkNotReachable)
                }
                return
            }
            #endif
            self.internalConnect(isReconnecting: false)
        }
    }
    
    func setReconnection(with isOpen: Bool) {
        self.serialQueue.async {
            self.isReconnectionOpen = isOpen
        }
    }
    
    func disconnect() {
        self.serialQueue.async {
            self.internalDisconnect(with: .userInvoked)
        }
    }
    
    func send(command: Command) {
        self.serialQueue.async {
            let hasCallback: Bool = (command.callback != nil)
            guard let websocket: WebSocket = self.websocket, websocket.isConnected else {
                if hasCallback {
                    self.delegateQueue.async {
                        // TODO: error
                        command.invokeCallback(with: .error(LCError(code: 0)))
                    }
                }
                return
            }
            var serialIndex: UInt16? = nil
            if hasCallback {
                serialIndex = self.nextSerialIndex
                command.setSerialIndex(with: Int32(serialIndex!))
            }
            var serializedData: Data? = nil
            do {
                serializedData = try command.data.serializedData()
            } catch {
                // TODO: log
            }
            guard let data: Data = serializedData, data.count <= 5000 else {
                if hasCallback {
                    self.delegateQueue.async {
                        // TODO: error
                        command.invokeCallback(with: .error(LCError(code: 0)))
                    }
                }
                return
            }
            if let index: UInt16 = serialIndex {
                self.commandIndexes.append(index)
                self.commandMap[index] = command
            }
            command.sendTimestamp = NSDate().timeIntervalSince1970
            websocket.write(data: data)
        }
    }
    
}

// MARK: - Internal

extension Connection {
    
    private func internalConnect(isReconnecting: Bool) {
        assert(self.specificAssertion)
        assert(self.websocket == nil && self.timer == nil && self.commandIndexes.isEmpty && self.commandMap.isEmpty)
        // TODO: RTM server
        guard let url: URL = URL(string: self.useSecondaryServer ? "Secondary" : "Primary") else {
            self.isReconnectionOpen = false
            // TODO: error
            let reason: Connection.Reason = .other((LCError(code: 0), self.isReconnectionOpen))
            self.delegateQueue.async {
                if isReconnecting {
                    self.delegate?.connectionDidDisconnect(connection: self, reason: reason)
                } else {
                    self.delegate?.connectionConnectingFailed(connection: self, reason: reason)
                }
            }
            return
        }
        let websocket: WebSocket = WebSocket(url: url, protocols: [self.lcProtocol.rawValue])
        websocket.delegate = self
        websocket.pongDelegate = self
        websocket.callbackQueue = self.serialQueue
        self.websocket = websocket
        if isReconnecting {
            self.delegateQueue.async {
                self.delegate?.connectionInReconnecting(connection: self)
            }
        }
        websocket.connect()
    }
    
    private func internalDisconnect(with reason: Connection.Reason) {
        assert(self.specificAssertion)
        if let timer: Connection.Timer = self.timer {
            timer.source.cancel()
            self.timer = nil
        }
        if let websocket: WebSocket = self.websocket {
            websocket.delegate = nil
            websocket.disconnect()
            self.websocket = nil
            self.delegateQueue.async {
                self.delegate?.connectionDidDisconnect(connection: self, reason: reason)
            }
        }
        let commands: Dictionary<UInt16, Command>.Values = self.commandMap.values
        self.commandMap.removeAll()
        self.commandIndexes.removeAll()
        self.serialIndex = 1
        self.delegateQueue.async {
            // TODO: error
            let error: LCError = LCError(code: 0)
            for command in commands {
                command.invokeCallback(with: .error(error))
            }
        }
    }
    
    private func applicationStateChanged(with newState: Connection.AppState) {
        assert(self.specificAssertion)
        let oldState: Connection.AppState = self.appState
        self.appState = newState
        switch (oldState, newState) {
        case (.background, .foreground):
            self.tryReconnect()
        case (.foreground, .background):
            self.internalDisconnect(with: .appInBackground)
        default:
            break
        }
    }
    
    private func tryReconnect() {
        assert(self.specificAssertion)
        var flag: Bool = true
        #if os(iOS) || os(tvOS)
        flag = (self.appState == .foreground)
        #endif
        #if !os(watchOS)
        if flag && self.reachabilityStatus != .notReachable && self.isReconnectionOpen {
            self.internalConnect(isReconnecting: true)
        }
        #endif
    }
    
}

// MARK: - WebSocketDelegate

extension Connection: WebSocketDelegate, WebSocketPongDelegate {
    
    func websocketDidConnect(socket: WebSocketClient) {
        assert(self.specificAssertion && self.websocket === socket && self.timer == nil)
        self.timer = Timer(connection: self)
        self.delegateQueue.async {
            self.delegate?.connectionDidConnect(connection: self)
        }
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        assert(self.specificAssertion && self.websocket === socket)
        // TODO: error
        if let wsError: WSError = error as? WSError {
            switch wsError.type {
            case .outputStreamWriteError, .upgradeError, .writeTimeoutError:
                if wsError.type == .upgradeError {
                    self.useSecondaryServer.toggle()
                }
                let reason: Connection.Reason = .other((LCError(code: 0), self.isReconnectionOpen))
                self.internalDisconnect(with: reason)
            case .protocolError:
                self.isReconnectionOpen = false
                let reason: Connection.Reason = .other((LCError(code: 0), self.isReconnectionOpen))
                self.internalDisconnect(with: reason)
            case .compressionError, .invalidSSLError, .closeError:
                assertionFailure("should not occurred.")
            }
        } else if let streamError: NSError = error as NSError? {
            let reason: Connection.Reason = .other((LCError(code: streamError.code), self.isReconnectionOpen))
            self.internalDisconnect(with: reason)
        } else {
            assertionFailure("should not occurred.")
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        assert(self.specificAssertion && self.websocket === socket)
        let gpbCommand: IMGenericCommand
        do {
            gpbCommand = try IMGenericCommand(serializedData: data)
        } catch {
            // TODO: log
            return
        }
        let index: Int32? = (gpbCommand.hasI ? gpbCommand.i : nil)
        if let index: Int32 = index {
            if index >= 1 && index <= UInt16.max {
                let serialIndex: UInt16 = UInt16(index)
                guard let outCommand: Command = self.commandMap.removeValue(forKey: serialIndex) else {
                    return
                }
                if let arrayIndex: Int = self.commandIndexes.firstIndex(of: serialIndex) {
                    self.commandIndexes.remove(at: arrayIndex)
                }
                self.delegateQueue.async {
                    outCommand.invokeCallback(with: .data(gpbCommand))
                }
            } else {
                // TODO: log
            }
        } else {
            let inCommand: Command = Command(data: gpbCommand)
            self.delegateQueue.async {
                self.delegate?.connectionDidReceiveCommand(connection: self, inCommand: inCommand)
            }
        }
    }
    
    func websocketDidReceivePong(socket: WebSocketClient, data: Data?) {
        assert(self.specificAssertion && self.websocket === socket)
        self.timer?.setPongTimestamp()
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        assertionFailure("should not be invoked.")
    }
    
}
