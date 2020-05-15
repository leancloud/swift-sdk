//
//  LiveQuery.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2019/7/27.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import Foundation

public class LiveQuery {
    
    public enum Event {
        case create(object: LCObject)
        case update(object: LCObject, updatedKeys: [String])
        case enter(object: LCObject, updatedKeys: [String])
        case leave(object: LCObject, updatedKeys: [String])
        case delete(object: LCObject)
        
        case login(user: LCUser)
        
        public enum State {
            case disconnected
            case subscribing
            case subscribed
            case failureOnSubscribe(error: LCError)
        }
        
        case state(State)
    }
    
    class WeakWrapper {
        weak var reference: LiveQuery?
        
        init(instance: LiveQuery) {
            self.reference = instance
        }
    }
    
    public let application: LCApplication
    
    public let query: LCQuery
    
    public let eventQueue: DispatchQueue
    
    public let eventHandler: (LiveQuery, Event) -> Void
    
    let client: LiveQueryClient
    
    typealias LocalInstanceID = String
    let localInstanceID: LocalInstanceID
    
    typealias RemoteQueryID = String
    var queryID: RemoteQueryID?
    
    deinit {
        LiveQueryClientManager.default
            .unregister(application: self.application)
        LiveQueryClientManager.default
            .releaseLocalInstanceID(self.localInstanceID)
    }
    
    public init(
        application: LCApplication = .default,
        query: LCQuery,
        eventQueue: DispatchQueue = .main,
        eventHandler: @escaping (LiveQuery, Event) -> Void)
        throws
    {
        guard application === query.application else {
            throw LCError(
                code: .inconsistency,
                reason: "`application` !== `query.application`, they should be the same instance.")
        }
        self.application = application
        self.query = query
        self.eventQueue = eventQueue
        self.eventHandler = eventHandler
        self.client = try LiveQueryClientManager.default.register(application: application)
        self.localInstanceID = LiveQueryClientManager.default.newLocalInstanceID()
    }
    
    public func subscribe(completion: @escaping (LCBooleanResult) -> Void) {
        self.client.insertSubscribeCallback(localInstanceID: self.localInstanceID) { [weak self] (result) in
            switch result {
            case .success(value: let clientTimestamp):
                self?.subscribing(
                    clientTimestamp: clientTimestamp,
                    completion: completion
                )
            case .failure(error: let error):
                self?.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        }
    }
    
    func subscribing(clientTimestamp: Int64, completion: ((LCBooleanResult) -> Void)? = nil) {
        if completion == nil {
            self.eventQueue.async {
                self.eventHandler(self, .state(.subscribing))
            }
        }
        var parameter: [String: Any] = [
            "query": self.query.lconValue,
            "id": self.client.ID,
            "clientTimestamp": clientTimestamp,
        ]
        if let sessionToken: String = self.application._currentUser?.sessionToken?.value {
            parameter["sessionToken"] = sessionToken
        }
        _ = self.application.httpClient.request(
            .post, "LiveQuery/subscribe",
            parameters: parameter)
        { (response) in
            let handleError: (LCError) -> Void = { error in
                self.eventQueue.async {
                    if let completion = completion {
                        completion(.failure(error: error))
                    } else {
                        self.eventHandler(self, .state(.failureOnSubscribe(error: error)))
                    }
                }
            }
            if let error = LCError(response: response) {
                handleError(error)
            } else {
                if let result = response.value as? [String: Any], let queryID = result["query_id"] as? String {
                    self.queryID = queryID
                    self.client.insertSubscribedLiveQuery(instance: self, queryID: queryID)
                    self.eventQueue.async {
                        if let completion = completion {
                            completion(.success)
                        } else {
                            self.eventHandler(self, .state(.subscribed))
                        }
                    }
                } else {
                    handleError(LCError(code: .malformedData))
                }
            }
        }
    }
    
    public func unsubscribe(completion: @escaping (LCBooleanResult) -> Void) {
        guard let queryID = self.queryID else {
            self.eventQueue.async {
                let error = LCError(code: .inconsistency, reason: "Query ID not found.")
                completion(.failure(error: error))
            }
            return
        }
        self.client.removeSubscribedLiveQuery(localInstanceID: self.localInstanceID, remoteQueryID: queryID)
        let parameter: [String: Any] = [
            "id": self.client.ID,
            "query_id": queryID,
        ]
        _ = self.application.httpClient.request(
            .post, "LiveQuery/unsubscribe",
            parameters: parameter)
        { (response) in
            if let error = LCError(response: response) {
                self.eventQueue.async {
                    completion(.failure(error: error))
                }
            } else {
                self.queryID = nil
                self.eventQueue.async {
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
                self.eventQueue.async {
                    self.eventHandler(self, event)
                }
            }
        } catch {
            Logger.shared.error(error)
        }
    }
    
}
