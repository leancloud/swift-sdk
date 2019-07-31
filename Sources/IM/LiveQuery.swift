//
//  LiveQuery.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2019/7/27.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import Foundation

class LiveQuery {
    
    enum Event {
        case create(object: LCObject)
        case update(object: LCObject, updatedKeys: [String])
        case enter(object: LCObject, updatedKeys: [String])
        case leave(object: LCObject, updatedKeys: [String])
        case delete(object: LCObject)
        
        case login(user: LCUser)
        
        case subscribing
        case subscribed
        case failureOnSubscribe(error: LCError)
    }
    
    class WeakWrapper {
        weak var reference: LiveQuery?
        
        init(liveQuery: LiveQuery) {
            self.reference = liveQuery
        }
    }
    
    let application: LCApplication
    
    let query: LCQuery
    
    let eventHandler: (LiveQuery, Event) -> Void
    
    let client: LiveQueryClient
    
    let uuid = UUID().uuidString
    
    let lock = NSLock()
    
    var queryID: String? {
        set {
            sync(self.underlyingQueryID = newValue)
        }
        get {
            var value: String?
            sync(value = self.underlyingQueryID)
            return value
        }
    }
    var underlyingQueryID: String?
    
    init(application: LCApplication = .default, query: LCQuery, eventHandler: @escaping (LiveQuery, Event) -> Void) throws {
        self.application = application
        self.query = query
        self.client = try LiveQueryClientManager.default.register(application: application)
        self.eventHandler = eventHandler
    }
    
    func subscribe() throws {
        guard self.queryID == nil else {
            throw LCError(code: .inconsistency, reason: "has subscribed.")
        }
        self.client.login(liveQuery: self)
    }
    
    func subscribe(clientID: String, clientTimestamp: Int64) {
        self.client.eventQueue.async {
            self.eventHandler(self, .subscribing)
        }
        
        var parameter: [String: Any] = [
            "query": self.query.lconValue,
            "id": clientID,
            "clientTimestamp": clientTimestamp
        ]
        if let sessionToken: String = self.application.currentUser?.sessionToken?.stringValue {
            parameter["sessionToken"] = sessionToken
        }
        
        _ = self.application.httpClient.request(
            .post,
            "LiveQuery/subscribe",
            parameters: parameter)
        { (response) in
            self.client.serialQueue.async {
                self.client.subscribingMap.removeValue(forKey: self.uuid)
            }
            if let error = LCError(response: response) {
                self.client.eventQueue.async {
                    self.eventHandler(self, .failureOnSubscribe(error: error))
                }
            } else {
                if let result = response.value as? [String: Any],
                    let queryID = result["query_id"] as? String {
                    self.queryID = queryID
                    self.client.serialQueue.async {
                        self.client.subscribedMap[queryID] = LiveQuery.WeakWrapper(liveQuery: self)
                    }
                    self.client.eventQueue.async {
                        self.eventHandler(self, .subscribed)
                    }
                } else {
                    self.client.eventQueue.async {
                        let error = LCError(code: .malformedData, reason: "response value invalid.")
                        self.eventHandler(self, .failureOnSubscribe(error: error))
                    }
                }
            }
        }
    }
    
    func unsubscribe(completion: @escaping (LCBooleanResult) -> Void) {
        guard let queryID = self.queryID else {
            self.client.eventQueue.async {
                let error = LCError(code: .inconsistency, reason: "Query ID not found.")
                completion(.failure(error: error))
            }
            return
        }
        
        let parameter: [String: Any] = [
            "id": self.client.ID,
            "query_id": queryID
        ]
        
        _ = self.application.httpClient.request(
            .post,
            "LiveQuery/unsubscribe",
            parameters: parameter)
        { (response) in
            if let error = LCError(response: response) {
                self.client.eventQueue.async {
                    completion(.failure(error: error))
                }
            } else {
                self.queryID = nil
                self.client.serialQueue.async {
                    self.client.subscribingMap.removeValue(forKey: self.uuid)
                    self.client.subscribedMap.removeValue(forKey: queryID)
                }
                self.client.eventQueue.async {
                    completion(.success)
                }
            }
        }
    }
    
    func process(jsonObject: [String: Any]) {
        do {
            guard
                let op = jsonObject["op"] as? String,
                let objectRawData = jsonObject["object"] as? [String: Any],
                let object = try ObjectProfiler.shared.object(
                    application: self.application,
                    dictionary: objectRawData,
                    dataType: .object) as? LCObject else
            {
                return
            }
            let updatedKeys = (jsonObject["updatedKeys"] as? [String]) ?? []
            var event: LiveQuery.Event?
            switch op {
            case "create":
                event = .create(object: object)
            case "update":
                event = .update(object: object, updatedKeys: updatedKeys)
            case "enter":
                event = .enter(object: object, updatedKeys: updatedKeys)
            case "leave":
                event = .leave(object: object, updatedKeys: updatedKeys)
            case "delete":
                event = .delete(object: object)
            case "login":
                if let user = object as? LCUser {
                    event = .login(user: user)
                }
            default:
                break
            }
            if let event = event {
                self.client.eventQueue.async {
                    self.eventHandler(self, event)
                }
            }
        } catch {
            Logger.shared.error(error)
        }
    }
    
}

extension LiveQuery: InternalSynchronizing {
    
    var mutex: NSLock {
        return self.lock
    }
    
}
