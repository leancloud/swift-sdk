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
        
        let checkMessage: (IMConversation, IMMessage) -> Void = { conv, message in
            XCTAssertEqual(message.status, .sent)
            XCTAssertNotNil(message.ID)
            XCTAssertEqual(conv.ID, message.conversationID)
            XCTAssertEqual(conv.clientID, message.currentClientID)
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
            case .unreadMessageCountUpdated:
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
            case .unreadMessageCountUpdated:
                XCTAssertTrue([0,1].contains(conversation.unreadMessageCount))
                exp1.fulfill()
            default:
                break
            }
        }
        try? conversationA.send(message: stringMessage) { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
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
            case .unreadMessageCountUpdated:
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
            case .unreadMessageCountUpdated:
                XCTFail()
            default:
                break
            }
        }
        try? conversationB.send(message: dataMessage, completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
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
        var lastMessageIDSet: Set<String> = []
        
        let exp = expectation(description: "message continuous sending and receiving")
        let count = 5
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
            case .unreadMessageCountUpdated:
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
            case .unreadMessageCountUpdated:
                if receivedMessageCountB == 0,
                    conversation.unreadMessageCount == 0 {
                    exp.fulfill()
                }
            default:
                break
            }
        }
        for _ in 0..<count {
            let sendAExp = expectation(description: "send message")
            let messageA = IMMessage()
            try? messageA.set(content: .string("test"))
            try? conversationA.send(message: messageA, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                sendAExp.fulfill()
            })
            wait(for: [sendAExp], timeout: timeout)
            let sendBExp = expectation(description: "send message")
            let messageB = IMMessage()
            try? messageB.set(content: .string("test"))
            try? conversationB.send(message: messageB, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                sendBExp.fulfill()
            })
            wait(for: [sendBExp], timeout: timeout)
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
        guard
            let tuples = convenienceInit(),
            let tuple1 = tuples.first,
            let tuple2 = tuples.last
            else
        {
            XCTFail()
            return
        }
        
        let message = IMMessage()
        try? message.set(content: .string("test"))
        var messageID: String? = nil
        
        let sendExp = expectation(description: "send message")
        sendExp.expectedFulfillmentCount = 3
        tuple1.delegator.messageEvent = { client, conv, event in
            if conv.ID == tuple1.conversation.ID {
                switch event {
                case .delivered(toClientID: let clientID, messageID: let msgID, deliveredTimestamp: _):
                    XCTAssertEqual(clientID, tuple2.client.ID)
                    messageID = msgID
                    sendExp.fulfill()
                default:
                    break
                }
            }
        }
        tuple2.delegator.messageEvent = { client, conv, event in
            if conv.ID == tuple2.conversation.ID {
                switch event {
                case .received(message: _):
                    sendExp.fulfill()
                default:
                    break
                }
            }
        }
        try? tuple1.conversation.send(message: message, options: [.needReceipt]) { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            sendExp.fulfill()
        }
        wait(for: [sendExp], timeout: timeout)
        
        let readRcpExp = expectation(description: "get read rcp")
        tuple1.delegator.messageEvent = { client, conv, event in
            if conv.ID == tuple1.conversation.ID {
                switch event {
                case .read(byClientID: let clientID, messageID: let msgID, readTimestamp: _):
                    XCTAssertEqual(clientID, tuple2.client.ID)
                    XCTAssertEqual(msgID, messageID)
                    readRcpExp.fulfill()
                default:
                    break
                }
            }
        }
        tuple2.conversation.read()
        wait(for: [readRcpExp], timeout: timeout)
        
        XCTAssertEqual(messageID, message.ID)
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
        try? message.set(content: .string("test"))
        try? conversationA.send(message: message, options: [.isTransient]) { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(message.ioType, .out)
            checkMessage(message)
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
    }
    
    func testMessageAutoSendingWhenOfflineAndReceiving() {
        guard
            let tuples = convenienceInit(shouldConnectionShared: false),
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
        try? willMessage.set(content: .string("test"))
        try? conversationA.send(message: willMessage, options: [.isAutoDeliveringWhenOffline]) { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
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
    
    func testSendMessageToChatRoom() {
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
        
        var chatRoomA: IMChatRoom? = nil
        var chatRoomB: IMChatRoom? = nil
        
        let prepareExp = expectation(description: "create chat room")
        prepareExp.expectedFulfillmentCount = 3
        try? clientA.createChatRoom(completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            chatRoomA = result.value
            prepareExp.fulfill()
            if let ID = chatRoomA?.ID {
                try? clientB.conversationQuery.getConversation(by: ID, completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    chatRoomB = result.value as? IMChatRoom
                    prepareExp.fulfill()
                    try? chatRoomB?.join(completion: { (result) in
                        XCTAssertTrue(result.isSuccess)
                        XCTAssertNil(result.error)
                        prepareExp.fulfill()
                    })
                })
            }
        })
        wait(for: [prepareExp], timeout: timeout)
        
        let sendExp = expectation(description: "send message")
        sendExp.expectedFulfillmentCount = 12
        delegatorA.messageEvent = { client, conv, event in
            if conv === chatRoomA {
                switch event {
                case .received(message: let message):
                    XCTAssertEqual(message.content?.string, "test")
                    sendExp.fulfill()
                default:
                    break
                }
            }
        }
        delegatorB.messageEvent = { client, conv, event in
            if conv === chatRoomB {
                switch event {
                case .received(message: let message):
                    XCTAssertEqual(message.content?.string, "test")
                    sendExp.fulfill()
                default:
                    break
                }
            }
        }
        for messagePriority in
            [IMChatRoom.MessagePriority.high,
             IMChatRoom.MessagePriority.normal,
             IMChatRoom.MessagePriority.low]
        {
            let messageA = IMMessage()
            try? messageA.set(content: .string("test"))
            ((try? chatRoomA?.send(message: messageA, priority: messagePriority, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                sendExp.fulfill()
            })) as ()??)
            let messageB = IMMessage()
            try? messageB.set(content: .string("test"))
            ((try? chatRoomB?.send(message: messageB, priority: messagePriority, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                sendExp.fulfill()
            })) as ()??)
        }
        wait(for: [sendExp], timeout: timeout)
        
        XCTAssertNil(chatRoomA?.lastMessage)
        XCTAssertNil(chatRoomB?.lastMessage)
        XCTAssertTrue((chatRoomA?.members ?? []).isEmpty)
        XCTAssertTrue((chatRoomB?.members ?? []).isEmpty)
    }
    
    func testReceiveMessageFromServiceConversation() {
        guard
            let convID = IMConversationTestCase.newServiceConversation(),
            let client = newOpenedClient() else {
            XCTFail()
            return
        }
        
        delay(seconds: 5)
        
        let delegator = IMClientTestCase.Delegator()
        client.delegate = delegator
        var serviceConv: IMServiceConversation? = nil
        
        let subscribeExp = expectation(description: "subscribe service converastion")
        subscribeExp.expectedFulfillmentCount = 2
        try? client.conversationQuery.getConversation(by: convID) { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            serviceConv = result.value as? IMServiceConversation
            subscribeExp.fulfill()
            try? serviceConv?.subscribe(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                subscribeExp.fulfill()
            })
        }
        wait(for: [subscribeExp], timeout: timeout)
        
        let receiveExp = expectation(description: "receive message")
        delegator.messageEvent = { client, conv, event in
            if conv === serviceConv {
                switch event {
                case .received(message: let message):
                    XCTAssertEqual(message.content?.string, "test")
                    receiveExp.fulfill()
                    delegator.messageEvent = nil
                default:
                    break
                }
            }
        }
        XCTAssertNotNil(IMConversationTestCase.broadcastingMessage(to: convID, content: "test"))
        wait(for: [receiveExp], timeout: timeout)
        
        delay(seconds: 5)
        
        let unsubscribeExp = expectation(description: "unsubscribe service conversation")
        ((try? serviceConv?.unsubscribe(completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            unsubscribeExp.fulfill()
        })) as ()??)
        wait(for: [unsubscribeExp], timeout: timeout)
        
        let shouldNotReceiveExp = expectation(description: "should not receive message")
        shouldNotReceiveExp.isInverted = true
        delegator.messageEvent = { client, conv, event in
            if conv === serviceConv {
                switch event {
                case .received(message: let message):
                    XCTAssertEqual(message.content?.string, "test")
                    shouldNotReceiveExp.fulfill()
                default:
                    break
                }
            }
        }
        XCTAssertNotNil(IMConversationTestCase.broadcastingMessage(to: convID, content: "test"))
        wait(for: [shouldNotReceiveExp], timeout: 5)
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
            try (message as IMMessage).set(content: .string(""))
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
        var progress = 0.0
        let success = sendingAndReceiving(sentMessage: message, progress: { p in
            progress = p
        }) { (rMessage) in
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
        XCTAssertTrue(progress > 0.0)
    }
    
    func testVideoMessageSendingAndReceiving() {
        let message = IMVideoMessage()
        let format: String = "mp4"
        message.file = LCFile(payload: .fileURL(fileURL: resourceURL(name: "test", ext: format)))
        var progress = 0.0
        let success = sendingAndReceiving(sentMessage: message, progress: { p in
            progress = p
        }) { (rMessage) in
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
        XCTAssertTrue(progress > 0.0)
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
            try receivingTuple?.conversation.update(oldMessage: oldMessage, to: newMessage, completion: { (_) in })
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        receivingTuple?.delegator.messageEvent = { client, conv, event in
            switch event {
            case .updated(updatedMessage: let patchedMessage, reason: let reason):
                XCTAssertTrue(conv.lastMessage === patchedMessage)
                patchedMessageChecker(patchedMessage, oldMessage)
                XCTAssertNil(reason)
                exp.fulfill()
            default:
                break
            }
        }
        ((try? sendingTuple?.conversation.update(oldMessage: oldMessage, to: newMessage, completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertTrue(newMessage === sendingTuple?.conversation.lastMessage)
            patchedMessageChecker(newMessage, oldMessage)
            exp.fulfill()
        })) as ()??)
        wait(for: [exp], timeout: timeout)
        
        XCTAssertNotNil(receivingTuple?.client.localRecord.lastPatchTimestamp)
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
            case .updated(updatedMessage: let recalledMessage, reason: let reason):
                XCTAssertTrue(conv.lastMessage === recalledMessage)
                recalledMessageChecker(recalledMessage, oldMessage)
                XCTAssertNil(reason)
                exp.fulfill()
            default:
                break
            }
        }
        ((try? sendingTuple?.conversation.recall(message: oldMessage, completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            if let recalledMessage = result.value {
                XCTAssertTrue(sendingTuple?.conversation.lastMessage === recalledMessage)
                recalledMessageChecker(recalledMessage, oldMessage)
            } else {
                XCTFail()
            }
            exp.fulfill()
        })) as ()??)
        wait(for: [exp], timeout: timeout)
        
        XCTAssertNotNil(receivingTuple?.client.localRecord.lastPatchTimestamp)
    }
    
    func testMessagePatchNotification() {
        guard
            let tuples = convenienceInit(shouldConnectionShared: false),
            let sendingTuple = tuples.first,
            let receivingTuple = tuples.last
            else
        {
            XCTFail()
            return
        }
        
        let conversationA = sendingTuple.conversation
        
        let clientB = receivingTuple.client
        let delegatorB = receivingTuple.delegator
        
        var oldMessage = IMTextMessage()
        oldMessage.text = "old"
        
        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "send msg")
            exp.expectedFulfillmentCount = 2
            return exp
        }) { (exp) in
            delegatorB.messageEvent = { client, conversation, event in
                switch event {
                case .received:
                    exp.fulfill()
                default:
                    break
                }
            }
            try! conversationA.send(message: oldMessage, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        delegatorB.reset()
        
        delay()
        
        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "update msg")
            exp.expectedFulfillmentCount = 2
            return exp
        }) { (exp) in
            delegatorB.messageEvent = { client, conv, event in
                switch event {
                case .updated:
                    exp.fulfill()
                default:
                    break
                }
            }
            let newMessage = IMTextMessage()
            newMessage.text = "new"
            try! conversationA.update(oldMessage: oldMessage, to: newMessage, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        delegatorB.reset()
        
        delay()
        clientB.connection.disconnect()
        delay()
        
        for i in 0...1 {
            oldMessage = IMTextMessage()
            oldMessage.text = "old\(i)"
            expecting(description: "send msg") { (exp) in
                try! conversationA.send(message: oldMessage, completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    exp.fulfill()
                })
            }
            delay()
            expecting(description: "update msg") { (exp) in
                let newMessage = IMTextMessage()
                newMessage.text = "new\(i)"
                try! conversationA.update(oldMessage: oldMessage, to: newMessage, completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    exp.fulfill()
                })
            }
        }
        
        delay()
        
        expecting(expectation: { () -> XCTestExpectation in
            let exp = self.expectation(description: "receive offline patch")
            exp.expectedFulfillmentCount = 2
            return exp
        }) { (exp) in
            delegatorB.messageEvent = { client, conv, event in
                switch event {
                case .updated:
                    exp.fulfill()
                default:
                    break
                }
            }
            clientB.connection.connect()
        }
    }
    
    func testMessagePatchError() {
        guard
            let tuples = convenienceInit(clientCount: 3),
            let sendingTuple = tuples.first,
            let receivingTuple = tuples.last
            else
        {
            XCTFail()
            return
        }
        
        let exp = expectation(description: "patch error")
        exp.expectedFulfillmentCount = 3
        let invalidContent = "无码种子"
        receivingTuple.delegator.messageEvent = { client, conv, event in
            if receivingTuple.conversation === conv {
                switch event {
                case .received(message: let message):
                    XCTAssertNotNil(message.content?.string)
                    XCTAssertNotEqual(message.content?.string, invalidContent)
                    exp.fulfill()
                default:
                    break
                }
            }
        }
        sendingTuple.delegator.messageEvent = { client, conv, event in
            if sendingTuple.conversation === conv {
                switch event {
                case .updated(updatedMessage: let message, reason: let reason):
                    XCTAssertNotNil(message.content?.string)
                    XCTAssertNotEqual(message.content?.string, invalidContent)
                    XCTAssertNotNil(reason)
                    XCTAssertNotNil(reason?.code)
                    XCTAssertNotNil(reason?.reason)
                    exp.fulfill()
                default:
                    break
                }
            }
        }
        let contentInvalidMessage = IMMessage()
        try! contentInvalidMessage.set(content: .string(invalidContent))
        try? sendingTuple.conversation.send(message: contentInvalidMessage, completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            exp.fulfill()
        })
        wait(for: [exp], timeout: timeout)
    }
    
    func testGetMessageReceiptFlag() {
        let message = IMMessage()
        try? message.set(content: .string("text"))
        var sendingTuple: Tuple? = nil
        var receivingTuple: Tuple? = nil
        let success = sendingAndReceiving(
            sentMessage: message,
            sendingTuple: &sendingTuple,
            receivingTuple: &receivingTuple
        )
        XCTAssertTrue(success)
        
        delay()
        
        let readExp = expectation(description: "read message")
        receivingTuple?.delegator.conversationEvent = { client, conv, event in
            if conv === receivingTuple?.conversation,
                case .unreadMessageCountUpdated = event {
                XCTAssertEqual(conv.unreadMessageCount, 0)
                readExp.fulfill()
            }
        }
        receivingTuple?.conversation.read()
        wait(for: [readExp], timeout: timeout)
        
        delay()
        
        let getReadFlagExp = expectation(description: "get read flag timestamp")
        ((try? sendingTuple?.conversation.getMessageReceiptFlag(completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.value?.readFlagTimestamp)
            XCTAssertNotNil(result.value?.readFlagTimestamp)
            XCTAssertEqual(result.value?.readFlagTimestamp, result.value?.deliveredFlagTimestamp)
            XCTAssertEqual(result.value?.readFlagDate, result.value?.deliveredFlagDate)
            XCTAssertGreaterThan(result.value?.readFlagTimestamp ?? 0, message.sentTimestamp ?? 0)
            getReadFlagExp.fulfill()
        })) as ()??)
        wait(for: [getReadFlagExp], timeout: timeout)
        
        let sendNeedRCPMessageExp = expectation(description: "send need RCP message")
        sendNeedRCPMessageExp.expectedFulfillmentCount = 3
        sendingTuple?.delegator.messageEvent = { client, conv, event in
            if conv === sendingTuple?.conversation {
                switch event {
                case .delivered(toClientID: _, messageID: _, deliveredTimestamp: _):
                    sendNeedRCPMessageExp.fulfill()
                default:
                    break
                }
            }
        }
        receivingTuple?.delegator.conversationEvent = { client, conv, event in
            if conv === receivingTuple?.conversation {
                switch event {
                case .lastMessageUpdated:
                    sendNeedRCPMessageExp.fulfill()
                default:
                    break
                }
            }
        }
        let needRCPMessage = IMMessage()
        try? needRCPMessage.set(content: .string("test"))
        ((try? sendingTuple?.conversation.send(message: needRCPMessage, options: [.needReceipt], completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            sendNeedRCPMessageExp.fulfill()
        })) as ()??)
        wait(for: [sendNeedRCPMessageExp], timeout: timeout)
        
        delay()
        
        let getDeliveredFlagExp = expectation(description: "get delivered flag timestamp")
        ((try? sendingTuple?.conversation.getMessageReceiptFlag(completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.value?.deliveredFlagTimestamp)
            XCTAssertNotNil(result.value?.deliveredFlagDate)
            XCTAssertNotEqual(result.value?.deliveredFlagTimestamp, result.value?.readFlagTimestamp)
            XCTAssertNotEqual(result.value?.deliveredFlagDate, result.value?.readFlagDate)
            XCTAssertGreaterThanOrEqual(result.value?.deliveredFlagTimestamp ?? 0, needRCPMessage.sentTimestamp ?? 0)
            getDeliveredFlagExp.fulfill()
        })) as ()??)
        wait(for: [getDeliveredFlagExp], timeout: timeout)
        
        let client = try! IMClient(ID: uuid, options: [])
        let conversation = IMConversation(ID: uuid, rawData: [:], convType: .normal, client: client, caching: false)
        do {
            try conversation.getMessageReceiptFlag(completion: { (_) in })
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
    }
    
    func testMessageQuery() {
        do {
            try CustomMessage.register()
        } catch {
            XCTFail("\(error)")
        }
        guard
            let clientA = newOpenedClient(),
            let clientB = newOpenedClient(),
            let conversation = createConversation(client: clientA, clientIDs: [clientA.ID, clientB.ID])
            else
        {
            XCTFail()
            return
        }
        
        do {
            try conversation.queryMessage(limit: 101, completion: { (_) in })
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        
        var sentTuples: [(String, Int64)] = []
        for i in 0...8 {
            var message: IMMessage!
            switch i {
            case 0:
                message = IMMessage()
                try? message.set(content: .string("test"))
            case 1:
                message = IMMessage()
                try? message.set(content: .data("bin".data(using: .utf8)!))
            case 2:
                message = IMTextMessage()
                (message as! IMTextMessage).text = "text"
            case 3:
                message = IMImageMessage()
                (message as! IMImageMessage).file = LCFile(payload: .fileURL(fileURL: resourceURL(name: "test", ext: "jpg")))
            case 4:
                message = IMAudioMessage()
                (message as! IMAudioMessage).file = LCFile(payload: .fileURL(fileURL: resourceURL(name: "test", ext: "mp3")))
            case 5:
                message = IMVideoMessage()
                (message as! IMVideoMessage).file = LCFile(payload: .fileURL(fileURL: resourceURL(name: "test", ext: "mp4")))
            case 6:
                message = IMFileMessage()
                (message as! IMFileMessage).file = LCFile(payload: .fileURL(fileURL: resourceURL(name: "test", ext: "zip")))
            case 7:
                message = IMLocationMessage()
                (message as! IMLocationMessage).location = LCGeoPoint(latitude: 90.0, longitude: 180.0)
            case 8:
                message = CustomMessage()
                (message as! CustomMessage).text = "custom"
            default:
                XCTFail()
            }
            let exp = expectation(description: "send message")
            try? conversation.send(message: message, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                if let messageID = message.ID, let ts = message.sentTimestamp {
                    sentTuples.append((messageID, ts))
                }
                exp.fulfill()
            })
            wait(for: [exp], timeout: timeout)
        }
        XCTAssertEqual(sentTuples.count, 9)
        
        delay(seconds: 5)
        
        let defaultQueryExp = expectation(description: "default query")
        try? conversation.queryMessage(completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.count, sentTuples.count)
            for i in 0..<sentTuples.count {
                XCTAssertEqual(result.value?[i].ID, sentTuples[i].0)
                XCTAssertEqual(result.value?[i].sentTimestamp, sentTuples[i].1)
                if i == 1 {
                    if let data = result.value?[i].content?.data,
                        let content = String(data: data, encoding: .utf8) {
                        XCTAssertEqual(content, "bin")
                    } else {
                        XCTFail()
                    }
                }
            }
            defaultQueryExp.fulfill()
        })
        wait(for: [defaultQueryExp], timeout: timeout)
        
        let directionQueryExp = expectation(description: "direction query")
        directionQueryExp.expectedFulfillmentCount = 2
        try? conversation.queryMessage(direction: .newToOld, limit: 1, completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.count, 1)
            XCTAssertEqual(result.value?.first?.ID, sentTuples.last?.0)
            XCTAssertEqual(result.value?.first?.sentTimestamp, sentTuples.last?.1)
            directionQueryExp.fulfill()
        })
        try? conversation.queryMessage(direction: .oldToNew, limit: 1, completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.count, 1)
            XCTAssertEqual(result.value?.first?.ID, sentTuples.first?.0)
            XCTAssertEqual(result.value?.first?.sentTimestamp, sentTuples.first?.1)
            directionQueryExp.fulfill()
        })
        wait(for: [directionQueryExp], timeout: timeout)
        
        let endpointQueryExp = expectation(description: "endpoint query")
        endpointQueryExp.expectedFulfillmentCount = 2
        let endpointQueryTuple = sentTuples[sentTuples.count / 2]
        let endpointQueryStart1 = IMConversation.MessageQueryEndpoint(
            messageID: endpointQueryTuple.0,
            sentTimestamp: endpointQueryTuple.1,
            isClosed: true
        )
        try? conversation.queryMessage(start: endpointQueryStart1, direction: .newToOld, limit: 5, completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.count, 5)
            for i in 0..<5 {
                XCTAssertEqual(result.value?[i].ID, sentTuples[i].0)
                XCTAssertEqual(result.value?[i].sentTimestamp, sentTuples[i].1)
            }
            endpointQueryExp.fulfill()
        })
        let endpointQueryStart2 = IMConversation.MessageQueryEndpoint(
            messageID: endpointQueryTuple.0,
            sentTimestamp: endpointQueryTuple.1,
            isClosed: false
        )
        try? conversation.queryMessage(start: endpointQueryStart2, direction: .oldToNew, limit: 5, completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.count, 4)
            for i in 0..<4 {
                XCTAssertEqual(result.value?[i].ID, sentTuples[i + 5].0)
                XCTAssertEqual(result.value?[i].sentTimestamp, sentTuples[i + 5].1)
            }
            endpointQueryExp.fulfill()
        })
        wait(for: [endpointQueryExp], timeout: timeout)
        
        let intervalQueryExp = expectation(description: "interval query")
        let end = IMConversation.MessageQueryEndpoint(
            messageID: sentTuples.first?.0,
            sentTimestamp: sentTuples.first?.1,
            isClosed: true
        )
        let start = IMConversation.MessageQueryEndpoint(
            messageID: sentTuples.last?.0,
            sentTimestamp: sentTuples.last?.1,
            isClosed: true
        )
        try? conversation.queryMessage(start: start, end: end, limit: sentTuples.count, completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.count, sentTuples.count)
            for i in 0..<sentTuples.count {
                XCTAssertEqual(result.value?[i].ID, sentTuples[i].0)
                XCTAssertEqual(result.value?[i].sentTimestamp, sentTuples[i].1)
            }
            intervalQueryExp.fulfill()
        })
        wait(for: [intervalQueryExp], timeout: timeout)
        
        let typeQuery = expectation(description: "type query")
        try? conversation.queryMessage(type: IMTextMessage.messageType, completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.count, 1)
            XCTAssertEqual(
                (result.value?.first as? IMTextMessage)?[IMCategorizedMessage.ReservedKey.type.rawValue] as? Int,
                IMTextMessage.messageType
            )
            XCTAssertNotNil(result.value?.first?.deliveredTimestamp)
            XCTAssertNotNil(result.value?.first?.deliveredDate)
            XCTAssertEqual(result.value?.first?.status, .delivered)
            typeQuery.fulfill()
        })
        wait(for: [typeQuery], timeout: timeout)
        
        XCTAssertEqual(conversation.lastMessage?.ID, sentTuples.last?.0)
        XCTAssertEqual(conversation.lastMessage?.sentTimestamp, sentTuples.last?.1)
    }

}

extension IMMessageTestCase {
    
    typealias Tuple = (client: IMClient, conversation: IMConversation, delegator: IMClientTestCase.Delegator)
    
    class CustomMessage: IMCategorizedMessage {
        class override var messageType: MessageType {
            return 1
        }
    }
    
    class InvalidCustomMessage: IMCategorizedMessage {
        class override var messageType: MessageType {
            return -1
        }
    }
    
    func newOpenedClient(
        clientID: String? = nil,
        options: IMClient.Options = .default)
        -> IMClient?
    {
        var client: IMClient? = try? IMClient(ID: clientID ?? uuid, options:options)
        let exp = expectation(description: "open")
        client?.open { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            if result.isFailure { client = nil }
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
        return client
    }
    
    func createConversation(client: IMClient, clientIDs: Set<String>, isTemporary: Bool = false) -> IMConversation? {
        var conversation: IMConversation? = nil
        let exp = expectation(description: "create conversation")
        if isTemporary {
            try? client.createTemporaryConversation(clientIDs: clientIDs, timeToLive: 3600, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                conversation = result.value
                exp.fulfill()
            })
        } else {
            try? client.createConversation(clientIDs: clientIDs, isUnique: false, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                conversation = result.value
                exp.fulfill()
            })
        }
        wait(for: [exp], timeout: timeout)
        return conversation
    }
    
    func convenienceInit(clientCount: Int = 2, shouldConnectionShared: Bool = true) -> [Tuple]? {
        var tuples: [Tuple] = []
        let exp = expectation(description: "get conversations")
        exp.expectedFulfillmentCount = clientCount
        var clientMap: [String: IMClient] = [:]
        var delegatorMap: [String: IMClientTestCase.Delegator] = [:]
        var conversationMap: [String: IMConversation] = [:]
        var clientIDs: [String] = []
        for _ in 0..<clientCount {
            guard let client = newOpenedClient() else {
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
            if !shouldConnectionShared {
                RTMConnectionRefMap_protobuf1.removeAll()
                RTMConnectionRefMap_protobuf3.removeAll()
            }
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
        progress: ((Double) -> Void)? = nil,
        receivedMessageChecker: ((T?) -> Void)? = nil)
        -> Bool
    {
        var sendingTuple: Tuple? = nil
        var receivingTuple: Tuple? = nil
        return sendingAndReceiving(
            sentMessage: sentMessage,
            sendingTuple: &sendingTuple,
            receivingTuple: &receivingTuple,
            progress: progress,
            receivedMessageChecker: receivedMessageChecker
        )
    }
    
    func sendingAndReceiving<T: IMMessage>(
        sentMessage: T,
        sendingTuple: inout Tuple?,
        receivingTuple: inout Tuple?,
        progress: ((Double) -> Void)? = nil,
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
        try? tuple1.conversation.send(message: sentMessage, progress: progress, completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            if result.isSuccess {
                flag += 1
            } else {
                XCTFail()
            }
            exp.fulfill()
        })
        wait(for: [exp], timeout: timeout)
        tuple2.delegator.messageEvent = nil
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
