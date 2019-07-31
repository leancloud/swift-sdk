//
//  LiveQueryClient.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2019/7/26.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import Foundation

class LiveQueryClientManager {
    
    static let `default` = LiveQueryClientManager()
    
    private init() {}
    
    private let mutex = NSLock()
    
    private var registry: [String: LiveQueryClient] = [:]
    
    func register(application: LCApplication) throws -> LiveQueryClient {
        self.mutex.lock()
        defer {
            self.mutex.unlock()
        }
        let appID: String = application.id
        if let client = self.registry[appID] {
            return client
        } else {
            let client = try LiveQueryClient(application: application)
            self.registry[appID] = client
            return client
        }
    }
    
    func unregister(application: LCApplication) {
        self.mutex.lock()
        defer {
            self.mutex.unlock()
        }
        self.registry.removeValue(forKey: application.id)
    }
    
}

class LiveQueryClient {
    
    #if DEBUG
    let specificKey = DispatchSpecificKey<Int>()
    let specificValue: Int = Int.random(in: 1...999)
    var specificAssertion: Bool {
        return self.specificValue == DispatchQueue.getSpecific(key: self.specificKey)
    }
    #else
    var specificAssertion: Bool {
        return true
    }
    #endif
    
    enum SessionState {
        case loggingIn
        case loggedIn(clientTimestamp: Int64)
        case loggingOut
        case loggedOut
        case disconnected(error: LCError?)
        case failure(error: LCError?)
    }
    
    let application: LCApplication
    
    weak var delegate: LiveQueryClientDelegate?
    
    var eventQueue: DispatchQueue = .main
    
    let connection: RTMConnection
    
    let connectionDelegator: RTMConnection.Delegator
    
    let ID: String = "livequery-\(Utility.UDID)"
    
    let serialQueue: DispatchQueue = DispatchQueue(label: "\(LiveQueryClient.self).serialQueue")
    
    var subscribingMap: [String: LiveQuery.WeakWrapper] = [:]
    
    var subscribedMap: [String: LiveQuery.WeakWrapper] = [:]
    
    var sessionState: SessionState {
        set {
            sync(self.underlyingSessionState = newValue)
        }
        get {
            var value: SessionState!
            sync(value = self.underlyingSessionState)
            return value
        }
    }
    var underlyingSessionState: SessionState = .disconnected(error: nil)
    
    let lock = NSLock()
    
    deinit {
        self.connection.removeDelegator(peerID: self.ID)
        RTMConnectionManager.default.unregister(
            application: self.application,
            service: .liveQuery
        )
    }
    
    init(application: LCApplication) throws {
        #if DEBUG
        self.serialQueue.setSpecific(key: self.specificKey, value: self.specificValue)
        #endif
        self.application = application
        self.connection = try RTMConnectionManager.default.register(
            application: application,
            service: .liveQuery
        )
        self.connectionDelegator = RTMConnection.Delegator(queue: self.serialQueue)
    }
    
    func login(liveQuery: LiveQuery) {
        self.serialQueue.async {
            
            self.subscribingMap[liveQuery.uuid] = LiveQuery.WeakWrapper(liveQuery: liveQuery)
            
            switch self.sessionState {
            case .loggingIn, .loggingOut:
                break
            case .loggedIn(clientTimestamp: let clientTimestamp):
                liveQuery.subscribe(clientID: self.ID, clientTimestamp: clientTimestamp)
            case .loggedOut, .disconnected, .failure:
                self.connectionDelegator.delegate = self
                self.connection.connect(peerID: self.ID, delegator: self.connectionDelegator)
            }
        }
    }
    
    func logout() {
        self.serialQueue.async {
            switch self.sessionState {
            case .loggedIn:
                self.sessionState = .loggingOut
                self.sendLogoutCommand()
            default:
                break
            }
        }
    }
    
    func newLiveQueryCommand(type: IMCommandType) -> IMGenericCommand {
        assert(type == .login || type == .logout)
        var outCommand = IMGenericCommand()
        outCommand.cmd = type
        if type == .login {
            outCommand.clientTs = Int64(Date().timeIntervalSince1970 * 1000.0)
        }
        outCommand.appID = self.application.id
        outCommand.installationID = self.ID
        outCommand.service = RTMService.liveQuery.rawValue
        return outCommand
    }
    
    func sendLoginCommand() {
        assert(self.specificAssertion)
        guard !self.subscribingMap.isEmpty else {
            return
        }
        let outCommand = self.newLiveQueryCommand(type: .login)
        self.connection.send(command: outCommand, callingQueue: self.serialQueue) { [weak self] (result) in
            assert(self?.specificAssertion ?? true)
            switch result {
            case .inCommand(let inCommand):
                self?.handle(callbackCommand: inCommand, outCommand: outCommand)
            case .error(let error):
                self?.handle(callbackError: error, outCommand: outCommand)
            }
        }
    }
    
    func sendLogoutCommand() {
        assert(self.specificAssertion)
        let outCommand = self.newLiveQueryCommand(type: .logout)
        self.connection.send(command: outCommand, callingQueue: self.serialQueue) { [weak self] (result) in
            assert(self?.specificAssertion ?? true)
            switch result {
            case .inCommand(let inCommand):
                self?.handle(callbackCommand: inCommand, outCommand: outCommand)
            case .error(let error):
                self?.handle(callbackError: error, outCommand: outCommand)
            }
        }
    }
    
    func handle(callbackCommand command: IMGenericCommand, outCommand: IMGenericCommand) {
        assert(self.specificAssertion)
        let sessionState: SessionState
        switch command.cmd {
        case .loggedin:
            let clientTimestamp = outCommand.clientTs
            sessionState = .loggedIn(clientTimestamp: clientTimestamp)
            
            for item in self.subscribingMap.values {
                item.reference?.subscribe(clientID: self.ID, clientTimestamp: clientTimestamp)
            }
            self.subscribingMap.removeAll()
        case .loggedout:
            sessionState = .loggedOut
            
            self.subscribingMap.removeAll()
            self.subscribedMap.removeAll()
            
            self.connectionDelegator.delegate = nil
            self.connection.removeDelegator(peerID: self.ID)
        default:
            let error = LCError(code: .commandInvalid)
            sessionState = .failure(error: error)
        }
        self.sessionState = sessionState
        self.eventQueue.async {
            self.delegate?.client(self, sessionState: sessionState)
        }
    }
    
    func handle(callbackError error: LCError, outCommand: IMGenericCommand) {
        assert(self.specificAssertion)
        switch error.code {
        case LCError.InternalErrorCode.commandTimeout.rawValue:
            switch outCommand.cmd {
            case .login:
                self.sendLoginCommand()
            case .logout:
                self.sendLogoutCommand()
            default:
                break
            }
        case LCError.InternalErrorCode.connectionLost.rawValue:
            break
        default:
            let sessionState: SessionState = .failure(error: error)
            self.sessionState = sessionState
            self.eventQueue.async {
                self.delegate?.client(self, sessionState: sessionState)
            }
        }
    }
    
}

extension LiveQueryClient: InternalSynchronizing {
    
    var mutex: NSLock {
        return self.lock
    }
    
}

extension LiveQueryClient: RTMConnectionDelegate {
    
    func connection(inConnecting connection: RTMConnection) {
        assert(self.specificAssertion)
        let sessionState: SessionState = .loggingIn
        self.sessionState = sessionState
        self.eventQueue.async {
            self.delegate?.client(self, sessionState: sessionState)
        }
    }
    
    func connection(didConnect connection: RTMConnection) {
        assert(self.specificAssertion)
        self.sendLoginCommand()
    }
    
    func connection(_ connection: RTMConnection, didDisconnect error: LCError) {
        assert(self.specificAssertion)
        let sessionState: SessionState = .disconnected(error: error)
        self.sessionState = sessionState
        
        for item in self.subscribedMap.values {
            if let liveQuery = item.reference {
                liveQuery.queryID = nil
                self.subscribingMap[liveQuery.uuid] = item
            }
        }
        self.subscribedMap.removeAll()
        
        self.eventQueue.async {
            self.delegate?.client(self, sessionState: sessionState)
        }
    }
    
    func connection(_ connection: RTMConnection, didReceiveCommand inCommand: IMGenericCommand) {
        assert(self.specificAssertion)
        guard inCommand.service == RTMService.liveQuery.rawValue else {
            return
        }
        switch inCommand.cmd {
        case .data:
            let messages = inCommand.dataMessage.msg
            for message in messages {
                guard let data = (message.hasData ? message.data : nil) else {
                    continue
                }
                do {
                    if
                        let jsonObject: [String: Any] = try data.jsonObject(),
                        let queryID = jsonObject["query_id"] as? String,
                        let liveQuery = self.subscribedMap[queryID]?.reference
                    {
                        liveQuery.process(jsonObject: jsonObject)
                    }
                } catch {
                    Logger.shared.error(error)
                }
            }
        default:
            break
        }
    }
    
}

protocol LiveQueryClientDelegate: class {
    
    func client(_ client: LiveQueryClient, sessionState: LiveQueryClient.SessionState)
    
}
