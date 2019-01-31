//
//  IMConversationTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2019/1/20.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import XCTest
import Alamofire
@testable import LeanCloud

class IMConversationTestCase: RTMBaseTestCase {
    
    private lazy var v2Router = HTTPRouter(
        application: .default,
        configuration: HTTPRouter.Configuration(apiVersion: "1.2")
    )

    func testCreateConversationErrorThrows() {
        
        let client: LCClient = try! LCClient(ID: uuid)
        
        let errExp = expectation(description: "not open")
        try? client.createConversation(clientIDs: []) { (r) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertFalse(r.isSuccess)
            XCTAssertNotNil(r.error)
            errExp.fulfill()
        }
        wait(for: [errExp], timeout: timeout)
        
        do {
            let invalidID: String = Array<String>.init(repeating: "a", count: 65).joined()
            try client.createConversation(clientIDs: [invalidID], completion: { (_) in })
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
    }
    
    func testCreateNormalConversation() {
        guard
            let clientA = newOpenedClient(),
            let clientB = newOpenedClient()
            else
        {
            XCTFail()
            return
        }
        
        let delegatorA = IMClientTestCase.Delegator()
        clientA.delegate = delegatorA
        let delegatorB = IMClientTestCase.Delegator()
        clientB.delegate = delegatorB
        
        let name: String? = "normalConv"
        let attribution: [String: Any]? = [
            "String": "",
            "Int": 1,
            "Double": 1.0,
            "Bool": true,
            "Array": Array<String>(),
            "Dictionary": Dictionary<String, Any>()
        ]
        
        let convAssertion: (LCConversation, LCClient) -> Void = { conv, client in
            XCTAssertTrue(type(of: conv) == LCConversation.self)
            XCTAssertEqual(conv.type, .normal)
            XCTAssertEqual(conv.members?.count, 2)
            XCTAssertEqual(conv.members?.contains(clientA.ID), true)
            XCTAssertEqual(conv.members?.contains(clientB.ID), true)
            XCTAssertNotNil(conv.client)
            if let c: LCClient = conv.client {
                XCTAssertTrue(c === client)
            }
            XCTAssertEqual(conv.clientID, client.ID)
            XCTAssertFalse(conv.isUnique)
            XCTAssertNil(conv.uniqueID)
            XCTAssertEqual(conv.creator, clientA.ID)
            XCTAssertNotNil(conv.createdAt)
            XCTAssertFalse(conv.isMuted)
            XCTAssertFalse(conv.isOutdated)
            XCTAssertNil(conv.lastMessage)
            XCTAssertEqual(conv.unreadMessageCount, 0)
            XCTAssertFalse(conv.isUnreadMessageContainMention)
            if let name: String = name {
                XCTAssertEqual(name, conv.name)
            } else {
                XCTAssertNil(conv.name)
            }
            if let attribution: [String: Any] = attribution {
                XCTAssertEqual(attribution.count, conv.attributes?.count)
                for (key, value) in attribution {
                    switch key {
                    case "String":
                        XCTAssertEqual(value as? String, conv.attributes?[key] as? String)
                    case "Int":
                        XCTAssertEqual(value as? Int, conv.attributes?[key] as? Int)
                    case "Double":
                        XCTAssertEqual(value as? Double, conv.attributes?[key] as? Double)
                    case "Bool":
                        XCTAssertEqual(value as? Bool, conv.attributes?[key] as? Bool)
                    case "Array":
                        XCTAssertEqual((value as? Array<String>)?.isEmpty, true)
                        XCTAssertEqual((conv.attributes?[key] as? Array<String>)?.isEmpty, true)
                    case "Dictionary":
                        XCTAssertEqual((value as? Dictionary<String, Any>)?.isEmpty, true)
                        XCTAssertEqual((conv.attributes?[key] as? Dictionary<String, Any>)?.isEmpty, true)
                    default:
                        XCTFail()
                    }
                }
            } else {
                XCTAssertNil(attribution)
            }
        }
        
        let exp = expectation(description: "create conversation")
        exp.expectedFulfillmentCount = 5
        delegatorA.conversationEvent = { client, conv, event in
            XCTAssertTrue(Thread.isMainThread)
            if client === clientA {
                convAssertion(conv, client)
                XCTAssertNil(conv.updatedAt)
                switch event {
                case .joined(byClientID: let cID):
                    XCTAssertEqual(cID, clientA.ID)
                    exp.fulfill()
                case .membersJoined(tuple: let tuple):
                    XCTAssertEqual(tuple.byClientID, clientA.ID)
                    XCTAssertEqual(tuple.members, Set<String>([clientA.ID, clientB.ID]))
                    exp.fulfill()
                default:
                    break
                }
            }
        }
        delegatorB.conversationEvent = { client, conv, event in
            XCTAssertTrue(Thread.isMainThread)
            if client === clientB {
                convAssertion(conv, client)
                XCTAssertNotNil(conv.updatedAt)
                switch event {
                case .joined(byClientID: let cID):
                    XCTAssertEqual(cID, clientA.ID)
                    exp.fulfill()
                case .membersJoined(tuple: let tuple):
                    XCTAssertEqual(tuple.byClientID, clientA.ID)
                    XCTAssertEqual(tuple.members, Set<String>([clientA.ID, clientB.ID]))
                    exp.fulfill()
                default:
                    break
                }
            }
        }
        try? clientA.createConversation(clientIDs: [clientA.ID, clientB.ID], name: name, attributes: attribution) { (result) in
            XCTAssertTrue(Thread.isMainThread)
            if let conv: LCConversation = result.value {
                convAssertion(conv, clientA)
                XCTAssertNil(conv.updatedAt)
            } else {
                XCTFail()
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: timeout, handler: nil)
        
        XCTAssertEqual(clientA.convCollection.count, 1)
        XCTAssertEqual(clientB.convCollection.count, 1)
        XCTAssertEqual(
            clientA.convCollection.first?.value.ID,
            clientB.convCollection.first?.value.ID
        )
        XCTAssertTrue(clientA.convQueryCallbackCollection.isEmpty)
        XCTAssertTrue(clientB.convQueryCallbackCollection.isEmpty)
    }
    
    func testCreateNormalAndUniqueConversation() {
        guard
            let clientA = newOpenedClient(customRTMURL: testableRTMURL),
            let clientB = newOpenedClient(customRTMURL: testableRTMURL)
            else
        {
            XCTFail()
            return
        }
        
        let exp1 = expectation(description: "create unique conversation")
        try? clientA.createConversation(clientIDs: [clientA.ID, clientB.ID], isUnique: true, completion: { (result) in
            if let conv: LCConversation = result.value {
                XCTAssertTrue(type(of: conv) == LCConversation.self)
                XCTAssertEqual(conv.type, .normal)
                XCTAssertTrue(conv.isUnique)
                XCTAssertNotNil(conv.uniqueID)
            } else {
                XCTFail()
            }
            exp1.fulfill()
        })
        wait(for: [exp1], timeout: timeout)
        
        let exp2 = expectation(description: "create unique conversation")
        try? clientB.createConversation(clientIDs: [clientA.ID, clientB.ID], isUnique: true, completion: { (result) in
            if let conv: LCConversation = result.value {
                XCTAssertTrue(type(of: conv) == LCConversation.self)
                XCTAssertEqual(conv.type, .normal)
                XCTAssertTrue(conv.isUnique)
                XCTAssertNotNil(conv.uniqueID)
            } else {
                XCTFail()
            }
            exp2.fulfill()
        })
        wait(for: [exp2], timeout: timeout)
        
        XCTAssertEqual(
            clientA.convCollection.first?.value.ID,
            clientB.convCollection.first?.value.ID
        )
        XCTAssertEqual(
            clientA.convCollection.first?.value.uniqueID,
            clientB.convCollection.first?.value.uniqueID
        )
    }
    
    func testCreateChatRoom() {
        guard let client = newOpenedClient() else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "create chat room")
        try? client.createChatRoom() { (result) in
            XCTAssertTrue(Thread.isMainThread)
            let chatRoom: LCChatRoom? = result.value
            XCTAssertEqual(chatRoom?.type, .transient)
            if let members = chatRoom?.members {
                XCTAssertTrue(members.isEmpty)
            } else {
                XCTAssertNil(chatRoom?.members)
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: timeout, handler: nil)
    }
    
    func testCreateTemporaryConversation() {
        guard
            let clientA = newOpenedClient(),
            let clientB = newOpenedClient()
            else
        {
            XCTFail()
            return
        }
        let delegatorA = IMClientTestCase.Delegator()
        clientA.delegate = delegatorA
        let delegatorB = IMClientTestCase.Delegator()
        clientB.delegate = delegatorB
        
        let ttl: Int32 = 3600
        
        let exp = expectation(description: "create conversation")
        exp.expectedFulfillmentCount = 5
        delegatorA.conversationEvent = { client, conv, event in
            XCTAssertTrue(Thread.isMainThread)
            if client === clientA {
                XCTAssertEqual(conv.type, .temporary)
                XCTAssertEqual((conv as? LCTemporaryConversation)?.timeToLive, Int(ttl))
                switch event {
                case .joined(byClientID: let cID):
                    XCTAssertEqual(cID, clientA.ID)
                    exp.fulfill()
                case .membersJoined(tuple: let tuple):
                    XCTAssertEqual(
                        tuple.byClientID,
                        clientA.ID)
                    XCTAssertEqual(
                        tuple.members,
                        Set<String>([clientA.ID, clientB.ID]))
                    exp.fulfill()
                default:
                    break
                }
            }
        }
        delegatorB.conversationEvent = { client, conv, event in
            XCTAssertTrue(Thread.isMainThread)
            if client === clientB {
                XCTAssertEqual(conv.type, .temporary)
                XCTAssertEqual((conv as? LCTemporaryConversation)?.timeToLive, Int(ttl))
                switch event {
                case .joined(byClientID: let cID):
                    XCTAssertEqual(cID, clientA.ID)
                    exp.fulfill()
                case .membersJoined(tuple: let tuple):
                    XCTAssertEqual(
                        tuple.byClientID,
                        clientA.ID)
                    XCTAssertEqual(
                        tuple.members,
                        Set<String>([clientA.ID, clientB.ID]))
                    exp.fulfill()
                default:
                    break
                }
            }
        }
        try? clientA.createTemporaryConversation(clientIDs: [clientA.ID, clientB.ID], timeToLive: ttl, completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            if let conv: LCTemporaryConversation = result.value {
                XCTAssertEqual(conv.type, .temporary)
                XCTAssertEqual(conv.timeToLive, Int(ttl))
            } else {
                XCTFail()
            }
            exp.fulfill()
        })
        waitForExpectations(timeout: timeout, handler: nil)
        
        XCTAssertEqual(
            clientA.convCollection.first?.value.ID,
            clientB.convCollection.first?.value.ID
        )
        XCTAssertEqual(
            clientA.convCollection.first?.value.ID.hasPrefix(LCTemporaryConversation.prefixOfID),
            true
        )
    }
    
    func testNormalConversationUnreadEvent() {
        guard let clientA = newOpenedClient(options: [.receiveUnreadMessageCountAfterSessionDidOpen]) else {
            XCTFail()
            return
        }
        
        let otherClientID: String = uuid
        let message = LCMessage()
        message.content = .string("test")
        message.isAllMembersMentioned = true
        
        let sendExp = expectation(description: "create conversation and send message")
        sendExp.expectedFulfillmentCount = 2
        try? clientA.createConversation(clientIDs: [otherClientID], completion: { (result) in
            XCTAssertNotNil(result.value)
            try? result.value?.send(message: message, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                sendExp.fulfill()
            })
            sendExp.fulfill()
        })
        wait(for: [sendExp], timeout: timeout)
        
        let clientB = try! LCClient(ID: otherClientID, options: [.receiveUnreadMessageCountAfterSessionDidOpen])
        let delegator = IMClientTestCase.Delegator()
        clientB.delegate = delegator
        
        let unreadExp = expectation(description: "opened and get unread event")
        unreadExp.expectedFulfillmentCount = 3
        delegator.conversationEvent = { client, conversation, event in
            if client === clientB, conversation.ID == message.conversationID {
                switch event {
                case .lastMessageUpdated:
                    XCTAssertEqual(conversation.lastMessage?.conversationID, message.conversationID)
                    XCTAssertEqual(conversation.lastMessage?.sentTimestamp, message.sentTimestamp)
                    XCTAssertEqual(conversation.lastMessage?.ID, message.ID)
                    unreadExp.fulfill()
                case .unreadMessageUpdated:
                    XCTAssertEqual(conversation.unreadMessageCount, 1)
                    XCTAssertTrue(conversation.isUnreadMessageContainMention)
                    unreadExp.fulfill()
                default:
                    break
                }
            }
        }
        clientB.open { (result) in
            XCTAssertTrue(result.isSuccess)
            unreadExp.fulfill()
        }
        wait(for: [unreadExp], timeout: timeout)
        
        let readExp = expectation(description: "read")
        delegator.conversationEvent = { client, conversation, event in
            if client === clientB, conversation.ID == message.conversationID {
                if case .unreadMessageUpdated = event {
                    XCTAssertEqual(conversation.unreadMessageCount, 0)
                    readExp.fulfill()
                }
            }
        }
        for (_, conv) in clientB.convCollection {
            conv.read()
        }
        wait(for: [readExp], timeout: timeout)
    }
    
    func testTemporaryConversationUnreadEvent() {
        guard let clientA = newOpenedClient(options: [.receiveUnreadMessageCountAfterSessionDidOpen]) else {
            XCTFail()
            return
        }
        
        let otherClientID: String = uuid
        let message = LCMessage()
        message.content = .string("test")
        message.isAllMembersMentioned = true
        
        let sendExp = expectation(description: "create temporary conversation and send message")
        sendExp.expectedFulfillmentCount = 2
        try? clientA.createTemporaryConversation(clientIDs: [otherClientID], timeToLive: 3600, completion: { (result) in
            XCTAssertNotNil(result.value)
            try? result.value?.send(message: message, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                sendExp.fulfill()
            })
            sendExp.fulfill()
        })
        wait(for: [sendExp], timeout: timeout)
        
        let clientB = try! LCClient(ID: otherClientID, options: [.receiveUnreadMessageCountAfterSessionDidOpen])
        let delegator = IMClientTestCase.Delegator()
        clientB.delegate = delegator
        
        let unreadExp = expectation(description: "opened and get unread event")
        unreadExp.expectedFulfillmentCount = 3
        delegator.conversationEvent = { client, conversation, event in
            if client === clientB, conversation.ID == message.conversationID {
                switch event {
                case .lastMessageUpdated:
                    XCTAssertEqual(conversation.lastMessage?.conversationID, message.conversationID)
                    XCTAssertEqual(conversation.lastMessage?.sentTimestamp, message.sentTimestamp)
                    XCTAssertEqual(conversation.lastMessage?.ID, message.ID)
                    unreadExp.fulfill()
                case .unreadMessageUpdated:
                    XCTAssertEqual(conversation.unreadMessageCount, 1)
                    XCTAssertTrue(conversation.isUnreadMessageContainMention)
                    unreadExp.fulfill()
                default:
                    break
                }
            }
        }
        clientB.open { (result) in
            XCTAssertTrue(result.isSuccess)
            unreadExp.fulfill()
        }
        wait(for: [unreadExp], timeout: timeout)
        
        let readExp = expectation(description: "read")
        delegator.conversationEvent = { client, conversation, event in
            if client === clientB, conversation.ID == message.conversationID {
                if case .unreadMessageUpdated = event {
                    XCTAssertEqual(conversation.unreadMessageCount, 0)
                    readExp.fulfill()
                }
            }
        }
        for (_, conv) in clientB.convCollection {
            conv.read()
        }
        wait(for: [readExp], timeout: timeout)
    }
    
    func testServiceConversationUnreadEvent() {
        
        let clientID = uuid
        
        guard let serviceConvID: String = newServiceConversation(),
            subscribing(serviceConversation: serviceConvID, by: clientID),
            let _ = broadcastingMessage(to: serviceConvID)
            else
        {
            XCTFail()
            return
        }
        
        delay()
        
        let clientA = try! LCClient(ID: clientID, options: [.receiveUnreadMessageCountAfterSessionDidOpen])
        let delegator = IMClientTestCase.Delegator()
        clientA.delegate = delegator
        
        let unreadExp = expectation(description: "opened and get unread event")
        unreadExp.expectedFulfillmentCount = 3
        delegator.conversationEvent = { client, conversation, event in
            if client === clientA, conversation.ID == serviceConvID {
                switch event {
                case .lastMessageUpdated:
                    unreadExp.fulfill()
                case .unreadMessageUpdated:
                    unreadExp.fulfill()
                default:
                    break
                }
            }
        }
        clientA.open { (result) in
            XCTAssertTrue(result.isSuccess)
            unreadExp.fulfill()
        }
        wait(for: [unreadExp], timeout: timeout)
        
        let readExp = expectation(description: "read")
        delegator.conversationEvent = { client, conversation, event in
            if client === clientA, conversation.ID == serviceConvID {
                if case .unreadMessageUpdated = event {
                    XCTAssertEqual(conversation.unreadMessageCount, 0)
                    readExp.fulfill()
                }
            }
        }
        for (_, conv) in clientA.convCollection {
            conv.read()
        }
        wait(for: [readExp], timeout: timeout)
    }
    
    func testLargeUnreadEvent() {
        guard let clientA = newOpenedClient(options: [.receiveUnreadMessageCountAfterSessionDidOpen]) else {
            XCTFail()
            return
        }
        
        let otherClientID: String = uuid
        let count: Int = 20
        
        for i in 0..<count {
            let exp = expectation(description: "create conversation and send message")
            exp.expectedFulfillmentCount = 2
            let message = LCMessage()
            message.content = .string("")
            if i == 0 {
                try! clientA.createTemporaryConversation(clientIDs: [otherClientID], timeToLive: 3600, completion: { (result) in
                    XCTAssertNotNil(result.value)
                    try! result.value?.send(message: message, completion: { (result) in
                        XCTAssertTrue(result.isSuccess)
                        exp.fulfill()
                    })
                    exp.fulfill()
                })
                wait(for: [exp], timeout: timeout)
            } else {
                try! clientA.createConversation(clientIDs: [otherClientID]) { (result) in
                    XCTAssertNotNil(result.value)
                    try! result.value?.send(message: message, completion: { (result) in
                        XCTAssertTrue(result.isSuccess)
                        exp.fulfill()
                    })
                    exp.fulfill()
                }
                wait(for: [exp], timeout: timeout)
            }
        }
        
        let convIDSet = Set<String>(clientA.convCollection.keys)
        let clientB = try! LCClient(ID: otherClientID, options: [.receiveUnreadMessageCountAfterSessionDidOpen])
        let delegator = IMClientTestCase.Delegator()
        clientB.delegate = delegator
        
        let largeUnreadExp = expectation(description: "opened and get large unread event")
        largeUnreadExp.expectedFulfillmentCount = (count * 2) + 1
        delegator.conversationEvent = { client, conversaton, event in
            if client === clientB, convIDSet.contains(conversaton.ID) {
                switch event {
                case .lastMessageUpdated, .unreadMessageUpdated:
                    largeUnreadExp.fulfill()
                default:
                    break
                }
            }
        }
        clientB.open { (result) in
            XCTAssertTrue(result.isSuccess)
            largeUnreadExp.fulfill()
        }
        wait(for: [largeUnreadExp], timeout: timeout)
        
        XCTAssertNotNil(clientB.lastUnreadNotifTime)
        
        let allReadExp = expectation(description: "all read")
        allReadExp.expectedFulfillmentCount = count
        delegator.conversationEvent = { client, conversation, event in
            if client === clientB, convIDSet.contains(conversation.ID) {
                if case .unreadMessageUpdated = event {
                    allReadExp.fulfill()
                }
            }
        }
        for (_, conv) in clientB.convCollection {
            conv.read()
        }
        wait(for: [allReadExp], timeout: timeout)
    }
    
}

extension IMConversationTestCase {
    
    func newOpenedClient(
        clientID: String? = nil,
        options: LCClient.Options = .default,
        customRTMURL: URL? = nil)
        -> LCClient?
    {
        var client: LCClient? = try? LCClient(ID: clientID ?? uuid, options:options, customServer: customRTMURL)
        let exp = expectation(description: "open")
        client?.open { (result) in
            if result.isFailure { client = nil }
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
        return client
    }
    
    func newServiceConversation() -> String? {
        var objectID: String?
        let exp = expectation(description: "create service conversation")
        let parameters: Parameters = [
            "name": uuid
        ]
        let headers: HTTPHeaders = [
            "X-LC-Id": LCApplication.default.id,
            "X-LC-Key": LCApplication.default.key,
            "Content-Type": "application/json"
        ]
        let request: URLRequest = Alamofire.request(
            v2Router.route(path: "/rtm/service-conversations", module: .api)!,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
            ).request!
        print("------\n\(request.url!)\n\(parameters)\n------\n")
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            XCTAssertTrue((200..<300).contains(statusCode))
            if let data = data,
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let json: [String: Any] = object {
                print("------\n\(json)\n------\n")
                objectID = json["objectId"] as? String
            }
            exp.fulfill()
        }
        task.resume()
        wait(for: [exp], timeout: timeout)
        return objectID
    }
    
    func subscribing(serviceConversation conversationID: String, by clientID: String) -> Bool {
        var success: Bool = false
        let exp = expectation(description: "subscribe a service conversation")
        let parameters: Parameters = [
            "client_id": clientID
        ]
        let headers: HTTPHeaders = [
            "X-LC-Id": LCApplication.default.id,
            "X-LC-Key": masterKey,
            "Content-Type": "application/json"
        ]
        let request: URLRequest = Alamofire.request(
            v2Router.route(path: "/rtm/service-conversations/\(conversationID)/subscribers")!,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
            ).request!
        print("------\n\(request.url!)\n\(parameters)\n------\n")
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(statusCode) {
                success = true
            } else {
                XCTFail()
            }
            if let data = data,
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let json: [String: Any] = object {
                print("------\n\(json)\n------\n")
            }
            exp.fulfill()
        }
        task.resume()
        wait(for: [exp], timeout: timeout)
        return success
    }
    
    func broadcastingMessage(to conversationID: String) -> (String, Int64)? {
        var tuple: (String, Int64)?
        let exp = expectation(description: "service conversation broadcasting message")
        let parameters: Parameters = [
            "from_client": "master",
            "message": "test"
        ]
        let headers: HTTPHeaders = [
            "X-LC-Id": LCApplication.default.id,
            "X-LC-Key": masterKey,
            "Content-Type": "application/json"
        ]
        let request: URLRequest = Alamofire.request(
            v2Router.route(path: "/rtm/service-conversations/\(conversationID)/broadcasts", module: .api)!,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
            ).request!
        print("------\n\(request.url!)\n\(parameters)\n------\n")
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            XCTAssertTrue((200..<300).contains(statusCode))
            if let data = data,
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let json: [String: Any] = object {
                print("------\n\(json)\n------\n")
                if let result: [String: Any] = json["result"] as? [String: Any],
                    let messageID = result["msg-id"] as? String,
                    let timestamp: Int64 = result["timestamp"] as? Int64 {
                    tuple = (messageID, timestamp)
                }
            }
            exp.fulfill()
        }
        task.resume()
        wait(for: [exp], timeout: timeout)
        return tuple
    }
    
}
