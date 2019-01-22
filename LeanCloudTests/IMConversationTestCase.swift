//
//  IMConversationTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2019/1/20.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class IMConversationTestCase: RTMBaseTestCase {
    
    private var uuid: String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    private func newOpenedClient(customRTMURL: URL? = nil) -> LCClient? {
        let client = try! LCClient(ID: uuid, customServer: customRTMURL)
        let exp = expectation(description: "")
        client.open { (_) in exp.fulfill() }
        wait(for: [exp], timeout: timeout)
        return client
    }

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
        { XCTFail(); return }
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
        { XCTFail(); return }
        
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
        guard
            let client = newOpenedClient()
            else
        { XCTFail(); return }
        
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
        { XCTFail(); return }
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
    
}
