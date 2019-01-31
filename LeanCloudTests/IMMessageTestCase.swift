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
            let tuples = convenienceInit(clientOptions: [.receiveUnreadMessageCountAfterSessionDidOpen]),
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
        
        let checkMessage: (IMConversation, IMMessage) -> Void = { conv, message in
            XCTAssertEqual(message.status, .sent)
            XCTAssertNotNil(message.ID)
            XCTAssertEqual(conv.ID, message.conversationID)
            XCTAssertEqual(conv.clientID, message.localClientID)
            XCTAssertNotNil(message.sentTimestamp)
            XCTAssertNotNil(message.sentDate)
            XCTAssertNotNil(message.content)
        }
        
        let exp1 = expectation(description: "A send message to B")
        exp1.expectedFulfillmentCount = 6
        let stringMessage = IMMessage()
        try? stringMessage.set(content: .string("string"))
        delegatorA.conversationEvent = { client, converstion, event in
            switch event {
            case .lastMessageUpdated:
                XCTAssertTrue(stringMessage === converstion.lastMessage)
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
                    XCTAssertNotNil(message.content?.string)
                    exp1.fulfill()
                    conversation.read(message: message)
                }
            case .lastMessageUpdated:
                exp1.fulfill()
            case .unreadMessageUpdated:
                XCTAssertTrue([0,1].contains(conversation.unreadMessageCount))
                exp1.fulfill()
            default:
                break
            }
        }
        try? conversationA.send(message: stringMessage) { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            checkMessage(conversationA, stringMessage)
            XCTAssertEqual(stringMessage.ioType, .out)
            XCTAssertEqual(stringMessage.fromClientID, conversationA.clientID)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: timeout)
        
        let exp2 = expectation(description: "B send message to A")
        exp2.expectedFulfillmentCount = 6
        let dataMessage = IMMessage()
        try? dataMessage.set(content: .data("data".data(using: .utf8)!))
        delegatorA.conversationEvent = { client, conversation, event in
            switch event {
            case .message(event: let mEvent):
                if case let .received(message: message) = mEvent {
                    checkMessage(conversation, message)
                    XCTAssertEqual(message.ioType, .in)
                    XCTAssertEqual(message.fromClientID, conversationB.clientID)
                    XCTAssertNotNil(message.content?.data)
                    exp2.fulfill()
                    conversation.read(message: message)
                }
            case .lastMessageUpdated:
                exp2.fulfill()
            case .unreadMessageUpdated:
                XCTAssertTrue([0,1].contains(conversation.unreadMessageCount))
                exp2.fulfill()
            default:
                break
            }
        }
        delegatorB.conversationEvent = { client, conversation, event in
            switch event {
            case .lastMessageUpdated:
                XCTAssertTrue(conversation.lastMessage === dataMessage)
                exp2.fulfill()
            case .unreadMessageUpdated:
                XCTFail()
            default:
                break
            }
        }
        try? conversationB.send(message: dataMessage, completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            checkMessage(conversationB, dataMessage)
            XCTAssertEqual(dataMessage.ioType, .out)
            XCTAssertEqual(dataMessage.fromClientID, conversationB.clientID)
            exp2.fulfill()
        })
        wait(for: [exp2], timeout: timeout)
        
        XCTAssertEqual(conversationA.unreadMessageCount, 0)
        XCTAssertEqual(conversationB.unreadMessageCount, 0)
        XCTAssertNotNil(conversationA.lastMessage?.ID)
        XCTAssertNotNil(conversationA.lastMessage?.conversationID)
        XCTAssertNotNil(conversationA.lastMessage?.sentTimestamp)
        XCTAssertEqual(
            conversationA.lastMessage?.ID,
            conversationB.lastMessage?.ID
        )
        XCTAssertEqual(
            conversationA.lastMessage?.conversationID,
            conversationB.lastMessage?.conversationID
        )
        XCTAssertEqual(
            conversationA.lastMessage?.sentTimestamp,
            conversationB.lastMessage?.sentTimestamp
        )
    }
    
    func testMessageContinuousSendingAndReceiving() {
        guard
            let tuples = convenienceInit(clientOptions: [.receiveUnreadMessageCountAfterSessionDidOpen]),
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
        var lastMessageIDSet: Set<String> = []
        
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
                    if receivedMessageCountA == 0,
                        let msgID = message.ID {
                        lastMessageIDSet.insert(msgID)
                    }
                    conversation.read(message: message)
                    exp.fulfill()
                default:
                    break
                }
            case .unreadMessageUpdated:
                if receivedMessageCountA == 0,
                    conversation.unreadMessageCount == 0 {
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
                    if receivedMessageCountB == 0,
                        let msgID = message.ID {
                        lastMessageIDSet.insert(msgID)
                    }
                    conversation.read(message: message)
                    exp.fulfill()
                default:
                    break
                }
            case .unreadMessageUpdated:
                if receivedMessageCountB == 0,
                    conversation.unreadMessageCount == 0 {
                    exp.fulfill()
                }
            default:
                break
            }
        }
        for _ in 0..<count {
            let sendMessageExp = expectation(description: "send message")
            sendMessageExp.expectedFulfillmentCount = 2
            let messageA = IMMessage()
            messageA.content = .string("")
            let messageB = IMMessage()
            messageB.content = .string("")
            try? conversationA.send(message: messageA, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                sendMessageExp.fulfill()
            })
            try? conversationB.send(message: messageB, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                sendMessageExp.fulfill()
            })
            wait(for: [sendMessageExp], timeout: timeout)
        }
        wait(for: [exp], timeout: timeout)
        
        XCTAssertEqual(conversationA.unreadMessageCount, 0)
        XCTAssertEqual(conversationB.unreadMessageCount, 0)
        XCTAssertNotNil(conversationA.lastMessage?.ID)
        XCTAssertNotNil(conversationA.lastMessage?.conversationID)
        XCTAssertNotNil(conversationA.lastMessage?.sentTimestamp)
        XCTAssertEqual(
            conversationA.lastMessage?.ID,
            conversationB.lastMessage?.ID
        )
        XCTAssertEqual(
            conversationA.lastMessage?.conversationID,
            conversationB.lastMessage?.conversationID
        )
        XCTAssertEqual(
            conversationA.lastMessage?.sentTimestamp,
            conversationB.lastMessage?.sentTimestamp
        )
        XCTAssertTrue([1,2].contains(lastMessageIDSet.count))
        XCTAssertTrue(lastMessageIDSet.contains(conversationA.lastMessage?.ID ?? ""))
    }
    
    func testMessageReceipt() {
        
    }
    
    func testTransientMessageSendingAndReceiving() {
        guard
            let tuples = convenienceInit(),
            let tuple1 = tuples.first,
            let tuple2 = tuples.last
            else
        {
            XCTFail()
            return
        }
        
        let conversationA = tuple1.conversation
        let delegatorB = tuple2.delegator
        let checkMessage: (IMMessage) -> Void = { message in
            XCTAssertTrue(message.isTransient)
            XCTAssertNotNil(message.ID)
            XCTAssertNotNil(message.sentTimestamp)
            XCTAssertNotNil(message.conversationID)
            XCTAssertEqual(message.status, .sent)
        }
        
        let exp = expectation(description: "send transient message")
        exp.expectedFulfillmentCount = 2
        delegatorB.messageEvent = { client, conversation, event in
            switch event {
            case .received(message: let message):
                XCTAssertEqual(message.ioType, .in)
                checkMessage(message)
                exp.fulfill()
            default:
                break
            }
        }
        let message = IMMessage()
        message.content = .string("")
        try? conversationA.send(message: message, options: [.isTransient]) { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertEqual(message.ioType, .out)
            checkMessage(message)
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
    }
    
    func testMessageAutoSendingWhenOfflineAndReceiving() {
        guard
            let tuples = convenienceInit(),
            let tuple1 = tuples.first,
            let tuple2 = tuples.last
            else
        {
            XCTFail()
            return
        }
        
        let clientA = tuple1.client
        let conversationA = tuple1.conversation
        let delegatorB = tuple2.delegator
        
        let sendExp = expectation(description: "send message")
        let willMessage = IMMessage()
        willMessage.content = .string("")
        try? conversationA.send(message: willMessage, options: [.isAutoDeliveringWhenOffline]) { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(conversationA.lastMessage)
            XCTAssertTrue(willMessage.isWill)
            XCTAssertNotNil(willMessage.sentTimestamp)
            sendExp.fulfill()
        }
        wait(for: [sendExp], timeout: timeout)
        
        let receiveExp = expectation(description: "receive message")
        delegatorB.messageEvent = { client, conversation, event in
            switch event {
            case .received(message: let message):
                XCTAssertNotNil(message.ID)
                XCTAssertNotNil(message.conversationID)
                XCTAssertNotNil(message.sentTimestamp)
                XCTAssertEqual(message.ID, willMessage.ID)
                XCTAssertEqual(message.conversationID, willMessage.conversationID)
                XCTAssertNotNil(conversation.lastMessage)
                receiveExp.fulfill()
            default:
                break
            }
        }
        clientA.connection.disconnect()
        wait(for: [receiveExp], timeout: timeout)
    }
    
    func testSendMessageToChatRoomAndReceiving() {
        
    }
    
    func testCustomMessageSendingAndReceiving() {
        do {
            try InvalidCustomMessage.register()
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        do {
            try CustomMessage.register()
        } catch {
            XCTFail("\(error)")
        }
        let message = CustomMessage()
        do {
            try message.set(content: .string(""))
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        XCTAssertTrue(sendingAndReceiving(sentMessage: message))
    }
    
    func testTextMessageSendingAndReceiving() {
        let message = IMTextMessage()
        message.text = "test"
        let success = sendingAndReceiving(sentMessage: message) { (rMessage) in
            XCTAssertNotNil(rMessage?.text)
            XCTAssertEqual(rMessage?.text, message.text)
        }
        XCTAssertTrue(success)
    }
    
    func testImageMessageSendingAndReceiving() {
        for i in 0..<2 {
            let message = IMImageMessage()
            let fileURL: URL
            let format: String
            if i == 0 {
                format = "png"
                fileURL = resourceURL(name: "test", ext: format)
            } else {
                format = "jpg"
                fileURL = resourceURL(name: "test", ext: format)
            }
            message.file = LCFile(payload: .fileURL(fileURL: fileURL))
            let success = sendingAndReceiving(sentMessage: message) { (rMessage) in
                XCTAssertNotNil(rMessage?.file?.objectId?.value)
                XCTAssertEqual(rMessage?.format, format)
                XCTAssertNotNil(rMessage?.size)
                XCTAssertNotNil(rMessage?.height)
                XCTAssertNotNil(rMessage?.width)
                XCTAssertNotNil(rMessage?.url)
                XCTAssertEqual(rMessage?.file?.objectId?.value, message.file?.objectId?.value)
                XCTAssertEqual(rMessage?.format, message.format)
                XCTAssertEqual(rMessage?.size, message.size)
                XCTAssertEqual(rMessage?.height, message.height)
                XCTAssertEqual(rMessage?.width, message.width)
                XCTAssertEqual(rMessage?.url, message.url)
            }
            XCTAssertTrue(success)
        }
    }
    
    func testAudioMessageSendingAndReceiving() {
        let message = IMAudioMessage()
        let format: String = "mp3"
        message.file = LCFile(payload: .fileURL(fileURL: resourceURL(name: "test", ext: format)))
        let success = sendingAndReceiving(sentMessage: message) { (rMessage) in
            XCTAssertNotNil(rMessage?.file?.objectId?.value)
            XCTAssertEqual(rMessage?.format, format)
            XCTAssertNotNil(rMessage?.size)
            XCTAssertNotNil(rMessage?.duration)
            XCTAssertNotNil(rMessage?.url)
            XCTAssertEqual(rMessage?.file?.objectId?.value, message.file?.objectId?.value)
            XCTAssertEqual(rMessage?.format, message.format)
            XCTAssertEqual(rMessage?.size, message.size)
            XCTAssertEqual(rMessage?.duration, message.duration)
            XCTAssertEqual(rMessage?.url, message.url)
        }
        XCTAssertTrue(success)
    }
    
    func testVideoMessageSendingAndReceiving() {
        let message = IMVideoMessage()
        let format: String = "mp4"
        message.file = LCFile(payload: .fileURL(fileURL: resourceURL(name: "test", ext: format)))
        let success = sendingAndReceiving(sentMessage: message) { (rMessage) in
            XCTAssertNotNil(rMessage?.file?.objectId?.value)
            XCTAssertEqual(rMessage?.format, format)
            XCTAssertNotNil(rMessage?.size)
            XCTAssertNotNil(rMessage?.duration)
            XCTAssertNotNil(rMessage?.url)
            XCTAssertEqual(rMessage?.file?.objectId?.value, message.file?.objectId?.value)
            XCTAssertEqual(rMessage?.format, message.format)
            XCTAssertEqual(rMessage?.size, message.size)
            XCTAssertEqual(rMessage?.duration, message.duration)
            XCTAssertEqual(rMessage?.url, message.url)
        }
        XCTAssertTrue(success)
    }
    
    func testFileMessageSendingAndReceiving() {
        let message = IMFileMessage()
        let format: String = "zip"
        message.file = LCFile(payload: .fileURL(fileURL: resourceURL(name: "test", ext: format)))
        let success = sendingAndReceiving(sentMessage: message) { (rMessage) in
            XCTAssertNotNil(rMessage?.file?.objectId?.value)
            XCTAssertEqual(rMessage?.format, format)
            XCTAssertNotNil(rMessage?.size)
            XCTAssertNotNil(rMessage?.url)
            XCTAssertEqual(rMessage?.file?.objectId?.value, message.file?.objectId?.value)
            XCTAssertEqual(rMessage?.format, message.format)
            XCTAssertEqual(rMessage?.size, message.size)
            XCTAssertEqual(rMessage?.url, message.url)
        }
        XCTAssertTrue(success)
    }
    
    func testLocationMessageSendingAndReceiving() {
        let message = IMLocationMessage()
        message.location = LCGeoPoint(latitude: 180.0, longitude: 90.0)
        let success = sendingAndReceiving(sentMessage: message) { (rMessage) in
            XCTAssertEqual(rMessage?.latitude, 180.0)
            XCTAssertEqual(rMessage?.longitude, 90.0)
            XCTAssertEqual(rMessage?.latitude, message.latitude)
            XCTAssertEqual(rMessage?.longitude, message.longitude)
        }
        XCTAssertTrue(success)
    }
    
    func testMessageUpdating() {
        let oldMessage = IMMessage()
        let oldContent: String = "old"
        try? oldMessage.set(content: .string(oldContent))
        let newMessage = IMMessage()
        let newContent: String = "new"
        try? newMessage.set(content: .string(newContent))
        
        var sendingTuple: Tuple? = nil
        var receivingTuple: Tuple? = nil
        XCTAssertTrue(sendingAndReceiving(sentMessage: oldMessage, sendingTuple: &sendingTuple, receivingTuple: &receivingTuple))
        
        delay()
        
        let patchedMessageChecker: (IMMessage, IMMessage) -> Void = { patchedMessage, originMessage in
            XCTAssertNotNil(patchedMessage.ID)
            XCTAssertNotNil(patchedMessage.conversationID)
            XCTAssertNotNil(patchedMessage.sentTimestamp)
            XCTAssertNotNil(patchedMessage.patchedTimestamp)
            XCTAssertNotNil(patchedMessage.patchedDate)
            XCTAssertEqual(patchedMessage.ID, originMessage.ID)
            XCTAssertEqual(patchedMessage.conversationID, originMessage.conversationID)
            XCTAssertEqual(patchedMessage.sentTimestamp, originMessage.sentTimestamp)
            XCTAssertEqual(originMessage.content?.string, oldContent)
            XCTAssertEqual(patchedMessage.content?.string, newContent)
        }
        
        let exp = expectation(description: "message patch")
        exp.expectedFulfillmentCount = 2
        do {
            try receivingTuple?.conversation.update(oldMessage: oldMessage, by: newMessage, completion: { (_) in })
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        receivingTuple?.delegator.messageEvent = { client, conv, event in
            switch event {
            case .updated(updatedMessage: let patchedMessage):
                XCTAssertTrue(conv.lastMessage === patchedMessage)
                patchedMessageChecker(patchedMessage, oldMessage)
                exp.fulfill()
            default:
                break
            }
        }
        try? sendingTuple?.conversation.update(oldMessage: oldMessage, by: newMessage, completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            XCTAssertTrue(newMessage === sendingTuple?.conversation.lastMessage)
            patchedMessageChecker(newMessage, oldMessage)
            exp.fulfill()
        })
        wait(for: [exp], timeout: timeout)
    }
    
    func testMessageRecalling() {
        let oldMessage = IMMessage()
        let oldContent: String = "old"
        try? oldMessage.set(content: .string(oldContent))
        
        var sendingTuple: Tuple? = nil
        var receivingTuple: Tuple? = nil
        XCTAssertTrue(sendingAndReceiving(sentMessage: oldMessage, sendingTuple: &sendingTuple, receivingTuple: &receivingTuple))
        
        delay()
        
        let recalledMessageChecker: (IMMessage, IMMessage) -> Void = { patchedMessage, originMessage in
            XCTAssertNotNil(patchedMessage.ID)
            XCTAssertNotNil(patchedMessage.conversationID)
            XCTAssertNotNil(patchedMessage.sentTimestamp)
            XCTAssertNotNil(patchedMessage.patchedTimestamp)
            XCTAssertNotNil(patchedMessage.patchedDate)
            XCTAssertEqual(patchedMessage.ID, originMessage.ID)
            XCTAssertEqual(patchedMessage.conversationID, originMessage.conversationID)
            XCTAssertEqual(patchedMessage.sentTimestamp, originMessage.sentTimestamp)
            XCTAssertEqual(originMessage.content?.string, oldContent)
            XCTAssertTrue(patchedMessage is IMRecalledMessage)
        }
        
        let exp = expectation(description: "message patch")
        exp.expectedFulfillmentCount = 2
        do {
            try receivingTuple?.conversation.recall(message: oldMessage, completion: { (_) in })
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        receivingTuple?.delegator.messageEvent = { client, conv, event in
            switch event {
            case .updated(updatedMessage: let recalledMessage):
                XCTAssertTrue(conv.lastMessage === recalledMessage)
                recalledMessageChecker(recalledMessage, oldMessage)
                exp.fulfill()
            default:
                break
            }
        }
        try? sendingTuple?.conversation.recall(message: oldMessage, completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            if let recalledMessage = result.value {
                XCTAssertTrue(sendingTuple?.conversation.lastMessage === recalledMessage)
                recalledMessageChecker(recalledMessage, oldMessage)
            } else {
                XCTFail()
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: timeout)
    }

}

extension IMMessageTestCase {
    
    typealias Tuple = (client: IMClient, conversation: IMConversation, delegator: IMClientTestCase.Delegator)
    
    class CustomMessage: IMCategorizedMessage {
        override var type: Int {
            return 1
        }
    }
    
    class InvalidCustomMessage: IMCategorizedMessage {
        override var type: Int {
            return -1
        }
    }
    
    func newOpenedClient(
        clientID: String? = nil,
        options: IMClient.Options = .default,
        customRTMURL: URL? = nil)
        -> IMClient?
    {
        var client: IMClient? = try? IMClient(ID: clientID ?? uuid, options:options, customServer: customRTMURL)
        let exp = expectation(description: "open")
        client?.open { (result) in
            if result.isFailure { client = nil }
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
        return client
    }
    
    func createConversation(client: IMClient, clientIDs: Set<String>) -> IMConversation? {
        var conversation: IMConversation? = nil
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
        clientOptions: IMClient.Options = .default)
        -> [Tuple]?
    {
        var tuples: [Tuple] = []
        let exp = expectation(description: "get conversations")
        exp.expectedFulfillmentCount = clientCount
        var clientMap: [String: IMClient] = [:]
        var delegatorMap: [String: IMClientTestCase.Delegator] = [:]
        var conversationMap: [String: IMConversation] = [:]
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
            let client: IMClient = clientMap[clientID] {
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
    
    func sendingAndReceiving<T: IMCategorizedMessage>(
        sentMessage: T,
        receivedMessageChecker: ((T?) -> Void)? = nil)
        -> Bool
    {
        var sendingTuple: Tuple? = nil
        var receivingTuple: Tuple? = nil
        return sendingAndReceiving(
            sentMessage: sentMessage,
            sendingTuple: &sendingTuple,
            receivingTuple: &receivingTuple,
            receivedMessageChecker: receivedMessageChecker
        )
    }
    
    func sendingAndReceiving<T: IMMessage>(
        sentMessage: T,
        sendingTuple: inout Tuple?,
        receivingTuple: inout Tuple?,
        receivedMessageChecker: ((T?) -> Void)? = nil)
        -> Bool
    {
        guard
            let tuples = convenienceInit(),
            let tuple1 = tuples.first,
            let tuple2 = tuples.last
            else
        {
            XCTFail()
            return false
        }
        sendingTuple = tuple1
        receivingTuple = tuple2
        var flag: Int = 0
        var receivedMessage: T? = nil
        let exp = expectation(description: "message send and receive")
        exp.expectedFulfillmentCount = 2
        tuple2.delegator.messageEvent = { _, _, event in
            switch event {
            case .received(message: let message):
                if let msg: T = message as? T {
                    receivedMessage = msg
                    flag += 1
                } else {
                    XCTFail()
                }
                exp.fulfill()
            default:
                break
            }
        }
        try? tuple1.conversation.send(message: sentMessage, completion: { (result) in
            if result.isSuccess {
                flag += 1
            } else {
                XCTFail()
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: timeout)
        XCTAssertNotNil(sentMessage.ID)
        XCTAssertNotNil(sentMessage.conversationID)
        XCTAssertNotNil(sentMessage.sentTimestamp)
        XCTAssertEqual(sentMessage.ID, receivedMessage?.ID)
        XCTAssertEqual(sentMessage.conversationID, receivedMessage?.conversationID)
        XCTAssertEqual(sentMessage.sentTimestamp, receivedMessage?.sentTimestamp)
        receivedMessageChecker?(receivedMessage)
        return (flag == 2)
    }
    
}
