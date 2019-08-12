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
    
    private var registry: [LCApplication.Identifier: LiveQueryClient] = [:]
    
    private var localInstanceIDSet: Set<LiveQuery.LocalInstanceID> = []
    
    func register(application: LCApplication) throws -> LiveQueryClient {
        self.mutex.lock()
        defer {
            self.mutex.unlock()
        }
        let appID: LCApplication.Identifier = application.id
        if let client = self.registry[appID] {
            return client
        } else {
            let client = try LiveQueryClient(application: application)
            self.registry[appID] = client
            return client
        }
    }
    
    func newLocalInstanceID() -> LiveQuery.LocalInstanceID {
        self.mutex.lock()
        defer {
            self.mutex.unlock()
        }
        var uuid = UUID().uuidString
        while self.localInstanceIDSet.contains(uuid) {
            uuid = UUID().uuidString
        }
        return uuid
    }
    
    func releaseLocalInstanceID(_ uuid: LiveQuery.LocalInstanceID) {
        self.mutex.lock()
        defer {
            self.mutex.unlock()
        }
        self.localInstanceIDSet.remove(uuid)
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
        case disconnected(error: LCError?)
        case failure(error: LCError?)
    }
    
    let application: LCApplication
    
    let connection: RTMConnection
    
    let connectionDelegator: RTMConnection.Delegator
    
    typealias Identifier = String
    
    let ID: LiveQueryClient.Identifier = "livequery-\(Utility.UDID)"
    
    let serialQueue: DispatchQueue = DispatchQueue(label: "\(LiveQueryClient.self).serialQueue")
    
    var subscribingCallbackMap: [LiveQuery.LocalInstanceID: (LCGenericResult<Int64>) -> Void] = [:]
    var retainedLiveQueryMap: [LiveQuery.LocalInstanceID: LiveQuery.WeakWrapper] = [:]
    var subscribedLiveQueryMap: [LiveQuery.RemoteQueryID: LiveQuery.WeakWrapper] = [:]
    
    var sessionState: SessionState = .disconnected(error: nil)
    
    deinit {
        let service: RTMConnection.Service = .liveQuery(ID: self.ID)
        self.connection.removeDelegator(service: service)
        RTMConnectionManager.default.unregister(
            application: self.application,
            service: service
        )
    }
    
    init(application: LCApplication) throws {
        #if DEBUG
        self.serialQueue.setSpecific(key: self.specificKey, value: self.specificValue)
        #endif
        self.application = application
        self.connection = try RTMConnectionManager.default.register(
            application: application,
            service: .liveQuery(ID: self.ID)
        )
        self.connectionDelegator = RTMConnection.Delegator(queue: self.serialQueue)
    }
    
    func insertSubscribeCallback(localInstanceID: LiveQuery.LocalInstanceID, callback: @escaping (LCGenericResult<Int64>) -> Void) {
        self.serialQueue.async {
            let sessionState = self.sessionState
            switch sessionState {
            case .loggedIn(clientTimestamp: let clientTimestamp):
                callback(.success(value: clientTimestamp))
            case .loggingIn, .disconnected, .failure:
                self.subscribingCallbackMap[localInstanceID] = callback
            }
            switch sessionState {
            case .disconnected, .failure:
                self.connectionDelegator.delegate = self
                self.connection.connect(service: .liveQuery(ID: self.ID), delegator: self.connectionDelegator)
            default:
                break
            }
        }
    }
    
    func newLiveQueryCommand(type: IMCommandType) -> IMGenericCommand {
        assert(type == .login)
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
        guard !self.subscribingCallbackMap.isEmpty || !self.retainedLiveQueryMap.isEmpty else {
            return
        }
        self.sessionState = .loggingIn
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
    
    func handle(callbackCommand command: IMGenericCommand, outCommand: IMGenericCommand) {
        assert(self.specificAssertion)
        switch command.cmd {
        case .loggedin:
            let clientTimestamp = outCommand.clientTs
            self.sessionState = .loggedIn(clientTimestamp: clientTimestamp)
            
            var localInstanceIDSet: Set<LiveQuery.LocalInstanceID> = []
            for (key, value) in self.subscribingCallbackMap {
                localInstanceIDSet.insert(key)
                value(.success(value: clientTimestamp))
            }
            self.subscribingCallbackMap.removeAll()
            
            for (key, value) in self.retainedLiveQueryMap {
                if let liveQuery = value.reference, !localInstanceIDSet.contains(key) {
                    liveQuery.subscribing(clientTimestamp: clientTimestamp)
                }
            }
            self.retainedLiveQueryMap.removeAll()
        default:
            let error = LCError(code: .commandInvalid)
            self.sessionState = .failure(error: error)
            self.purgeContainers(error: error)
        }
    }
    
    func handle(callbackError error: LCError, outCommand: IMGenericCommand) {
        assert(self.specificAssertion)
        switch error.code {
        case LCError.InternalErrorCode.commandTimeout.rawValue:
            switch outCommand.cmd {
            case .login:
                self.sendLoginCommand()
            default:
                break
            }
        case LCError.InternalErrorCode.connectionLost.rawValue:
            break
        default:
            self.sessionState = .failure(error: error)
            self.purgeContainers(error: error)
        }
    }
    
    func purgeContainers(error: LCError) {
        assert(self.specificAssertion)
        for item in self.subscribingCallbackMap.values {
            item(.failure(error: error))
        }
        self.subscribingCallbackMap.removeAll()
        self.retainedLiveQueryMap.removeAll()
    }
    
    func insertSubscribedLiveQuery(instance: LiveQuery, queryID: LiveQuery.RemoteQueryID) {
        self.serialQueue.async {
            self.subscribedLiveQueryMap[queryID] = LiveQuery.WeakWrapper(instance: instance)
        }
    }
    
    func removeSubscribedLiveQuery(
        localInstanceID: LiveQuery.LocalInstanceID,
        remoteQueryID: LiveQuery.RemoteQueryID)
    {
        self.serialQueue.async {
            self.retainedLiveQueryMap.removeValue(forKey: localInstanceID)
            self.subscribedLiveQueryMap.removeValue(forKey: remoteQueryID)
        }
    }
    
}

extension LiveQueryClient: RTMConnectionDelegate {
    
    func connection(inConnecting connection: RTMConnection) {}
    
    func connection(didConnect connection: RTMConnection) {
        assert(self.specificAssertion)
        self.sendLoginCommand()
    }
    
    func connection(_ connection: RTMConnection, didDisconnect error: LCError) {
        assert(self.specificAssertion)
        
        self.sessionState = .disconnected(error: error)
        
        for item in self.subscribingCallbackMap.values {
            item(.failure(error: error))
        }
        self.subscribingCallbackMap.removeAll()
        
        for item in self.subscribedLiveQueryMap.values {
            guard let liveQuery = item.reference else {
                continue
            }
            self.retainedLiveQueryMap[liveQuery.localInstanceID] = item
            liveQuery.eventQueue.async {
                liveQuery.eventHandler(liveQuery, .state(.disconnected))
            }
        }
        self.subscribedLiveQueryMap.removeAll()
        
        if self.retainedLiveQueryMap.isEmpty {
            self.connectionDelegator.delegate = nil
            self.connection.removeDelegator(service: .liveQuery(ID: self.ID))
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
                        let liveQuery = self.subscribedLiveQueryMap[queryID]?.reference
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
