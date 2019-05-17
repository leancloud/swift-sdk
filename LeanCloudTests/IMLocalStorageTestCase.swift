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
        let clientID = uuid
        var client: IMClient? = try! IMClient(ID: clientID)
        
        XCTAssertNotNil(client!.localStorage)
        
        let dbURL: URL = try! client!.application.localStorageContext!.fileURL(place: .persistentData, module: .IM(clientID: clientID), file: .database)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path))
        
        weak var weakRef = client!.localStorage
        client = nil
        
        delay()
        
        XCTAssertNil(weakRef)
    }
    
    func testOpen() {
        let client = try! IMClient(ID: uuid)
        
        expecting { (exp) in
            client.localStorage?.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
    }
    
    func testInsertOrReplaceConversationRawData() {
        let client = try! IMClient(ID: uuid)
        
        expecting { (exp) in
            client.localStorage?.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            let rawData: IMConversation.RawData = [
                IMConversation.Key.createdAt.rawValue: LCDate().isoString,
                IMConversation.Key.updatedAt.rawValue: LCDate().isoString
            ]
            client.localStorage?.insertOrReplace(conversationID: uuid, rawData: rawData, convType: .normal, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            let rawData: IMConversation.RawData = [
                IMConversation.Key.createdAt.rawValue: LCDate().isoString,
                IMConversation.Key.updatedAt.rawValue: LCDate().isoString
            ]
            client.localStorage?.insertOrReplace(conversationID: uuid, rawData: rawData, convType: .system, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            let rawData: IMConversation.RawData = [
                IMConversation.Key.createdAt.rawValue: LCDate().isoString,
                IMConversation.Key.updatedAt.rawValue: LCDate().isoString
            ]
            client.localStorage?.insertOrReplace(conversationID: uuid, rawData: rawData, convType: .temporary, completion: { (result) in
                XCTAssertTrue(result.isFailure)
                XCTAssertNotNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            let rawData: IMConversation.RawData = [
                IMConversation.Key.createdAt.rawValue: LCDate().isoString,
                IMConversation.Key.updatedAt.rawValue: LCDate().isoString
            ]
            client.localStorage?.insertOrReplace(conversationID: uuid, rawData: rawData, convType: .transient, completion: { (result) in
                XCTAssertTrue(result.isFailure)
                XCTAssertNotNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.localStorage?.dbQueue.inDatabase({ (db) in
                let key = IMLocalStorage.Table.Conversation.CodingKeys.self
                let result = try! db.executeQuery("select * from \(IMLocalStorage.Table.conversation)", values: nil)
                var i = 0
                while result.next() {
                    i += 1
                    XCTAssertNotNil(result.string(forColumn: key.id.rawValue))
                    XCTAssertNotNil(result.data(forColumn: key.raw_data.rawValue))
                    XCTAssertTrue(result.longLongInt(forColumn: key.updated_timestamp.rawValue) > 0)
                    XCTAssertTrue(result.longLongInt(forColumn: key.created_timestamp.rawValue) > 0)
                    XCTAssertFalse(result.bool(forColumn: key.outdated.rawValue))
                }
                result.close()
                XCTAssertEqual(i, 2)
                exp.fulfill()
            })
        }
    }
    
    func testUpdateOrIgnoreConversationSets() {
        let client = try! IMClient(ID: uuid)
        
        expecting { (exp) in
            client.localStorage?.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        let conversationID = uuid
        let date1 = LCDate()
        let date1millisecond = Int64(date1.value.timeIntervalSince1970 * 1000.0)
        var rawData: IMConversation.RawData = [
            IMConversation.Key.createdAt.rawValue: date1.isoString,
            IMConversation.Key.updatedAt.rawValue: date1.isoString
        ]
        
        expecting { (exp) in
            client.localStorage?.insertOrReplace(conversationID: conversationID, rawData: rawData, convType: .normal, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        let date2 = LCDate()
        let date2millisecond = Int64(date2.value.timeIntervalSince1970 * 1000.0)
        rawData[IMConversation.Key.updatedAt.rawValue] = date2.isoString
        
        expecting { (exp) in
            let sets: [IMLocalStorage.Table.Conversation] = [
                .rawData(try! JSONSerialization.data(withJSONObject: rawData)),
                .updatedTimestamp(date2millisecond)
            ]
            client.localStorage?.updateOrIgnore(conversationID: conversationID, sets: sets, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.localStorage?.dbQueue.inDatabase({ (db) in
                let key = IMLocalStorage.Table.Conversation.CodingKeys.self
                let result = try! db.executeQuery("select * from \(IMLocalStorage.Table.conversation) where \(key.id.rawValue) = \"\(conversationID)\"", values: nil)
                while result.next() {
                    let updatedTimestamp: Int64 = result.longLongInt(forColumn: key.updated_timestamp.rawValue)
                    XCTAssertNotEqual(updatedTimestamp, date1millisecond)
                    XCTAssertEqual(updatedTimestamp, date2millisecond)
                }
                result.close()
                exp.fulfill()
            })
        }
    }
    
    func testInsertOrReplaceLastMessage() {
        let client = try! IMClient(ID: uuid)
        
        expecting { (exp) in
            client.localStorage?.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            let conversationID = uuid
            let date = Date()
            let dateMillisecond = Int64(date.timeIntervalSince1970 * 1000.0)
            let message = IMMessage.instance(
                application: client.application,
                isTransient: false,
                conversationID: conversationID,
                currentClientID: client.ID,
                fromClientID: uuid,
                timestamp: dateMillisecond,
                patchedTimestamp: nil,
                messageID: uuid,
                content: .string("test"),
                isAllMembersMentioned: nil,
                mentionedMembers: nil
            )
            client.localStorage?.insertOrReplace(conversationID: conversationID, lastMessage: message, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.localStorage?.dbQueue.inDatabase({ (db) in
                let result = try! db.executeQuery("select * from \(IMLocalStorage.Table.lastMessage)", values: nil)
                var i = 0
                while result.next() {
                    i += 1
                }
                result.close()
                XCTAssertEqual(i, 1)
                exp.fulfill()
            })
        }
    }
    
    func testSelectConversations() {
        let client = try! IMClient(ID: uuid)
        
        expecting { (exp) in
            client.localStorage?.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        var conversationIDSet: Set<String> = []
        
        for _ in 0...1 {
            let conversationID = uuid
            
            expecting { (exp) in
                let date = LCDate()
                let rawData: IMConversation.RawData = [
                    IMConversation.Key.createdAt.rawValue: date.isoString,
                    IMConversation.Key.updatedAt.rawValue: date.isoString
                ]
                client.localStorage?.insertOrReplace(conversationID: conversationID, rawData: rawData, convType: .normal, completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    exp.fulfill()
                })
            }
            
            expecting { (exp) in
                let date = Date()
                let dateMillisecond = Int64(date.timeIntervalSince1970 * 1000.0)
                let message = IMMessage.instance(
                    application: client.application,
                    isTransient: false,
                    conversationID: conversationID,
                    currentClientID: client.ID,
                    fromClientID: uuid,
                    timestamp: dateMillisecond,
                    patchedTimestamp: nil,
                    messageID: uuid,
                    content: .string("test"),
                    isAllMembersMentioned: nil,
                    mentionedMembers: nil
                )
                client.localStorage?.insertOrReplace(conversationID: conversationID, lastMessage: message, completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    exp.fulfill()
                })
            }
            
            conversationIDSet.insert(conversationID)
        }
        
        let expectingOrder: (IMClient.StoredConversationOrder) -> Void = { order in
            self.expecting { (exp) in
                client.localStorage?.selectConversations(order: order, completion: { (client, result) in
                    switch result {
                    case .success(value: let tuple):
                        var timestamp: Int64 = -1
                        var i = -1
                        for (index, conv) in tuple.conversations.enumerated() {
                            i = index
                            switch order {
                            case .createdTimestamp(descending: let descending):
                                if let date = conv.createdAt {
                                    let currentTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
                                    if timestamp >= 0 {
                                        if descending {
                                            XCTAssertTrue(timestamp >= currentTimestamp)
                                        } else {
                                            XCTAssertTrue(timestamp <= currentTimestamp)
                                        }
                                    }
                                    timestamp = currentTimestamp
                                } else {
                                    XCTFail()
                                }
                            case .updatedTimestamp(descending: let descending):
                                if let date = conv.updatedAt {
                                    let currentTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
                                    if timestamp >= 0 {
                                        if descending {
                                            XCTAssertTrue(timestamp >= currentTimestamp)
                                        } else {
                                            XCTAssertTrue(timestamp <= currentTimestamp)
                                        }
                                    }
                                    timestamp = currentTimestamp
                                } else {
                                    XCTFail()
                                }
                            case .lastMessageSentTimestamp(descending: let descending):
                                if let currentTimestamp = conv.lastMessage?.sentTimestamp {
                                    if timestamp >= 0 {
                                        if descending {
                                            XCTAssertTrue(timestamp >= currentTimestamp)
                                        } else {
                                            XCTAssertTrue(timestamp <= currentTimestamp)
                                        }
                                    }
                                    timestamp = currentTimestamp
                                } else {
                                    XCTFail()
                                }
                            }
                        }
                        XCTAssertTrue(i == 1)
                    case .failure(error: let error):
                        XCTFail("\(error)")
                    }
                    exp.fulfill()
                })
            }
        }
        
        expectingOrder(.createdTimestamp(descending: true))
        expectingOrder(.createdTimestamp(descending: false))
        expectingOrder(.updatedTimestamp(descending: true))
        expectingOrder(.updatedTimestamp(descending: false))
        expectingOrder(.lastMessageSentTimestamp(descending: true))
        expectingOrder(.lastMessageSentTimestamp(descending: false))
    }
    
    func testInsertOrReplaceMessages() {
        let client = try! IMClient(ID: uuid)
        
        expecting { (exp) in
            client.localStorage?.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.localStorage?.insertOrReplace(messages: [], completion: { (result) in
                XCTAssertTrue(result.isFailure)
                XCTAssertNotNil(result.error)
                exp.fulfill()
            })
        }
        
        let conversationID = uuid
        var messages: [IMMessage] = []
        
        for _ in 0...9 {
            let date = Date()
            let sentTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
            messages.append(IMMessage.instance(
                application: client.application,
                isTransient: false,
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
        
        expecting { (exp) in
            client.localStorage?.insertOrReplace(messages: messages, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.localStorage?.dbQueue.inDatabase({ (db) in
                let result = try! db.executeQuery("select * from \(IMLocalStorage.Table.message)", values: nil)
                var i = 0
                while result.next() {
                    i += 1
                }
                result.close()
                XCTAssertEqual(i, 10)
                exp.fulfill()
            })
        }
    }
    
    func testMessagesBreakpointMechanism() {
        let client = try! IMClient(ID: uuid)
        
        expecting { (exp) in
            client.localStorage?.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        let conversationID = uuid
        var messages: [IMMessage] = []
        
        for _ in 0...5 {
            let date = Date()
            let sentTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
            messages.append(IMMessage.instance(
                application: client.application,
                isTransient: false,
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
            self.expecting(closure: { (exp) in
                client.localStorage?.dbQueue.inDatabase({ (db) in
                    let key = IMLocalStorage.Table.Message.CodingKeys.breakpoint.rawValue
                    let result = try! db.executeQuery("select \(key) from \(IMLocalStorage.Table.message)", values: nil)
                    var i = 0
                    var breakpoint = false
                    while result.next() {
                        breakpoint = result.bool(forColumn: key)
                        if i == 0 {
                            XCTAssertTrue(breakpoint)
                        }
                        i += 1
                    }
                    XCTAssertTrue(breakpoint)
                    exp.fulfill()
                })
            })
        }
        
        expecting { (exp) in
            let subMessages = Array(messages[0...2])
            client.localStorage?.insertOrReplace(messages: subMessages, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertTrue(subMessages.first!.breakpoint)
                XCTAssertTrue(subMessages.last!.breakpoint)
                exp.fulfill()
            })
        }
        
        checkBreakpoint()
        resetMessagesBreakpoint()
        
        expecting { (exp) in
            let subMessages = Array(messages[2...4])
            client.localStorage?.insertOrReplace(messages: subMessages, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertFalse(subMessages.first!.breakpoint)
                XCTAssertTrue(subMessages.last!.breakpoint)
                exp.fulfill()
            })
        }
        
        checkBreakpoint()
        resetMessagesBreakpoint()
        
        expecting { (exp) in
            let subMessages = Array(messages[3...5])
            client.localStorage?.insertOrReplace(messages: subMessages, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertFalse(subMessages.first!.breakpoint)
                XCTAssertTrue(subMessages.last!.breakpoint)
                exp.fulfill()
            })
        }
        
        checkBreakpoint()
        resetMessagesBreakpoint()
        
        expecting { (exp) in
            client.localStorage?.insertOrReplace(messages: messages, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertTrue(messages.first!.breakpoint)
                XCTAssertTrue(messages.last!.breakpoint)
                exp.fulfill()
            })
        }
        
        checkBreakpoint()
    }
    
    func testUpdateOrIgnoreMessage() {
        let client = try! IMClient(ID: uuid)
        
        expecting { (exp) in
            client.localStorage?.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        let conversationID = uuid
        var messages: [IMMessage] = []
        
        for _ in 0...2 {
            let date = Date()
            let sentTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
            messages.append(IMMessage.instance(
                application: client.application,
                isTransient: false,
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
        
        expecting { (exp) in
            client.localStorage?.insertOrReplace(messages: messages, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            let patchMessage = messages.first!
            patchMessage.patchedTimestamp = Int64(Date().timeIntervalSince1970 * 1000.0)
            try! client.localStorage?.updateOrIgnore(message: patchMessage, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.localStorage?.dbQueue.inDatabase({ (db) in
                let message = messages.first!
                let key = IMLocalStorage.Table.Message.CodingKeys.self
                let result = try! db.executeQuery("select \(key.patchedTimestamp.rawValue) from \(IMLocalStorage.Table.message) where \(key.conversationID.rawValue) = \"\(conversationID)\" and \(key.sentTimestamp.rawValue) = \(message.sentTimestamp!) and \(key.messageID.rawValue) = \"\(message.ID!)\"", values: nil)
                if result.next() {
                    XCTAssertEqual(result.longLongInt(forColumn: key.patchedTimestamp.rawValue), message.patchedTimestamp!)
                } else {
                    XCTFail()
                }
                result.close()
                exp.fulfill()
            })
        }
    }
    
    func testSelectMessages() {
        let client = try! IMClient(ID: uuid)
        
        expecting { (exp) in
            client.localStorage?.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        let conversationID = uuid
        var messages: [IMMessage] = []
        
        for _ in 0...2 {
            let date = Date()
            let sentTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
            messages.append(IMMessage.instance(
                application: client.application,
                isTransient: false,
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
        
        expecting { (exp) in
            client.localStorage?.insertOrReplace(messages: messages, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.localStorage?.selectMessages(conversationID: conversationID, limit: 1, completion: { (_, result, hasBreakpoint) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.count, 1)
                for (_, item) in result.value!.enumerated() {
                    XCTAssertEqual(item.conversationID!, messages.last!.conversationID!)
                    XCTAssertEqual(item.sentTimestamp!, messages.last!.sentTimestamp!)
                    XCTAssertEqual(item.ID!, messages.last!.ID!)
                }
                XCTAssertTrue(hasBreakpoint)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.localStorage?.selectMessages(conversationID: conversationID, limit: 20, completion: { (_, result, hasBreakpoint) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.count, 3)
                XCTAssertTrue(hasBreakpoint)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            let startMessage = messages.last
            let start = IMConversation.MessageQueryEndpoint(
                messageID: startMessage?.ID,
                sentTimestamp: startMessage?.sentTimestamp,
                isClosed: true
            )
            client.localStorage?.selectMessages(conversationID: conversationID, start: start, end: nil, direction: .newToOld, limit: 20, completion: { (_, result, hasBreakpoint) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.count, 3)
                XCTAssertTrue(hasBreakpoint)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            let startMessage = messages.last
            let start = IMConversation.MessageQueryEndpoint(
                messageID: startMessage?.ID,
                sentTimestamp: startMessage?.sentTimestamp,
                isClosed: false
            )
            client.localStorage?.selectMessages(conversationID: conversationID, start: start, end: nil, direction: .newToOld, limit: 20, completion: { (_, result, hasBreakpoint) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.count, 2)
                for (index, item) in result.value!.enumerated() {
                    XCTAssertEqual(item.conversationID!, messages[index].conversationID!)
                    XCTAssertEqual(item.sentTimestamp!, messages[index].sentTimestamp!)
                    XCTAssertEqual(item.ID!, messages[index].ID!)
                }
                XCTAssertTrue(hasBreakpoint)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            let endMessage = messages.first
            let end = IMConversation.MessageQueryEndpoint(
                messageID: endMessage?.ID,
                sentTimestamp: endMessage?.sentTimestamp,
                isClosed: true
            )
            client.localStorage?.selectMessages(conversationID: conversationID, start: nil, end: end, direction: .newToOld, limit: 20, completion: { (_, result, hasBreakpoint) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.count, 3)
                XCTAssertTrue(hasBreakpoint)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            let endMessage = messages.first
            let end = IMConversation.MessageQueryEndpoint(
                messageID: endMessage?.ID,
                sentTimestamp: endMessage?.sentTimestamp,
                isClosed: false
            )
            client.localStorage?.selectMessages(conversationID: conversationID, start: nil, end: end, direction: .newToOld, limit: 20, completion: { (_, result, hasBreakpoint) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.count, 2)
                for (index, item) in result.value!.enumerated() {
                    XCTAssertEqual(item.conversationID!, messages[index + 1].conversationID!)
                    XCTAssertEqual(item.sentTimestamp!, messages[index + 1].sentTimestamp!)
                    XCTAssertEqual(item.ID!, messages[index + 1].ID!)
                }
                XCTAssertTrue(hasBreakpoint)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
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
            client.localStorage?.selectMessages(conversationID: conversationID, start: start, end: end, direction: nil, limit: 20, completion: { (_, result, hasBreakpoint) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.count, 3)
                XCTAssertTrue(hasBreakpoint)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
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
            client.localStorage?.selectMessages(conversationID: conversationID, start: start, end: end, direction: nil, limit: 20, completion: { (_, result, hasBreakpoint) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.count, 2)
                for (index, item) in result.value!.enumerated() {
                    XCTAssertEqual(item.conversationID!, messages[index].conversationID!)
                    XCTAssertEqual(item.sentTimestamp!, messages[index].sentTimestamp!)
                    XCTAssertEqual(item.ID!, messages[index].ID!)
                }
                XCTAssertTrue(hasBreakpoint)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
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
            client.localStorage?.selectMessages(conversationID: conversationID, start: start, end: end, direction: nil, limit: 20, completion: { (_, result, hasBreakpoint) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.count, 2)
                for (index, item) in result.value!.enumerated() {
                    XCTAssertEqual(item.conversationID!, messages[index + 1].conversationID!)
                    XCTAssertEqual(item.sentTimestamp!, messages[index + 1].sentTimestamp!)
                    XCTAssertEqual(item.ID!, messages[index + 1].ID!)
                }
                XCTAssertTrue(hasBreakpoint)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
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
            client.localStorage?.selectMessages(conversationID: conversationID, start: start, end: end, direction: nil, limit: 20, completion: { (_, result, hasBreakpoint) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.count, 1)
                for (index, item) in result.value!.enumerated() {
                    XCTAssertEqual(item.conversationID!, messages[index + 1].conversationID!)
                    XCTAssertEqual(item.sentTimestamp!, messages[index + 1].sentTimestamp!)
                    XCTAssertEqual(item.ID!, messages[index + 1].ID!)
                }
                XCTAssertFalse(hasBreakpoint)
                exp.fulfill()
            })
        }
    }
    
    func testDeleteConversationAndMessage() {
        let client = try! IMClient(ID: uuid)
        
        expecting { (exp) in
            client.localStorage?.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        let conversationID = uuid
        var messages: [IMMessage] = []
        
        for _ in 0...2 {
            let date = Date()
            let sentTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
            messages.append(IMMessage.instance(
                application: client.application,
                isTransient: false,
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
        
        expecting { (exp) in
            client.localStorage?.insertOrReplace(conversationID: conversationID, rawData: [:], convType: .normal, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.localStorage?.insertOrReplace(conversationID: conversationID, lastMessage: messages.last!, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.localStorage?.insertOrReplace(messages: messages, completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.localStorage?.deleteConversationAndMessages(IDs: [conversationID], completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.localStorage?.dbQueue.inDatabase({ (db) in
                let conversationResult = try! db.executeQuery("select * from \(IMLocalStorage.Table.conversation) where \(IMLocalStorage.Table.Conversation.CodingKeys.id.rawValue) = \"\(conversationID)\"", values: nil)
                XCTAssertFalse(conversationResult.next())
                conversationResult.close()
                
                let lastMessageResult = try! db.executeQuery("select * from \(IMLocalStorage.Table.lastMessage) where \(IMLocalStorage.Table.LastMessage.CodingKeys.conversation_id.rawValue) = \"\(conversationID)\"", values: nil)
                XCTAssertFalse(lastMessageResult.next())
                lastMessageResult.close()
                
                let messageResult = try! db.executeQuery("select * from \(IMLocalStorage.Table.message) where \(IMLocalStorage.Table.Message.CodingKeys.conversationID.rawValue) = \"\(conversationID)\"", values: nil)
                XCTAssertFalse(messageResult.next())
                messageResult.close()
                
                exp.fulfill()
            })
        }
    }

}
