//
//  IMLocalStorageTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2019/4/30.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class IMLocalStorageTestCase: RTMBaseTestCase {
    
    func testInitAndDeinit() {
        var client: IMClient! = clientUsingLocalStorage()
        XCTAssertNotNil(client.localStorage)
        
        let dbURL: URL = try! client.application.localStorageContext!
            .fileURL(place: .persistentData, module: .IM(clientID: client.ID), file: .database)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path))
        
        weak var weakRef = client.localStorage
        client = nil
        delay()
        XCTAssertNil(weakRef)
    }
    
    func testInsertOrReplaceConversationRawData() {
        let client = clientUsingLocalStorage()
        prepare(client: client)
        
        let convTypes: [IMConversation.ConvType] = [.normal, .system, .transient, .temporary]
        
        for convType in convTypes {
            do {
                let rawData: IMConversation.RawData = [
                    IMConversation.Key.convType.rawValue: convType.rawValue,
                    IMConversation.Key.createdAt.rawValue: LCDate().isoString,
                    IMConversation.Key.updatedAt.rawValue: LCDate().isoString]
                try client.localStorage?.insertOrReplace(conversationID: uuid, rawData: rawData, convType: convType)
            } catch {
                XCTFail("\(error)")
            }
        }
        
        do {
            let result = try client.localStorage?.selectConversations(order: .createdTimestamp(descending: true), client: client)
            XCTAssertEqual(result?.conversations.count, 2)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testUpdateOrIgnoreConversationSets() {
        let client = clientUsingLocalStorage()
        prepare(client: client)

        let conversationID = uuid
        var rawData: IMConversation.RawData = [
            IMConversation.Key.createdAt.rawValue: LCDate().isoString,
            IMConversation.Key.updatedAt.rawValue: LCDate().isoString]
        
        do {
            try client.localStorage?.insertOrReplace(conversationID: conversationID, rawData: rawData, convType: .normal)
        } catch {
            XCTFail("\(error)")
        }

        do {
            let date = LCDate()
            rawData[IMConversation.Key.updatedAt.rawValue] = date.isoString
            let sets: [IMLocalStorage.Table.Conversation] = [
                .rawData(try! JSONSerialization.data(withJSONObject: rawData)),
                .updatedTimestamp(Int64(date.value.timeIntervalSince1970 * 1000.0))]
            try client.localStorage?.updateOrIgnore(conversationID: conversationID, sets: sets)
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let result = try client.localStorage?.selectConversations(order: .updatedTimestamp(descending: true), client: client)
            XCTAssertEqual(result?.conversations.count, 1)
            XCTAssertEqual(
                result?.conversations.first?[IMConversation.Key.updatedAt.rawValue] as? String,
                rawData[IMConversation.Key.updatedAt.rawValue] as? String)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testInsertOrReplaceLastMessage() {
        let client = clientUsingLocalStorage()
        prepare(client: client)
        
        let conversationID = uuid

        do {
            let rawData: IMConversation.RawData = [
                IMConversation.Key.createdAt.rawValue: LCDate().isoString,
                IMConversation.Key.updatedAt.rawValue: LCDate().isoString]
            try client.localStorage?.insertOrReplace(conversationID: conversationID, rawData: rawData, convType: .normal)
        } catch {
            XCTFail("\(error)")
        }
        
        let message = IMMessage.instance(
            application: client.application,
            conversationID: conversationID,
            currentClientID: client.ID,
            fromClientID: uuid,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000.0),
            patchedTimestamp: nil,
            messageID: uuid,
            content: .string("test"))
        
        do {
            try client.localStorage?.insertOrReplace(conversationID: conversationID, lastMessage: message)
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let result = try client.localStorage?.selectConversations(order: .lastMessageSentTimestamp(descending: true), client: client)
            XCTAssertEqual(result?.conversations.count, 1)
            XCTAssertNotNil(result?.conversations.first?.lastMessage)
            XCTAssertEqual(result?.conversations.first?.lastMessage?.conversationID, message.conversationID)
            XCTAssertEqual(result?.conversations.first?.lastMessage?.sentTimestamp, message.sentTimestamp)
            XCTAssertEqual(result?.conversations.first?.lastMessage?.ID, message.ID)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testSelectConversations() {
        let client = clientUsingLocalStorage()
        prepare(client: client)
        
        var conversationIDSequence: [String] = []
        
        for _ in 0...1 {
            let conversationID = uuid
            
            do {
                let rawData: IMConversation.RawData = [
                    IMConversation.Key.createdAt.rawValue: LCDate().isoString,
                    IMConversation.Key.updatedAt.rawValue: LCDate().isoString]
                try client.localStorage?.insertOrReplace(conversationID: conversationID, rawData: rawData, convType: .normal)
            } catch {
                XCTFail("\(error)")
            }
            
            let message = IMMessage.instance(
                application: client.application,
                conversationID: conversationID,
                currentClientID: client.ID,
                fromClientID: uuid,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000.0),
                patchedTimestamp: nil,
                messageID: uuid,
                content: .string("test"))
            
            do {
                try client.localStorage?.insertOrReplace(conversationID: conversationID, lastMessage: message)
            } catch {
                XCTFail("\(error)")
            }
            
            conversationIDSequence.append(conversationID)
        }
        
        let orders: [IMClient.StoredConversationOrder] = [
            .lastMessageSentTimestamp(descending: true),
            .lastMessageSentTimestamp(descending: false),
            .createdTimestamp(descending: true),
            .createdTimestamp(descending: false),
            .updatedTimestamp(descending: true),
            .updatedTimestamp(descending: false)]
        for order in orders {
            do {
                let result = try client.localStorage?.selectConversations(order: order, client: client)
                XCTAssertEqual(result?.conversations.count, 2)
                if order.value {
                    XCTAssertEqual(conversationIDSequence.first, result?.conversations.last?.ID)
                    XCTAssertEqual(conversationIDSequence.last, result?.conversations.first?.ID)
                } else {
                    XCTAssertEqual(conversationIDSequence.first, result?.conversations.first?.ID)
                    XCTAssertEqual(conversationIDSequence.last, result?.conversations.last?.ID)
                }
            } catch {
                XCTFail("\(error)")
            }
        }
    }
    
    func testInsertOrReplaceMessages() {
        let client = clientUsingLocalStorage()
        prepare(client: client)
        
        let conversationID = uuid
        var messages: [IMMessage] = []
        
        do {
            for _ in 0...9 {
                let date = Date()
                let sentTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
                messages.append(IMMessage.instance(
                    application: client.application,
                    conversationID: conversationID,
                    currentClientID: client.ID,
                    fromClientID: uuid,
                    timestamp: sentTimestamp,
                    patchedTimestamp: sentTimestamp,
                    messageID: uuid,
                    content: .string("test"),
                    isAllMembersMentioned: true,
                    mentionedMembers: [uuid])
                )
                delay(seconds: 0.1)
            }
            try client.localStorage?.insertOrReplace(messages: messages)
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: nil, end: nil, direction: nil, limit: messages.count)
            XCTAssertEqual(result?.messages.count, messages.count)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testMessagesBreakpoint() {
        let client = clientUsingLocalStorage()
        prepare(client: client)

        let conversationID = uuid
        var messages: [IMMessage] = []

        for _ in 0...5 {
            let date = Date()
            let sentTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
            messages.append(IMMessage.instance(
                application: client.application,
                conversationID: conversationID,
                currentClientID: client.ID,
                fromClientID: uuid,
                timestamp: sentTimestamp,
                patchedTimestamp: sentTimestamp,
                messageID: uuid,
                content: .string("test"),
                isAllMembersMentioned: true,
                mentionedMembers: [uuid])
            )
            delay(seconds: 0.1)
        }

        let resetMessagesBreakpoint: () -> Void = {
            for msg in messages {
                msg.breakpoint = false
            }
        }

        let checkBreakpoint: () -> Void = {
            do {
                let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: nil, end: nil, direction: nil, limit: 100)
                var messages = result?.messages ?? []
                XCTAssertEqual(messages.first?.breakpoint, true)
                XCTAssertEqual(messages.last?.breakpoint, true)
                messages.removeFirst()
                messages.removeLast()
                for item in messages {
                    XCTAssertEqual(item.breakpoint, false)
                }
            } catch {
                XCTFail("\(error)")
            }
        }
        
        do {
            let subMessages = Array(messages[0...2])
            try client.localStorage?.insertOrReplace(messages: subMessages)
            checkBreakpoint()
        } catch {
            XCTFail("\(error)")
        }
        
        resetMessagesBreakpoint()
        
        do {
            let subMessages = Array(messages[2...4])
            try client.localStorage?.insertOrReplace(messages: subMessages)
            checkBreakpoint()
        } catch {
            XCTFail("\(error)")
        }
        
        resetMessagesBreakpoint()
        
        do {
            let subMessages = Array(messages[3...5])
            try client.localStorage?.insertOrReplace(messages: subMessages)
            checkBreakpoint()
        } catch {
            XCTFail("\(error)")
        }
        
        resetMessagesBreakpoint()
        
        do {
            try client.localStorage?.insertOrReplace(messages: messages)
            checkBreakpoint()
        } catch {
            XCTFail("\(error)")
        }
    }

    func testUpdateOrIgnoreMessage() {
        let client = clientUsingLocalStorage()
        prepare(client: client)

        let conversationID = uuid
        var messages: [IMMessage] = []

        do {
            for _ in 0...2 {
                let date = Date()
                let sentTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
                messages.append(IMMessage.instance(
                    application: client.application,
                    conversationID: conversationID,
                    currentClientID: client.ID,
                    fromClientID: uuid,
                    timestamp: sentTimestamp,
                    patchedTimestamp: sentTimestamp,
                    messageID: uuid,
                    content: .string("test"),
                    isAllMembersMentioned: true,
                    mentionedMembers: [uuid])
                )
                delay(seconds: 0.1)
            }
            try client.localStorage?.insertOrReplace(messages: messages)
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let patchMessage = messages.first!
            patchMessage.patchedTimestamp = Int64(Date().timeIntervalSince1970 * 1000.0)
            try client.localStorage?.updateOrIgnore(message: patchMessage)
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: nil, end: nil, direction: nil, limit: 10)
            XCTAssertNotEqual(result?.messages.first?.sentTimestamp, result?.messages.first?.patchedTimestamp)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testSelectMessages() {
        let client = clientUsingLocalStorage()
        prepare(client: client)

        let conversationID = uuid
        var messages: [IMMessage] = []

        do {
            for _ in 0...2 {
                let date = Date()
                let sentTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
                messages.append(IMMessage.instance(
                    application: client.application,
                    conversationID: conversationID,
                    currentClientID: client.ID,
                    fromClientID: uuid,
                    timestamp: sentTimestamp,
                    patchedTimestamp: sentTimestamp,
                    messageID: uuid,
                    content: .string("test"),
                    isAllMembersMentioned: true,
                    mentionedMembers: [uuid])
                )
                delay(seconds: 0.1)
            }
            try client.localStorage?.insertOrReplace(messages: messages)
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: nil, end: nil, direction: nil, limit: 1)
            XCTAssertEqual(result?.messages.count, 1)
            XCTAssertEqual(result?.messages.first?.conversationID, messages.last?.conversationID)
            XCTAssertEqual(result?.messages.first?.sentTimestamp, messages.last?.sentTimestamp)
            XCTAssertEqual(result?.messages.first?.ID, messages.last?.ID)
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: nil, end: nil, direction: nil, limit: 10)
            XCTAssertEqual(result?.messages.count, messages.count)
            for (index, message) in (result?.messages ?? []).enumerated() {
                XCTAssertEqual(message.conversationID, messages[index].conversationID)
                XCTAssertEqual(message.sentTimestamp, messages[index].sentTimestamp)
                XCTAssertEqual(message.ID, messages[index].ID)
            }
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let startMessage = messages.last
            let start = IMConversation.MessageQueryEndpoint(
                messageID: startMessage?.ID,
                sentTimestamp: startMessage?.sentTimestamp,
                isClosed: true
            )
            let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: start, end: nil, direction: .newToOld, limit: 10)
            XCTAssertEqual(result?.messages.count, messages.count)
            for (index, message) in (result?.messages ?? []).enumerated() {
                XCTAssertEqual(message.conversationID, messages[index].conversationID)
                XCTAssertEqual(message.sentTimestamp, messages[index].sentTimestamp)
                XCTAssertEqual(message.ID, messages[index].ID)
            }
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let startMessage = messages.last
            let start = IMConversation.MessageQueryEndpoint(
                messageID: startMessage?.ID,
                sentTimestamp: startMessage?.sentTimestamp,
                isClosed: false
            )
            let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: start, end: nil, direction: .newToOld, limit: 10)
            XCTAssertEqual(result?.messages.count, messages.count - 1)
            for (index, message) in (result?.messages ?? []).enumerated() {
                XCTAssertEqual(message.conversationID, messages[index].conversationID)
                XCTAssertEqual(message.sentTimestamp, messages[index].sentTimestamp)
                XCTAssertEqual(message.ID, messages[index].ID)
            }
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let endMessage = messages.first
            let end = IMConversation.MessageQueryEndpoint(
                messageID: endMessage?.ID,
                sentTimestamp: endMessage?.sentTimestamp,
                isClosed: true
            )
            let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: nil, end: end, direction: .newToOld, limit: 10)
            XCTAssertEqual(result?.messages.count, messages.count)
            for (index, message) in (result?.messages ?? []).enumerated() {
                XCTAssertEqual(message.conversationID, messages[index].conversationID)
                XCTAssertEqual(message.sentTimestamp, messages[index].sentTimestamp)
                XCTAssertEqual(message.ID, messages[index].ID)
            }
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let endMessage = messages.first
            let end = IMConversation.MessageQueryEndpoint(
                messageID: endMessage?.ID,
                sentTimestamp: endMessage?.sentTimestamp,
                isClosed: false
            )
            let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: nil, end: end, direction: .newToOld, limit: 10)
            XCTAssertEqual(result?.messages.count, messages.count - 1)
            for (index, message) in (result?.messages ?? []).enumerated() {
                XCTAssertEqual(message.conversationID, messages[index + 1].conversationID)
                XCTAssertEqual(message.sentTimestamp, messages[index + 1].sentTimestamp)
                XCTAssertEqual(message.ID, messages[index + 1].ID)
            }
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let startMessage = messages.last
            let start = IMConversation.MessageQueryEndpoint(
                messageID: startMessage?.ID,
                sentTimestamp: startMessage?.sentTimestamp,
                isClosed: true
            )
            let endMessage = messages.first
            let end = IMConversation.MessageQueryEndpoint(
                messageID: endMessage?.ID,
                sentTimestamp: endMessage?.sentTimestamp,
                isClosed: true
            )
            let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: start, end: end, direction: nil, limit: 10)
            XCTAssertEqual(result?.messages.count, messages.count)
            for (index, message) in (result?.messages ?? []).enumerated() {
                XCTAssertEqual(message.conversationID, messages[index].conversationID)
                XCTAssertEqual(message.sentTimestamp, messages[index].sentTimestamp)
                XCTAssertEqual(message.ID, messages[index].ID)
            }
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let startMessage = messages.last
            let start = IMConversation.MessageQueryEndpoint(
                messageID: startMessage?.ID,
                sentTimestamp: startMessage?.sentTimestamp,
                isClosed: false
            )
            let endMessage = messages.first
            let end = IMConversation.MessageQueryEndpoint(
                messageID: endMessage?.ID,
                sentTimestamp: endMessage?.sentTimestamp,
                isClosed: true
            )
            let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: start, end: end, direction: nil, limit: 10)
            XCTAssertEqual(result?.messages.count, messages.count - 1)
            for (index, message) in (result?.messages ?? []).enumerated() {
                XCTAssertEqual(message.conversationID, messages[index].conversationID)
                XCTAssertEqual(message.sentTimestamp, messages[index].sentTimestamp)
                XCTAssertEqual(message.ID, messages[index].ID)
            }
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let startMessage = messages.last
            let start = IMConversation.MessageQueryEndpoint(
                messageID: startMessage?.ID,
                sentTimestamp: startMessage?.sentTimestamp,
                isClosed: true
            )
            let endMessage = messages.first
            let end = IMConversation.MessageQueryEndpoint(
                messageID: endMessage?.ID,
                sentTimestamp: endMessage?.sentTimestamp,
                isClosed: false
            )
            let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: start, end: end, direction: nil, limit: 10)
            XCTAssertEqual(result?.messages.count, messages.count - 1)
            for (index, message) in (result?.messages ?? []).enumerated() {
                XCTAssertEqual(message.conversationID, messages[index + 1].conversationID)
                XCTAssertEqual(message.sentTimestamp, messages[index + 1].sentTimestamp)
                XCTAssertEqual(message.ID, messages[index + 1].ID)
            }
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let startMessage = messages.last
            let start = IMConversation.MessageQueryEndpoint(
                messageID: startMessage?.ID,
                sentTimestamp: startMessage?.sentTimestamp,
                isClosed: false
            )
            let endMessage = messages.first
            let end = IMConversation.MessageQueryEndpoint(
                messageID: endMessage?.ID,
                sentTimestamp: endMessage?.sentTimestamp,
                isClosed: false
            )
            let result = try client.localStorage?.selectMessages(client: client, conversationID: conversationID, start: start, end: end, direction: nil, limit: 10)
            XCTAssertEqual(result?.messages.count, messages.count - 2)
            for (index, message) in (result?.messages ?? []).enumerated() {
                XCTAssertEqual(message.conversationID, messages[index + 1].conversationID)
                XCTAssertEqual(message.sentTimestamp, messages[index + 1].sentTimestamp)
                XCTAssertEqual(message.ID, messages[index + 1].ID)
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func testDeleteConversationAndMessage() {
        let client = clientUsingLocalStorage()
        prepare(client: client)

        let conversationID = uuid
        var messages: [IMMessage] = []

        for _ in 0...2 {
            let date = Date()
            let sentTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
            messages.append(IMMessage.instance(
                application: client.application,
                conversationID: conversationID,
                currentClientID: client.ID,
                fromClientID: uuid,
                timestamp: sentTimestamp,
                patchedTimestamp: sentTimestamp,
                messageID: uuid,
                content: .string("test"),
                isAllMembersMentioned: true,
                mentionedMembers: [uuid])
            )
            delay(seconds: 0.1)
        }
        
        do {
            try client.localStorage?.insertOrReplace(conversationID: conversationID, rawData: [:], convType: .normal)
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            try client.localStorage?.insertOrReplace(conversationID: conversationID, lastMessage: messages.last!)
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            try client.localStorage?.insertOrReplace(messages: messages)
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            try client.localStorage?.deleteConversationAndMessages(IDs: [conversationID])
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let conversations = (try client.localStorage?
                .selectConversations(order: .lastMessageSentTimestamp(descending: true), client: client))?
                .conversations
            XCTAssertEqual(conversations?.isEmpty, true)
            let messages = (try client.localStorage?
                .selectMessages(client: client, conversationID: conversationID, start: nil, end: nil, direction: nil, limit: 10))?
                .messages
            XCTAssertEqual(messages?.isEmpty, true)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testCompletionThread() {
        let client = clientUsingLocalStorage()
        prepare(client: client)
        
        expecting { (exp) in
            try! client.deleteStoredConversationAndMessages(IDs: [], completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        do {
            let rawData: IMConversation.RawData = [
                IMConversation.Key.createdAt.rawValue: LCDate().isoString,
                IMConversation.Key.updatedAt.rawValue: LCDate().isoString]
            try client.localStorage?.insertOrReplace(conversationID: uuid, rawData: rawData, convType: .normal)
        } catch {
            XCTFail("\(error)")
        }
        
        expecting { (exp) in
            try! client.getAndLoadStoredConversations(completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            try! client.convCollection.values.first?.queryMessage(policy: .onlyCache, completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
    }

}

extension IMLocalStorageTestCase {
    
    func clientUsingLocalStorage() -> IMClient {
        return try! IMClient(ID: uuid, options: [.usingLocalStorage])
    }
    
    func prepare(client: IMClient) {
        expecting { (exp) in
            try! client.prepareLocalStorage { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            }
        }
    }
    
}
