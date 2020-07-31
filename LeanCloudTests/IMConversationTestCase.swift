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

    func testCreateConversationThenErrorThrows() {
        
        let client: IMClient = try! IMClient(ID: uuid, options: [])
        
        let errExp = expectation(description: "not open")
        try? client.createConversation(clientIDs: [], isUnique: false) { (r) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertFalse(r.isSuccess)
            XCTAssertNotNil(r.error)
            errExp.fulfill()
        }
        wait(for: [errExp], timeout: timeout)
        
        do {
            let invalidID: String = Array<String>.init(repeating: "a", count: 65).joined()
            try client.createConversation(clientIDs: [invalidID], isUnique: false, completion: { (_) in })
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
        
        let convAssertion: (IMConversation, IMClient) -> Void = { conv, client in
            XCTAssertTrue(type(of: conv) == IMConversation.self)
            XCTAssertEqual(conv.rawData["objectId"] as? String, conv.ID)
            XCTAssertEqual(conv.rawData["conv_type"] as? Int, 1)
            XCTAssertEqual(conv.convType, .normal)
            XCTAssertEqual(conv.members?.count, 2)
            XCTAssertEqual(conv.members?.contains(clientA.ID), true)
            XCTAssertEqual(conv.members?.contains(clientB.ID), true)
            XCTAssertNotNil(conv.client)
            if let c: IMClient = conv.client {
                XCTAssertTrue(c === client)
            }
            XCTAssertEqual(conv.clientID, client.ID)
            XCTAssertFalse(conv.isUnique)
            XCTAssertNil(conv.uniqueID)
            XCTAssertEqual(conv.creator, clientA.ID)
            XCTAssertNotNil(conv.updatedAt ?? conv.createdAt)
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
                switch event {
                case .joined(byClientID: let cID, at: _):
                    XCTAssertEqual(cID, clientA.ID)
                    exp.fulfill()
                case .membersJoined(members: let members, byClientID: let byClientID, at: _):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(Set(members), Set([clientA.ID, clientB.ID]))
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
                case .joined(byClientID: let cID, at: _):
                    XCTAssertEqual(cID, clientA.ID)
                    exp.fulfill()
                case .membersJoined(members: let members, byClientID: let byClientID, at: _):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(Set(members), Set([clientA.ID, clientB.ID]))
                    exp.fulfill()
                default:
                    break
                }
            }
        }
        try? clientA.createConversation(clientIDs: [clientA.ID, clientB.ID], name: name, attributes: attribution, isUnique: false) { (result) in
            XCTAssertTrue(Thread.isMainThread)
            if let conv: IMConversation = result.value {
                convAssertion(conv, clientA)
            } else {
                XCTFail()
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
        
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
        
        let exp1 = expectation(description: "create unique conversation")
        exp1.expectedFulfillmentCount = 5
        delegatorA.conversationEvent = { _, _, event in
            switch event {
            case .joined:
                exp1.fulfill()
            case .membersJoined:
                exp1.fulfill()
            default:
                break
            }
        }
        delegatorB.conversationEvent = { _, _, event in
            switch event {
            case .joined:
                exp1.fulfill()
            case .membersJoined:
                exp1.fulfill()
            default:
                break
            }
        }
        try? clientA.createConversation(clientIDs: [clientA.ID, clientB.ID], completion: { (result) in
            if let conv: IMConversation = result.value {
                XCTAssertTrue(type(of: conv) == IMConversation.self)
                XCTAssertEqual(conv.rawData["objectId"] as? String, conv.ID)
                XCTAssertEqual(conv.rawData["conv_type"] as? Int, 1)
                XCTAssertEqual(conv.convType, .normal)
                XCTAssertTrue(conv.isUnique)
                XCTAssertNotNil(conv.uniqueID)
            } else {
                XCTFail()
            }
            exp1.fulfill()
        })
        wait(for: [exp1], timeout: timeout)
        
        delegatorA.conversationEvent = nil
        delegatorB.conversationEvent = nil
        
        let exp2 = expectation(description: "create unique conversation")
        exp2.expectedFulfillmentCount = 5
        delegatorA.conversationEvent = { _, _, event in
            switch event {
            case .joined:
                exp2.fulfill()
            case .membersJoined:
                exp2.fulfill()
            default:
                break
            }
        }
        delegatorB.conversationEvent = { _, _, event in
            switch event {
            case .joined:
                exp2.fulfill()
            case .membersJoined:
                exp2.fulfill()
            default:
                break
            }
        }
        try? clientB.createConversation(clientIDs: [clientA.ID, clientB.ID], completion: { (result) in
            if let conv: IMConversation = result.value {
                XCTAssertTrue(type(of: conv) == IMConversation.self)
                XCTAssertEqual(conv.convType, .normal)
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
        
        expecting { (exp) in
            clientA.convCollection.first?.value.checkJoined(completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value, true)
                exp.fulfill()
            })
        }
    }
    
    func testCreateChatRoom() {
        guard let client = newOpenedClient() else {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "create chat room")
        try? client.createChatRoom() { (result) in
            XCTAssertTrue(Thread.isMainThread)
            let chatRoom: IMChatRoom? = result.value
            XCTAssertEqual(chatRoom?.convType, .transient)
            XCTAssertEqual(chatRoom?.rawData["objectId"] as? String, chatRoom?.ID)
            XCTAssertEqual(chatRoom?.rawData["conv_type"] as? Int, 2)
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
                XCTAssertEqual(conv.convType, .temporary)
                XCTAssertEqual((conv as? IMTemporaryConversation)?.timeToLive, Int(ttl))
                switch event {
                case .joined(byClientID: let cID, at: _):
                    XCTAssertEqual(cID, clientA.ID)
                    exp.fulfill()
                case .membersJoined(members: let members, byClientID: let byClientID, at: _):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(Set(members), Set([clientA.ID, clientB.ID]))
                    exp.fulfill()
                default:
                    break
                }
            }
        }
        delegatorB.conversationEvent = { client, conv, event in
            XCTAssertTrue(Thread.isMainThread)
            if client === clientB {
                XCTAssertEqual(conv.convType, .temporary)
                XCTAssertEqual((conv as? IMTemporaryConversation)?.timeToLive, Int(ttl))
                switch event {
                case .joined(byClientID: let cID, at: _):
                    XCTAssertEqual(cID, clientA.ID)
                    exp.fulfill()
                case .membersJoined(members: let members, byClientID: let byClientID, at: _):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(Set(members), Set([clientA.ID, clientB.ID]))
                    exp.fulfill()
                default:
                    break
                }
            }
        }
        try? clientA.createTemporaryConversation(clientIDs: [clientA.ID, clientB.ID], timeToLive: ttl, completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            if let conv: IMTemporaryConversation = result.value {
                XCTAssertEqual(conv.convType, .temporary)
                XCTAssertEqual(conv.rawData["objectId"] as? String, conv.ID)
                XCTAssertEqual(conv.rawData["conv_type"] as? Int, 4)
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
            clientA.convCollection.first?.value.ID.hasPrefix(IMTemporaryConversation.prefixOfID),
            true
        )
    }
    
    func testServiceConversationSubscription() {
        guard let client = newOpenedClient(),
              let serviceConversationID = IMConversationTestCase.newServiceConversation() else {
            XCTFail()
            return
        }
        delay()
        var serviceConversation: IMServiceConversation?
        expecting { (exp) in
            try! client.conversationQuery.getConversation(by: serviceConversationID) { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                serviceConversation = (result.value as? IMServiceConversation)
                XCTAssertEqual(serviceConversation?.rawData["objectId"] as? String, serviceConversation?.ID)
                XCTAssertEqual(serviceConversation?.rawData["conv_type"] as? Int, 3)
                XCTAssertEqual(serviceConversation?.isSubscribed, false)
                exp.fulfill()
            }
        }
        guard let _ = serviceConversation else {
            XCTFail()
            return
        }
        expecting(
            description: "service conversation subscription",
            count: 3)
        { (exp) in
            serviceConversation?.checkSubscription(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value, false)
                exp.fulfill()
                try! serviceConversation?.subscribe(completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    XCTAssertEqual(serviceConversation?.isSubscribed, true)
                    exp.fulfill()
                    serviceConversation?.checkSubscription(completion: { (result) in
                        XCTAssertTrue(result.isSuccess)
                        XCTAssertNil(result.error)
                        XCTAssertEqual(result.value, true)
                        exp.fulfill()
                    })
                })
            })
        }
        let query = client.conversationQuery
        expecting { (exp) in
            try! query.getConversation(by: serviceConversationID) { (result) in
                XCTAssertNil(result.error)
                if let conv = result.value as? IMServiceConversation {
                    XCTAssertEqual(conv.isMuted, false)
                    XCTAssertTrue(conv.rawData["muted"] != nil)
                    XCTAssertNotNil(conv.subscribedTimestamp)
                    XCTAssertNotNil(conv.subscribedAt)
                } else {
                    XCTFail()
                }
                exp.fulfill()
            }
        }
    }
    
    func testNormalConversationUnreadEvent() {
        guard let clientA = newOpenedClient() else {
            XCTFail()
            return
        }
        
        let clientBID = uuid
        
        var conversation1: IMConversation!
        var conversation2: IMConversation!
        
        let message1 = IMMessage()
        try! message1.set(content: .string(uuid))
        message1.isAllMembersMentioned = true
        let message2 = IMMessage()
        try! message2.set(content: .string(uuid))
        
        expecting(
            description: "create conversation, then send message",
            count: 4)
        { (exp) in
            try! clientA.createConversation(
                clientIDs: [clientBID],
                isUnique: false)
            { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                conversation1 = result.value
                exp.fulfill()
                try! conversation1.send(message: message1) { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    exp.fulfill()
                    try! clientA.createConversation(
                        clientIDs: [clientBID],
                        isUnique: false)
                    { (result) in
                        XCTAssertTrue(result.isSuccess)
                        XCTAssertNil(result.error)
                        conversation2 = result.value
                        exp.fulfill()
                        try! conversation2.send(message: message2) { (result) in
                            XCTAssertTrue(result.isSuccess)
                            XCTAssertNil(result.error)
                            exp.fulfill()
                        }
                    }
                }
            }
        }
        
        delay()
        
        guard let _ = conversation1,
            let _ = conversation2 else {
                XCTFail()
                return
        }
        
        RTMConnectionManager.default
            .imProtobuf1Registry.removeAll()
        RTMConnectionManager.default
            .imProtobuf3Registry.removeAll()
        
        let clientB = try! IMClient(
            ID: clientBID,
            options: [.receiveUnreadMessageCountAfterSessionDidOpen])
        let delegatorB = IMClientTestCase.Delegator()
        clientB.delegate = delegatorB
        
        expecting(
            description: "open, then receive unread event",
            count: 5)
        { (exp) in
            delegatorB.conversationEvent = { client, conversation, event in
                if conversation.ID == conversation1.ID {
                    switch event {
                    case .lastMessageUpdated:
                        let lastMessage = conversation.lastMessage
                        XCTAssertEqual(lastMessage?.conversationID, message1.conversationID)
                        XCTAssertEqual(lastMessage?.sentTimestamp, message1.sentTimestamp)
                        XCTAssertEqual(lastMessage?.ID, message1.ID)
                        exp.fulfill()
                    case .unreadMessageCountUpdated:
                        XCTAssertEqual(conversation.unreadMessageCount, 1)
                        XCTAssertTrue(conversation.isUnreadMessageContainMention)
                        exp.fulfill()
                    default:
                        break
                    }
                } else if conversation.ID == conversation2.ID {
                    switch event {
                    case .lastMessageUpdated:
                        let lastMessage = conversation.lastMessage
                        XCTAssertEqual(lastMessage?.conversationID, message2.conversationID)
                        XCTAssertEqual(lastMessage?.sentTimestamp, message2.sentTimestamp)
                        XCTAssertEqual(lastMessage?.ID, message2.ID)
                        exp.fulfill()
                    case .unreadMessageCountUpdated:
                        XCTAssertEqual(conversation.unreadMessageCount, 1)
                        XCTAssertFalse(conversation.isUnreadMessageContainMention)
                        exp.fulfill()
                    default:
                        break
                    }
                }
            }
            clientB.open { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            }
        }
        
        expecting { (exp) in
            delegatorB.clientEvent = { client, event in
                switch event {
                case .sessionDidPause:
                    exp.fulfill()
                default:
                    break
                }
            }
            clientB.connection.disconnect()
        }
        
        delay()
        XCTAssertNotNil(clientB.lastUnreadNotifTime)
        
        let message3 = IMMessage()
        try! message3.set(content: .string(uuid))
        
        expecting { (exp) in
            try! conversation1.send(message: message3) { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            }
        }
        
        expecting(
            description: "reconnect, then receive unread event",
            count: 3)
        { (exp) in
            delegatorB.clientEvent = { client, event in
                switch event {
                case .sessionDidOpen:
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conversation, event in
                if conversation.ID == conversation1.ID {
                    switch event {
                    case .lastMessageUpdated:
                        let lastMessage = conversation.lastMessage
                        XCTAssertEqual(lastMessage?.conversationID, message3.conversationID)
                        XCTAssertEqual(lastMessage?.sentTimestamp, message3.sentTimestamp)
                        XCTAssertEqual(lastMessage?.ID, message3.ID)
                        exp.fulfill()
                    case .unreadMessageCountUpdated:
                        XCTAssertEqual(conversation.unreadMessageCount, 2)
                        XCTAssertTrue(conversation.isUnreadMessageContainMention)
                        exp.fulfill()
                    default:
                        break
                    }
                }
            }
            clientB.connection.connect()
        }
        
        expecting(
            description: "read",
            count: 2)
        { (exp) in
            delegatorB.conversationEvent = { client, conversation, event in
                if conversation.ID == conversation1.ID {
                    switch event {
                    case .unreadMessageCountUpdated:
                        XCTAssertEqual(conversation.unreadMessageCount, 0)
                        exp.fulfill()
                    default:
                        break
                    }
                } else if conversation.ID == conversation2.ID {
                    switch event {
                    case .unreadMessageCountUpdated:
                        XCTAssertEqual(conversation.unreadMessageCount, 0)
                        exp.fulfill()
                    default:
                        break
                    }
                }
            }
            for (_, conv) in clientB.convCollection {
                conv.read()
            }
        }
    }
    
    func testTemporaryConversationUnreadEvent() {
        guard let clientA = newOpenedClient() else {
            XCTFail()
            return
        }
        
        let otherClientID: String = uuid
        let message = IMMessage()
        try? message.set(content: .string("test"))
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
        
        let clientB = try! IMClient(ID: otherClientID, options: [.receiveUnreadMessageCountAfterSessionDidOpen])
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
                case .unreadMessageCountUpdated:
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
                if case .unreadMessageCountUpdated = event {
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
        
        guard let serviceConvID: String = IMConversationTestCase.newServiceConversation(),
            IMConversationTestCase.subscribing(serviceConversation: serviceConvID, by: clientID),
            let _ = IMConversationTestCase.broadcastingMessage(to: serviceConvID)
            else
        {
            XCTFail()
            return
        }
        
        delay(seconds: 15)
        
        let clientA = try! IMClient(ID: clientID, options: [.receiveUnreadMessageCountAfterSessionDidOpen])
        let delegator = IMClientTestCase.Delegator()
        clientA.delegate = delegator
        
        let unreadExp = expectation(description: "opened and get unread event")
        unreadExp.expectedFulfillmentCount = 3
        delegator.conversationEvent = { client, conversation, event in
            if client === clientA, conversation.ID == serviceConvID {
                switch event {
                case .lastMessageUpdated:
                    unreadExp.fulfill()
                case .unreadMessageCountUpdated:
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
                if case .unreadMessageCountUpdated = event {
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
        guard let clientA = newOpenedClient() else {
            XCTFail()
            return
        }
        
        let otherClientID: String = uuid
        let count: Int = 20
        
        for i in 0..<count {
            let exp = expectation(description: "create conversation and send message")
            exp.expectedFulfillmentCount = 2
            let message = IMMessage()
            try? message.set(content: .string("test"))
            if i % 2 == 0 {
                try! clientA.createTemporaryConversation(clientIDs: [otherClientID, uuid], timeToLive: 3600, completion: { (result) in
                    XCTAssertNotNil(result.value)
                    try! result.value?.send(message: message, completion: { (result) in
                        XCTAssertTrue(result.isSuccess)
                        exp.fulfill()
                    })
                    exp.fulfill()
                })
                wait(for: [exp], timeout: timeout)
            } else {
                try! clientA.createConversation(clientIDs: [otherClientID], isUnique: false) { (result) in
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
        let clientB = try! IMClient(ID: otherClientID, options: [.receiveUnreadMessageCountAfterSessionDidOpen])
        let delegator = IMClientTestCase.Delegator()
        clientB.delegate = delegator
        
        let largeUnreadExp = expectation(description: "opened and get large unread event")
        largeUnreadExp.expectedFulfillmentCount = (count * 2) + 1
        delegator.conversationEvent = { client, conversaton, event in
            if client === clientB, convIDSet.contains(conversaton.ID) {
                switch event {
                case .lastMessageUpdated, .unreadMessageCountUpdated:
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
        
        delay()
        XCTAssertNotNil(clientB.lastUnreadNotifTime)
        
        let allReadExp = expectation(description: "all read")
        allReadExp.expectedFulfillmentCount = count
        delegator.conversationEvent = { client, conversation, event in
            if client === clientB, convIDSet.contains(conversation.ID) {
                if case .unreadMessageCountUpdated = event {
                    allReadExp.fulfill()
                }
            }
        }
        for (_, conv) in clientB.convCollection {
            conv.read()
        }
        wait(for: [allReadExp], timeout: timeout)
    }
    
    func testMembersChange() {
        guard let clientA = newOpenedClient(),
            let clientB = newOpenedClient() else {
                XCTFail()
                return
        }
        
        let delegatorA = IMClientTestCase.Delegator()
        clientA.delegate = delegatorA
        let delegatorB = IMClientTestCase.Delegator()
        clientB.delegate = delegatorB
        
        var convA: IMConversation?
        
        expecting(
            description: "create conversation",
            count: 5)
        { (exp) in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .joined(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                case let .membersJoined(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientA.ID))
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .joined(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                case let .membersJoined(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientA.ID))
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            try! clientA.createConversation(clientIDs: [clientB.ID]) { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                convA = result.value
                exp.fulfill()
            }
        }
        
        let convB = clientB.convCollection[convA?.ID ?? ""]
        XCTAssertNotNil(convB)
        
        expecting(
            description: "leave",
            count: 3)
        { (exp) in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersLeft(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientB.ID)
                    XCTAssertEqual(members.count, 1)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertEqual(conv.members?.count, 1)
                    XCTAssertEqual(conv.members?.first, clientA.ID)
                    XCTAssertNotNil(at)
                    XCTAssertEqual(at, conv.updatedAt)
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .left(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientB.ID)
                    XCTAssertEqual(conv.members?.count, 1)
                    XCTAssertEqual(conv.members?.first, clientA.ID)
                    XCTAssertNotNil(at)
                    XCTAssertEqual(at, conv.updatedAt)
                    exp.fulfill()
                default:
                    break
                }
            }
            try! convB?.leave(completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting(
            description: "join",
            count: 4)
        { (exp) in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersJoined(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientB.ID)
                    XCTAssertEqual(members.count, 1)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertEqual(conv.members?.count, 2)
                    XCTAssertEqual(conv.members?.contains(clientA.ID), true)
                    XCTAssertEqual(conv.members?.contains(clientB.ID), true)
                    XCTAssertNotNil(at)
                    XCTAssertEqual(at, conv.updatedAt)
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .joined(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientB.ID)
                    XCTAssertEqual(conv.members?.count, 2)
                    XCTAssertEqual(conv.members?.contains(clientA.ID), true)
                    XCTAssertEqual(conv.members?.contains(clientB.ID), true)
                    XCTAssertNotNil(at)
                    XCTAssertEqual(at, conv.updatedAt)
                    exp.fulfill()
                case let .membersJoined(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientB.ID)
                    XCTAssertEqual(members.count, 1)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertEqual(conv.members?.count, 2)
                    XCTAssertEqual(conv.members?.contains(clientA.ID), true)
                    XCTAssertEqual(conv.members?.contains(clientB.ID), true)
                    XCTAssertNotNil(at)
                    XCTAssertEqual(at, conv.updatedAt)
                    exp.fulfill()
                default:
                    break
                }
            }
            try! convB?.join(completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting(
            description: "remove",
            count: 3)
        { (exp) in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersLeft(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(members.count, 1)
                    XCTAssertEqual(members.first, clientB.ID)
                    XCTAssertEqual(conv.members?.count, 1)
                    XCTAssertEqual(conv.members?.first, clientA.ID)
                    XCTAssertNotNil(at)
                    XCTAssertEqual(at, conv.updatedAt)
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .left(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(conv.members?.count, 1)
                    XCTAssertEqual(conv.members?.first, clientA.ID)
                    XCTAssertNotNil(at)
                    XCTAssertEqual(at, conv.updatedAt)
                    exp.fulfill()
                default:
                    break
                }
            }
            try! convA?.remove(members: [clientB.ID], completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting(
            description: "add",
            count: 4)
        { (exp) in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersJoined(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(members.count, 1)
                    XCTAssertEqual(members.first, clientB.ID)
                    XCTAssertEqual(conv.members?.count, 2)
                    XCTAssertEqual(conv.members?.contains(clientA.ID), true)
                    XCTAssertEqual(conv.members?.contains(clientB.ID), true)
                    XCTAssertNotNil(at)
                    XCTAssertEqual(at, conv.updatedAt)
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .joined(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(conv.members?.count, 2)
                    XCTAssertEqual(conv.members?.contains(clientA.ID), true)
                    XCTAssertEqual(conv.members?.contains(clientB.ID), true)
                    XCTAssertNotNil(at)
                    XCTAssertEqual(at, conv.updatedAt)
                    exp.fulfill()
                case let .membersJoined(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertEqual(members.count, 1)
                    XCTAssertEqual(members.first, clientB.ID)
                    XCTAssertEqual(conv.members?.count, 2)
                    XCTAssertEqual(conv.members?.contains(clientA.ID), true)
                    XCTAssertEqual(conv.members?.contains(clientB.ID), true)
                    XCTAssertNotNil(at)
                    XCTAssertEqual(at, conv.updatedAt)
                    exp.fulfill()
                default:
                    break
                }
            }
            try! convA?.add(members: [clientB.ID], completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            convA?.countMembers(completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.intValue, 2);
                exp.fulfill()
            })
        }
    }
    
    func testGetChatRoomOnlineMembers() {
        guard let clientA = newOpenedClient(),
            let clientB = newOpenedClient() else {
                XCTFail()
                return
        }
        
        var chatRoomA: IMChatRoom?
        
        expecting { (exp) in
            try! clientA.createChatRoom(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                chatRoomA = result.value
                exp.fulfill()
            })
        }
        
        var chatRoomB: IMChatRoom?
        
        expecting { (exp) in
            if let ID = chatRoomA?.ID {
                try? clientB.conversationQuery.getConversation(by: ID, completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    chatRoomB = result.value as? IMChatRoom
                    exp.fulfill()
                })
            } else {
                XCTFail()
                exp.fulfill()
            }
        }
        
        expecting(
            description: "get online count",
            count: 7)
        { (exp) in
            chatRoomA?.getOnlineMembersCount(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.intValue, 1)
                exp.fulfill()
                try? chatRoomB?.join(completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    exp.fulfill()
                    chatRoomA?.getOnlineMembersCount(completion: { (result) in
                        XCTAssertTrue(result.isSuccess)
                        XCTAssertNil(result.error)
                        XCTAssertEqual(result.intValue, 2)
                        exp.fulfill()
                        chatRoomA?.getOnlineMembers(completion: { (result) in
                            XCTAssertTrue(result.isSuccess)
                            XCTAssertNil(result.error)
                            XCTAssertEqual(result.value?.count, 2)
                            XCTAssertEqual(result.value?.contains(clientA.ID), true)
                            XCTAssertEqual(result.value?.contains(clientB.ID), true)
                            exp.fulfill()
                            try? chatRoomB?.leave(completion: { (result) in
                                XCTAssertTrue(result.isSuccess)
                                XCTAssertNil(result.error)
                                exp.fulfill()
                                chatRoomA?.getOnlineMembersCount(completion: { (result) in
                                    XCTAssertTrue(Thread.isMainThread)
                                    XCTAssertTrue(result.isSuccess)
                                    XCTAssertNil(result.error)
                                    XCTAssertEqual(result.intValue, 1)
                                    exp.fulfill()
                                    chatRoomA?.countMembers(completion: { (result) in
                                        XCTAssertTrue(Thread.isMainThread)
                                        XCTAssertTrue(result.isSuccess)
                                        XCTAssertNil(result.error)
                                        XCTAssertEqual(result.intValue, 1)
                                        exp.fulfill()
                                    })
                                })
                            })
                        })
                    })
                })
            })
        }
    }
    
    func testMuteAndUnmute() {
        guard let client = newOpenedClient() else {
            XCTFail()
            return
        }
        
        var conversation: IMConversation? = nil
        var previousUpdatedAt: Date?
        
        let createExp = expectation(description: "create conversation")
        try? client.createConversation(clientIDs: [uuid, uuid], isUnique: false) { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            conversation = result.value
            previousUpdatedAt = conversation?.updatedAt ?? conversation?.createdAt
            createExp.fulfill()
        }
        wait(for: [createExp], timeout: timeout)
        
        delay()
        
        let muteExp = expectation(description: "mute")
        conversation?.mute(completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(conversation?.isMuted, true)
            let mutedMembers = conversation?[IMConversation.Key.mutedMembers.rawValue] as? [String]
            XCTAssertEqual(mutedMembers?.count, 1)
            XCTAssertEqual(mutedMembers?.contains(client.ID), true)
            if let updatedAt = conversation?.updatedAt, let preUpdatedAt = previousUpdatedAt {
                XCTAssertGreaterThan(updatedAt, preUpdatedAt)
                previousUpdatedAt = updatedAt
            } else {
                XCTFail()
            }
            muteExp.fulfill()
        })
        wait(for: [muteExp], timeout: timeout)
        
        delay()
        
        let unmuteExp = expectation(description: "unmute")
        conversation?.unmute(completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(conversation?.isMuted, false)
            let mutedMembers = conversation?[IMConversation.Key.mutedMembers.rawValue] as? [String]
            XCTAssertEqual(mutedMembers?.count, 0)
            if let updatedAt = conversation?.updatedAt, let preUpdatedAt = previousUpdatedAt {
                XCTAssertGreaterThan(updatedAt, preUpdatedAt)
                previousUpdatedAt = updatedAt
            } else {
                XCTFail()
            }
            unmuteExp.fulfill()
        })
        wait(for: [unmuteExp], timeout: timeout)
    }
    
    func testConversationQuery() {
        guard let clientA = newOpenedClient() else {
            XCTFail()
            return
        }
        
        var ID1: String? = nil
        var ID2: String? = nil
        var ID3: String? = nil
        var ID4: String? = nil
        for i in 0...3 {
            switch i {
            case 0:
                let createExp = expectation(description: "create normal conversation")
                createExp.expectedFulfillmentCount = 2
                try? clientA.createConversation(clientIDs: [uuid], isUnique: false, completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    ID1 = result.value?.ID
                    let message = IMTextMessage()
                    message.text = "test"
                    try? result.value?.send(message: message, completion: { (result) in
                        XCTAssertTrue(result.isSuccess)
                        XCTAssertNil(result.error)
                        createExp.fulfill()
                    })
                    createExp.fulfill()
                })
                wait(for: [createExp], timeout: timeout)
            case 1:
                let createExp = expectation(description: "create chat room")
                try? clientA.createChatRoom(completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    ID2 = result.value?.ID
                    createExp.fulfill()
                })
                wait(for: [createExp], timeout: timeout)
            case 2:
                let ID = IMConversationTestCase.newServiceConversation()
                XCTAssertNotNil(ID)
                ID3 = ID
            case 3:
                let createExp = expectation(description: "create temporary conversation")
                try? clientA.createTemporaryConversation(clientIDs: [uuid], timeToLive: 3600, completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    ID4 = result.value?.ID
                    createExp.fulfill()
                })
                wait(for: [createExp], timeout: timeout)
            default:
                break
            }
        }
        
        guard
            let normalConvID = ID1,
            let chatRoomID = ID2,
            let serviceID = ID3,
            let tempID = ID4
            else
        {
            XCTFail()
            return
        }
        
        delay()
        clientA.convCollection.removeAll()
        
        let queryExp1 = expectation(description: "query normal conversation with message and without member")
        let query1 = clientA.conversationQuery
        query1.options = [.notContainMembers, .containLastMessage]
        try? query1.getConversation(by: normalConvID) { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.convType, .normal)
            if let conv = result.value {
                XCTAssertTrue(type(of: conv) == IMConversation.self)
                XCTAssertEqual(conv.rawData["objectId"] as? String, conv.ID)
                XCTAssertEqual(conv.rawData["conv_type"] as? Int, 1)
            }
            XCTAssertEqual(result.value?.members ?? [], [])
            XCTAssertNotNil(result.value?.lastMessage)
            queryExp1.fulfill()
        }
        wait(for: [queryExp1], timeout: timeout)
        
        let queryExp2 = expectation(description: "query chat room")
        try? clientA.conversationQuery.getConversation(by: chatRoomID, completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.convType, .transient)
            if let conv = result.value as? IMChatRoom {
                XCTAssertEqual(conv.rawData["objectId"] as? String, conv.ID)
                XCTAssertEqual(conv.rawData["conv_type"] as? Int, 2)
                XCTAssertTrue(type(of: conv) == IMChatRoom.self)
            }
            queryExp2.fulfill()
        })
        wait(for: [queryExp2], timeout: timeout)

        let queryExp3 = expectation(description: "query service conversation")
        try? clientA.conversationQuery.getConversation(by: serviceID, completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.convType, .system)
            if let conv = result.value as? IMServiceConversation {
                XCTAssertEqual(conv.rawData["objectId"] as? String, conv.ID)
                XCTAssertEqual(conv.rawData["conv_type"] as? Int, 3)
                XCTAssertTrue(type(of: conv) == IMServiceConversation.self)
            }
            queryExp3.fulfill()
        })
        wait(for: [queryExp3], timeout: timeout)
        
        clientA.convCollection.removeAll()
        
        let queryAllExp = expectation(description: "query all")
        queryAllExp.expectedFulfillmentCount = 4
        try? clientA.conversationQuery.getConversations(by: [normalConvID, chatRoomID, serviceID], completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.count, 3)
            if let convs = result.value {
                for conv in convs {
                    switch conv.convType {
                    case .normal:
                        queryAllExp.fulfill()
                    case .transient:
                        queryAllExp.fulfill()
                    case .system:
                        queryAllExp.fulfill()
                    default:
                        break
                    }
                }
            }
            queryAllExp.fulfill()
        })
        wait(for: [queryAllExp], timeout: timeout)
        
        let queryTempExp = expectation(description: "query temporary conversation")
        try? clientA.conversationQuery.getTemporaryConversation(by: tempID) { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.value)
            if let conv = result.value {
                XCTAssertEqual(conv.rawData["objectId"] as? String, conv.ID)
                XCTAssertEqual(conv.rawData["conv_type"] as? Int, 4)
            }
            queryTempExp.fulfill()
        }
        wait(for: [queryTempExp], timeout: timeout)
        
        clientA.convCollection.removeAll()
        
        let generalQueryExp1 = expectation(description: "general query with default conditon")
        try? clientA.conversationQuery.findConversations(completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.count, 1)
            XCTAssertEqual(result.value?.first?.convType, .normal)
            XCTAssertEqual(result.value?.first?.members?.contains(clientA.ID), true)
            generalQueryExp1.fulfill()
        })
        wait(for: [generalQueryExp1], timeout: timeout)
        
        let generalQueryExp2 = expectation(description: "general query with custom conditon")
        let generalQuery1 = clientA.conversationQuery
        try! generalQuery1.where(IMConversation.Key.transient.rawValue, .equalTo(true))
        let generalQuery2 = clientA.conversationQuery
        try! generalQuery2.where(IMConversation.Key.system.rawValue, .equalTo(true))
        let generalQuery3 = ((try? generalQuery1.or(generalQuery2)) as IMConversationQuery??)
        try! generalQuery3??.where(IMConversation.Key.createdAt.rawValue, .ascending)
        generalQuery3??.limit = 5
        ((try? generalQuery3??.findConversations(completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertLessThanOrEqual(result.value?.count ?? .max, 5)
            if let convs = result.value {
                let types: [IMConversation.ConvType] = [.system, .transient]
                var date = Date(timeIntervalSince1970: 0)
                for conv in convs {
                    XCTAssertTrue(types.contains(conv.convType))
                    XCTAssertNotNil(conv.createdAt)
                    if let createdAt = conv.createdAt {
                        XCTAssertGreaterThanOrEqual(createdAt, date)
                        date = createdAt
                    }
                }
            }
            generalQueryExp2.fulfill()
        })) as ()??)
        wait(for: [generalQueryExp2], timeout: timeout)
        
        for constraint in [LCQuery.Constraint.selected, LCQuery.Constraint.included] {
            do {
                let conversationQuery = clientA.conversationQuery
                try conversationQuery.where("key", constraint)
                XCTFail()
            } catch {
                XCTAssertTrue(error is LCError)
            }
        }
    }
    
    func testUpdateAttribution() {
        guard let clientA = newOpenedClient() else {
            XCTFail()
            return
        }
        
        RTMConnectionManager.default
            .imProtobuf1Registry.removeAll()
        RTMConnectionManager.default
            .imProtobuf3Registry.removeAll()
        
        guard let clientB = newOpenedClient() else {
            XCTFail()
            return
        }
        
        let delegatorA = IMClientTestCase.Delegator()
        clientA.delegate = delegatorA
        let delegatorB = IMClientTestCase.Delegator()
        clientB.delegate = delegatorB
        
        var convA: IMConversation? = nil
        var convB: IMConversation? = nil
        
        let nameKey = IMConversation.Key.name.rawValue
        let attrKey = IMConversation.Key.attributes.rawValue
        let createKey = "create"
        let deleteKey = "delete"
        let arrayKey = "array"
        
        var previousUpdatedAt: Date?
        
        let createConvExp = expectation(description: "create conversation")
        try! clientA.createConversation(
            clientIDs: [clientA.ID, clientB.ID],
            name: uuid,
            attributes: [
                deleteKey: uuid,
                arrayKey: [uuid]
            ],
            isUnique: false)
        { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            convA = result.value
            previousUpdatedAt = convA?.updatedAt ?? convA?.createdAt
            createConvExp.fulfill()
        }
        wait(for: [createConvExp], timeout: timeout)
        
        delay()
        
        let data: [String: Any] = [
            nameKey: uuid,
            "\(attrKey).\(createKey)": uuid,
            "\(attrKey).\(deleteKey)": ["__op": "Delete"],
            "\(attrKey).\(arrayKey)": ["__op": "Add", "objects": [uuid]]
        ]
        
        let updateExp = expectation(description: "update")
        updateExp.expectedFulfillmentCount = 2
        delegatorB.conversationEvent = { client, conv, event in
            if conv.ID == convA?.ID {
                switch event {
                case let .dataUpdated(updatingData: updatingData, updatedData: updatedData, byClientID: byClientID, at: at):
                    XCTAssertNotNil(updatedData)
                    XCTAssertNotNil(updatingData)
                    XCTAssertNotNil(at)
                    XCTAssertEqual(byClientID, clientA.ID)
                    if let updatedAt = at, let preUpdatedAt = previousUpdatedAt {
                        XCTAssertGreaterThan(updatedAt, preUpdatedAt)
                    } else {
                        XCTFail()
                    }
                    convB = conv
                    updateExp.fulfill()
                default:
                    break
                }
            }
        }
        try! convA?.update(attribution: data, completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            if let updatedAt = convA?.updatedAt, let preUpdatedAt = previousUpdatedAt {
                XCTAssertGreaterThan(updatedAt, preUpdatedAt)
            } else {
                XCTFail()
            }
            updateExp.fulfill()
        })
        wait(for: [updateExp], timeout: timeout)
        
        let check = { (conv: IMConversation?) in
            XCTAssertEqual(conv?.name, data[nameKey] as? String)
            XCTAssertEqual(conv?.attributes?[createKey] as? String, data["\(attrKey).\(createKey)"] as? String)
            XCTAssertNil(conv?.attributes?[deleteKey])
            XCTAssertNotNil(conv?.attributes?[arrayKey])
        }
        check(convA)
        check(convB)
        XCTAssertEqual(convA?.attributes?[arrayKey] as? [String], convB?.attributes?[arrayKey] as? [String])
    }
    
    func testOfflineEvents() {
        guard let clientA = newOpenedClient() else {
            return
        }
        let delegatorA = IMClientTestCase.Delegator()
        clientA.delegate = delegatorA
        
        RTMConnectionManager.default
            .imProtobuf1Registry.removeAll()
        RTMConnectionManager.default
            .imProtobuf3Registry.removeAll()
        
        guard let clientB = newOpenedClient() else {
            return
        }
        let delegatorB = IMClientTestCase.Delegator()
        clientB.delegate = delegatorB
        
        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "create conv and send msg with rcp")
            exp.expectedFulfillmentCount = 5
            return exp
        }) { (exp) in
            delegatorA.messageEvent = { client, conv, event in
                switch event {
                case .received:
                    exp.fulfill()
                default:
                    break
                }
            }
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case .joined:
                    exp.fulfill()
                    let message = IMTextMessage()
                    message.text = "text"
                    try! conv.send(message: message, options: [.needReceipt], completion: { (result) in
                        XCTAssertTrue(result.isSuccess)
                        XCTAssertNil(result.error)
                        exp.fulfill()
                    })
                case .message(event: let msgEvent):
                    switch msgEvent {
                    case .delivered:
                        exp.fulfill()
                    default:
                        break
                    }
                default:
                    break
                }
            }
            try! clientA.createConversation(clientIDs: [clientB.ID], completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        delegatorA.reset()
        delegatorB.reset()
        
        XCTAssertNotNil(clientB.localRecord.lastServerTimestamp)
        
        delay()
        clientB.connection.disconnect()
        delay()
        
        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "conv read")
            exp.expectedFulfillmentCount = 1
            return exp
        }) { (exp) in
            let conv = clientA.convCollection.first?.value
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case .unreadMessageCountUpdated:
                    exp.fulfill()
                default:
                    break
                }
            }
            conv?.read()
        }
        delegatorA.reset()
        
        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "create another normal conv")
            exp.expectedFulfillmentCount = 3
            return exp
        }) { exp in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case .joined:
                    exp.fulfill()
                case .membersJoined:
                    exp.fulfill()
                default:
                    break
                }
            }
            try! clientA.createConversation(clientIDs: [clientB.ID], isUnique: false) { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            }
        }
        delegatorA.reset()
        
        expecting(description: "update normal conv attr") { (exp) in
            let conv = clientA.convCollection.first?.value
            let name = self.uuid
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case .dataUpdated:
                    XCTAssertEqual(conv.name, name)
                    exp.fulfill()
                default:
                    break
                }
            }
            try! conv?.update(attribution: ["name": name], completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        delegatorA.reset()
        
        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "create temp conv")
            exp.expectedFulfillmentCount = 3
            return exp
        }) { exp in
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case .joined:
                    exp.fulfill()
                case .membersJoined:
                    exp.fulfill()
                default:
                    break
                }
            }
            try! clientA.createTemporaryConversation(clientIDs: [clientB.ID], timeToLive: 3600, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        delegatorA.reset()
        
        delay()
        
        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "get offline events")
            exp.expectedFulfillmentCount = 6
            return exp
        }) { (exp) in
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case .joined:
                    if conv is IMTemporaryConversation {
                        exp.fulfill()
                    } else {
                        exp.fulfill()
                    }
                case .membersJoined:
                    if conv is IMTemporaryConversation {
                        exp.fulfill()
                    } else {
                        exp.fulfill()
                    }
                case .dataUpdated:
                    exp.fulfill()
                case .message(event: let msgEvent):
                    switch msgEvent {
                    case .read:
                        exp.fulfill()
                    default:
                        break
                    }
                default:
                    break
                }
            }
            clientB.connection.connect()
        }
        delegatorB.reset()
    }
    
    func testMemberInfo() {
        guard
            let clientA = newOpenedClient(),
            let clientB = newOpenedClient() else
        {
            XCTFail()
            return
        }
        let clientCID: String = self.uuid
        
        let delegatorA = IMClientTestCase.Delegator()
        clientA.delegate = delegatorA
        let delegatorB = IMClientTestCase.Delegator()
        clientB.delegate = delegatorB
        
        var convA: IMConversation?
        
        expecting { (exp) in
            try! clientA.createConversation(clientIDs: [clientB.ID, clientCID], completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                convA = result.value
                exp.fulfill()
            })
        }
        
        do {
            try convA?.update(role: .owner, ofMember: clientB.ID, completion: { (_) in })
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        
        expecting { (exp) in
            convA?.fetchMemberInfoTable(completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertNotNil(convA?.memberInfoTable)
                XCTAssertEqual(convA?.memberInfoTable?.isEmpty, true)
                exp.fulfill()
            })
        }
        
        multiExpecting(expectations: { () -> [XCTestExpectation] in
            let exp = self.expectation(description: "change member role to manager")
            exp.expectedFulfillmentCount = 2
            return [exp]
        }) { (exps) in
            let exp = exps[0]
            
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .memberInfoChanged(info: info, byClientID: byClientID, at: at):
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual(info.role, .manager)
                    XCTAssertEqual(info.ID, clientB.ID)
                    XCTAssertEqual(info.conversationID, conv.ID)
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    XCTAssertNil(conv.memberInfoTable)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            try! convA?.update(role: .manager, ofMember: clientB.ID, completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(convA?.memberInfoTable?[clientB.ID]?.role, .manager)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            let convB = clientB.convCollection.values.first
            XCTAssertNil(convB?.memberInfoTable)
            convB?.getMemberInfo(by: clientB.ID, completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        multiExpecting(expectations: { () -> [XCTestExpectation] in
            let exp = self.expectation(description: "change member role to member")
            exp.expectedFulfillmentCount = 2
            return [exp]
        }) { (exps) in
            let exp = exps[0]
            
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .memberInfoChanged(info: info, byClientID: byClientID, at: at):
                    XCTAssertEqual(info.role, .member)
                    XCTAssertEqual(info.ID, clientB.ID)
                    XCTAssertEqual(info.conversationID, conv.ID)
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    XCTAssertEqual(conv.memberInfoTable?[clientB.ID]?.role, .member)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            try! convA?.update(role: .member, ofMember: clientB.ID, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(convA?.memberInfoTable?[clientB.ID]?.role, .member)
                exp.fulfill()
            })
        }
    }
    
    func testMemberBlock() {
        guard
            let clientA = newOpenedClient(),
            let clientB = newOpenedClient(),
            let clientC = newOpenedClient() else
        {
            XCTFail()
            return
        }
        
        let delegatorA = IMClientTestCase.Delegator()
        clientA.delegate = delegatorA
        let delegatorB = IMClientTestCase.Delegator()
        clientB.delegate = delegatorB
        let delegatorC = IMClientTestCase.Delegator()
        clientC.delegate = delegatorC
        
        var convA: IMConversation?
        
        expecting { (exp) in
            try! clientA.createConversation(clientIDs: [clientB.ID, clientC.ID], completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                convA = result.value
                exp.fulfill()
            })
        }
        
        multiExpecting(expectations: { () -> [XCTestExpectation] in
            let exp = self.expectation(description: "block member")
            exp.expectedFulfillmentCount = 7
            return [exp]
        }) { (exps) in
            let exp = exps[0]
            
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersBlocked(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertTrue(members.contains(clientC.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                case let .membersLeft(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertTrue(members.contains(clientC.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .blocked(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                case let .left(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            delegatorC.conversationEvent = { client, conv, event in
                switch event {
                case let .blocked(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                case let .left(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            try! convA?.block(members: [clientB.ID, clientC.ID], completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        delegatorA.reset()
        delegatorB.reset()
        delegatorC.reset()
        
        expecting { (exp) in
            convA?.checkBlocking(member: clientA.ID, completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value, false)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            convA?.checkBlocking(member: clientB.ID, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value, true)
                exp.fulfill()
            })
        }
        
        do {
            try convA?.getBlockedMembers(limit: 0, completion: { (result) in })
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        
        do {
            try convA?.getBlockedMembers(limit: 101, completion: { (result) in })
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        
        var next: String?
        
        expecting { (exp) in
            try! convA?.getBlockedMembers(limit: 1, completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.members.count, 1)
                if let member = result.value?.members.first {
                    XCTAssertTrue([clientB.ID, clientC.ID].contains(member))
                }
                XCTAssertNotNil(result.value?.next)
                next = result.value?.next
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            try! convA?.getBlockedMembers(next: next, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.members.count, 1)
                if let member = result.value?.members.first {
                    XCTAssertTrue([clientB.ID, clientC.ID].contains(member))
                }
                XCTAssertNil(result.value?.next)
                exp.fulfill()
            })
        }
        
        multiExpecting(expectations: { () -> [XCTestExpectation] in
            let exp = self.expectation(description: "unblock member")
            exp.expectedFulfillmentCount = 4
            return [exp]
        }) { (exps) in
            let exp = exps[0]
            
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersUnblocked(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertTrue(members.contains(clientC.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .unblocked(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            delegatorC.conversationEvent = { client, conv, event in
                switch event {
                case let .unblocked(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            try! convA?.unblock(members: [clientB.ID, clientC.ID], completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
    }
    
    func testMemberMute() {
        guard
            let clientA = newOpenedClient(),
            let clientB = newOpenedClient(),
            let clientC = newOpenedClient() else
        {
            XCTFail()
            return
        }
        
        let delegatorA = IMClientTestCase.Delegator()
        clientA.delegate = delegatorA
        let delegatorB = IMClientTestCase.Delegator()
        clientB.delegate = delegatorB
        let delegatorC = IMClientTestCase.Delegator()
        clientC.delegate = delegatorC
        
        var convA: IMConversation?
        
        expecting { (exp) in
            try! clientA.createConversation(clientIDs: [clientB.ID, clientC.ID], completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                convA = result.value
                exp.fulfill()
            })
        }
        
        multiExpecting(expectations: { () -> [XCTestExpectation] in
            let exp = self.expectation(description: "mute member")
            exp.expectedFulfillmentCount = 4
            return [exp]
        }) { (exps) in
            let exp = exps[0]
            
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersMuted(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertTrue(members.contains(clientC.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .muted(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            delegatorC.conversationEvent = { client, conv, event in
                switch event {
                case let .muted(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            try! convA?.mute(members: [clientB.ID, clientC.ID], completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        delegatorA.reset()
        delegatorB.reset()
        delegatorC.reset()
        
        expecting { (exp) in
            convA?.checkMuting(member: clientA.ID, completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value, false)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            convA?.checkMuting(member: clientB.ID, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value, true)
                exp.fulfill()
            })
        }
        
        do {
            try convA?.getMutedMembers(limit: 0, completion: { (result) in })
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        
        do {
            try convA?.getMutedMembers(limit: 101, completion: { (result) in })
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        
        var next: String?
        
        expecting { (exp) in
            try! convA?.getMutedMembers(limit: 1, completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.members.count, 1)
                if let member = result.value?.members.first {
                    XCTAssertTrue([clientB.ID, clientC.ID].contains(member))
                }
                XCTAssertNotNil(result.value?.next)
                next = result.value?.next
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            try! convA?.getMutedMembers(next: next, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.members.count, 1)
                if let member = result.value?.members.first {
                    XCTAssertTrue([clientB.ID, clientC.ID].contains(member))
                }
                XCTAssertNil(result.value?.next)
                exp.fulfill()
            })
        }
        
        multiExpecting(expectations: { () -> [XCTestExpectation] in
            let exp = self.expectation(description: "unmute member")
            exp.expectedFulfillmentCount = 4
            return [exp]
        }) { (exps) in
            let exp = exps[0]
            
            delegatorA.conversationEvent = { client, conv, event in
                switch event {
                case let .membersUnmuted(members: members, byClientID: byClientID, at: at):
                    XCTAssertEqual(members.count, 2)
                    XCTAssertTrue(members.contains(clientB.ID))
                    XCTAssertTrue(members.contains(clientC.ID))
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            delegatorB.conversationEvent = { client, conv, event in
                switch event {
                case let .unmuted(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            delegatorC.conversationEvent = { client, conv, event in
                switch event {
                case let .unmuted(byClientID: byClientID, at: at):
                    XCTAssertEqual(byClientID, clientA.ID)
                    XCTAssertNotNil(at)
                    exp.fulfill()
                default:
                    break
                }
            }
            
            try! convA?.unmute(members: [clientB.ID, clientC.ID], completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
    }
    
}

extension IMConversationTestCase {
    
    func newOpenedClient(clientID: String? = nil) -> IMClient? {
        var client = try? IMClient(
            ID: clientID ?? uuid,
            options: [.receiveUnreadMessageCountAfterSessionDidOpen])
        let exp = expectation(description: "open")
        client?.open { (result) in
            if result.isFailure {
                client = nil
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
        return client
    }
    
    static func newServiceConversation() -> String? {
        var objectID: String?
        var loop = true
        _ = LCApplication.default.httpClient.request(
            url: LCApplication.default.v2router.route(
                path: "/rtm/service-conversations", module: .api)!,
            method: .post,
            parameters: ["name": uuid],
            headers: nil,
            completionQueue: .main)
        { (response) in
            objectID = response["objectId"]
            loop.toggle()
        }
        while loop {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
        return objectID
    }
    
    static func subscribing(serviceConversation conversationID: String, by clientID: String) -> Bool {
        var success: Bool = false
        var loop = true
        _ = LCApplication.default.httpClient.request(
            url: LCApplication.default.v2router.route(
                path: "/rtm/service-conversations/\(conversationID)/subscribers")!,
            method: .post,
            parameters: ["client_id": clientID],
            headers: ["X-LC-Key": LCApplication.default.masterKey],
            completionQueue: .main)
        { (response) in
            success = response.isSuccess
            loop.toggle()
        }
        while loop {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
        return success
    }
    
    static func broadcastingMessage(to conversationID: String, content: String = "test") -> (String, Int64)? {
        var tuple: (String, Int64)?
        var loop = true
        _ = LCApplication.default.httpClient.request(
            url: LCApplication.default.v2router.route(
                path: "/rtm/service-conversations/\(conversationID)/broadcasts", module: .api)!,
            method: .post,
            parameters: ["from_client": "master", "message": content],
            headers: ["X-LC-Key": LCApplication.default.masterKey],
            completionQueue: .main)
        { (response) in
            if let result: [String: Any] = response["result"],
                let messageID: String = result["msg-id"] as? String,
                let timestamp: Int64 = result["timestamp"] as? Int64 {
                tuple = (messageID, timestamp)
            }
            loop.toggle()
        }
        while loop {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
        return tuple
    }
    
}
