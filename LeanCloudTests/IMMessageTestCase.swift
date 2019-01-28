//
//  IMMessageTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2019/1/28.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class IMMessageTestCase: RTMBaseTestCase {
    
    func testMessageSendingAndReceiving() {
        guard
            let tuples = convenienceInit(),
            let tuple1 = tuples.first,
            let tuple2 = tuples.last
            else
        {
            XCTFail()
            return
        }
        
        let delegatorA = tuple1.delegator
        let conversationA = tuple1.conversation
        let delegatorB = tuple2.delegator
        let conversationB = tuple2.conversation
        
        let checkMessage: (LCConversation, LCMessage) -> Void = { conv, message in
            XCTAssertEqual(message.status, .sent)
            XCTAssertNotNil(message.ID)
            XCTAssertEqual(conv.ID, message.conversationID)
            XCTAssertEqual(conv.clientID, message.localClientID)
            XCTAssertNotNil(message.sentTimestamp)
            XCTAssertNotNil(message.sentDate)
            XCTAssertNotNil(message.content)
        }
        
        let exp1 = expectation(description: "A send message to B")
        exp1.expectedFulfillmentCount = 5
        let messageAB = LCMessage()
        messageAB.content = .string("AB")
        delegatorA.conversationEvent = { client, converstion, event in
            switch event {
            case .lastMessageUpdated:
                XCTAssertTrue(messageAB === converstion.lastMessage)
                exp1.fulfill()
            case .unreadMessageUpdated:
                XCTFail()
            default:
                break
            }
        }
        delegatorB.conversationEvent = { client, conversation, event in
            switch event {
            case .message(event: let mEvent):
                if case let .received(message: message) = mEvent {
                    checkMessage(conversation, message)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.fromClientID, conversationA.clientID)
                    exp1.fulfill()
                }
            case .lastMessageUpdated:
                exp1.fulfill()
            case .unreadMessageUpdated:
                XCTAssertEqual(conversation.unreadMessageCount, 1)
                exp1.fulfill()
            default:
                break
            }
        }
        try? conversationA.send(message: messageAB) { (result) in
            XCTAssertTrue(result.isSuccess)
            checkMessage(conversationA, messageAB)
            XCTAssertEqual(messageAB.ioType, .out)
            XCTAssertEqual(messageAB.fromClientID, conversationA.clientID)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: timeout)
        
        let exp2 = expectation(description: "B send message to A")
        exp2.expectedFulfillmentCount = 5
        let messageBA = LCMessage()
        messageBA.content = .string("BA")
        delegatorA.conversationEvent = { client, conversation, event in
            switch event {
            case .message(event: let mEvent):
                if case let .received(message: message) = mEvent {
                    checkMessage(conversation, message)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.fromClientID, conversationB.clientID)
                    exp2.fulfill()
                }
            case .lastMessageUpdated:
                exp2.fulfill()
            case .unreadMessageUpdated:
                XCTAssertEqual(conversation.unreadMessageCount, 1)
                exp2.fulfill()
            default:
                break
            }
        }
        delegatorB.conversationEvent = { client, conversation, event in
            switch event {
            case .lastMessageUpdated:
                XCTAssertTrue(conversation.lastMessage === messageBA)
                exp2.fulfill()
            case .unreadMessageUpdated:
                XCTFail()
            default:
                break
            }
        }
        try? conversationB.send(message: messageBA, completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            checkMessage(conversationB, messageBA)
            XCTAssertEqual(messageBA.ioType, .out)
            XCTAssertEqual(messageBA.fromClientID, conversationB.clientID)
            exp2.fulfill()
        })
        wait(for: [exp2], timeout: timeout)
        
        XCTAssertTrue(read(
            conversations: [conversationA, conversationB],
            delegators: [delegatorA, delegatorB])
        )
    }
    
    func testMessageContinuousSendingAndReceiving() {
        guard
            let tuples = convenienceInit(),
            let tuple1 = tuples.first,
            let tuple2 = tuples.last
            else
        {
            XCTFail()
            return
        }
        
        let delegatorA = tuple1.delegator
        let conversationA = tuple1.conversation
        let delegatorB = tuple2.delegator
        let conversationB = tuple2.conversation
        
        let exp = expectation(description: "message continuous sending and receiving")
        let count = 10
        exp.expectedFulfillmentCount = (count * 2) + 2
        var receivedMessageCountA = count
        delegatorA.conversationEvent = { client, conversation, event in
            switch event {
            case .message(event: let mEvent):
                switch mEvent {
                case .received(message: let message):
                    receivedMessageCountA -= 1
                    conversation.read(message: message)
                    exp.fulfill()
                default:
                    break
                }
            case .unreadMessageUpdated:
                if receivedMessageCountA == 0 {
                    XCTAssertEqual(conversation.unreadMessageCount, 0)
                    exp.fulfill()
                }
            default:
                break
            }
        }
        var receivedMessageCountB = count
        delegatorB.conversationEvent = { client, conversation, event in
            switch event {
            case .message(event: let mEvent):
                switch mEvent {
                case .received(message: let message):
                    receivedMessageCountB -= 1
                    conversation.read(message: message)
                    exp.fulfill()
                default:
                    break
                }
            case .unreadMessageUpdated:
                if receivedMessageCountB == 0 {
                    XCTAssertEqual(conversation.unreadMessageCount, 0)
                    exp.fulfill()
                }
            default:
                break
            }
        }
        for _ in 0..<count {
            let expA = expectation(description: "A send message")
            let messageA = LCMessage()
            messageA.content = .string("")
            try? conversationA.send(message: messageA, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                expA.fulfill()
            })
            wait(for: [expA], timeout: timeout)
            let expB = expectation(description: "B send message")
            let messageB = LCMessage()
            messageB.content = .string("")
            try? conversationB.send(message: messageB, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                expB.fulfill()
            })
            wait(for: [expB], timeout: timeout)
        }
        wait(for: [exp], timeout: timeout)
        
        XCTAssertEqual(conversationA.unreadMessageCount, 0)
        XCTAssertEqual(conversationB.unreadMessageCount, 0)
    }

}

extension IMMessageTestCase {
    
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
    
    func createConversation(client: LCClient, clientIDs: Set<String>) -> LCConversation? {
        var conversation: LCConversation? = nil
        let exp = expectation(description: "create conversation")
        try? client.createConversation(clientIDs: clientIDs, completion: { (result) in
            conversation = result.value
            exp.fulfill()
        })
        wait(for: [exp], timeout: timeout)
        return conversation
    }
    
    func convenienceInit(
        clientCount: Int = 2,
        clientOptions: LCClient.Options = [.receiveUnreadMessageCountAfterSessionDidOpen])
        -> [(client: LCClient, conversation: LCConversation, delegator: IMClientTestCase.Delegator)]?
    {
        var tuples: [(client: LCClient, conversation: LCConversation, delegator: IMClientTestCase.Delegator)] = []
        let exp = expectation(description: "get conversations")
        exp.expectedFulfillmentCount = clientCount
        var clientMap: [String: LCClient] = [:]
        var delegatorMap: [String: IMClientTestCase.Delegator] = [:]
        var conversationMap: [String: LCConversation] = [:]
        var clientIDs: [String] = []
        for _ in 0..<clientCount {
            guard let client = newOpenedClient(options: clientOptions) else {
                continue
            }
            let delegator = IMClientTestCase.Delegator()
            delegator.conversationEvent = { c, conv, event in
                if c === client, case .joined = event {
                    conversationMap[c.ID] = conv
                    exp.fulfill()
                }
            }
            client.delegate = delegator
            clientMap[client.ID] = client
            delegatorMap[client.ID] = delegator
            clientIDs.append(client.ID)
        }
        if let clientID: String = clientIDs.first,
            let client: LCClient = clientMap[clientID] {
            let _ = createConversation(client: client, clientIDs: Set(clientIDs))
        }
        wait(for: [exp], timeout: timeout)
        var convID: String? = nil
        for item in clientIDs {
            if let client = clientMap[item],
                let conv = conversationMap[item],
                let delegator = delegatorMap[item] {
                if let convID = convID {
                    XCTAssertEqual(convID, conv.ID)
                } else {
                    convID = conv.ID
                }
                tuples.append((client, conv, delegator))
            }
        }
        if tuples.count == clientCount {
            return tuples
        } else {
            return nil
        }
    }
    
    func read(conversations: [LCConversation], delegators: [IMClientTestCase.Delegator]) -> Bool {
        var count = conversations.count
        let exp = expectation(description: "read")
        exp.expectedFulfillmentCount = count
        for item in delegators {
            item.conversationEvent = { c, conv, e in
                if case .unreadMessageUpdated = e {
                    count -= 1
                    XCTAssertEqual(conv.unreadMessageCount, 0)
                    exp.fulfill()
                }
            }
        }
        for item in conversations {
            item.read()
        }
        wait(for: [exp], timeout: timeout)
        return (count == 0)
    }
    
}
