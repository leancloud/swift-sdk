//
//  IMLocalStorage.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2019/4/18.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import Foundation
import FMDB

class IMLocalStorage {
    
    enum Version: UInt32 {
        case v1 = 1
        
        static var current: Version {
            return .v1
        }
    }
    
    struct Table {
        
        static let conversation = "conversation"
        enum Conversation {
            case ID(String)
            case rawData(Data)
            case updatedTimestamp(Int64)
            case createdTimestamp(Int64)
            case outdated(Bool)
            
            enum CodingKeys: String {
                case id
                case raw_data
                case updated_timestamp
                case created_timestamp
                case outdated
            }
            
            var key: String {
                switch self {
                case .ID:
                    return CodingKeys.id.rawValue
                case .rawData:
                    return CodingKeys.raw_data.rawValue
                case .updatedTimestamp:
                    return CodingKeys.updated_timestamp.rawValue
                case .createdTimestamp:
                    return CodingKeys.created_timestamp.rawValue
                case .outdated:
                    return CodingKeys.outdated.rawValue
                }
            }
            
            var value: Any {
                switch self {
                case let .ID(v):
                    return v
                case let .rawData(v):
                    return v
                case let .updatedTimestamp(v):
                    return v
                case let .createdTimestamp(v):
                    return v
                case let .outdated(v):
                    return v
                }
            }
        }
        
        static let lastMessage = "last_message"
        enum LastMessage {
            case conversationID(String)
            case rawData(Data)
            case sentTimestamp(Int64)
            
            enum CodingKeys: String {
                case conversation_id
                case raw_data
                case sent_timestamp
            }
            
            var key: String {
                switch self {
                case .conversationID:
                    return CodingKeys.conversation_id.rawValue
                case .rawData:
                    return CodingKeys.raw_data.rawValue
                case .sentTimestamp:
                    return CodingKeys.sent_timestamp.rawValue
                }
            }
            
            var value: Any {
                switch self {
                case let .conversationID(v):
                    return v
                case let .rawData(v):
                    return v
                case let .sentTimestamp(v):
                    return v
                }
            }
        }
        
        static let message = "message"
        struct Message: Codable {
            let conversationID: String
            let sentTimestamp: Int64
            let messageID: String
            let fromPeerID: String?
            let content: String?
            let binary: Bool
            let deliveredTimestamp: Int64?
            let readTimestamp: Int64?
            let patchedTimestamp: Int64?
            let allMentioned: Bool?
            let mentionedList: String?
            let status: Int
            let breakpoint: Bool
            
            init(message: IMMessage) throws {
                guard
                    let conversationID = message.conversationID,
                    let sentTimestamp = message.sentTimestamp,
                    let messageID = message.ID,
                    message.underlyingStatus.rawValue >= IMMessage.Status.sent.rawValue
                    else
                {
                    throw LCError(
                        code: .inconsistency,
                        reason: "\((#file as NSString).lastPathComponent): message invalid."
                    )
                }
                self.conversationID = conversationID
                self.sentTimestamp = sentTimestamp
                self.messageID = messageID
                self.fromPeerID = message.fromClientID
                if let content = message.content {
                    switch content {
                    case .string(let str):
                        self.content = str
                        self.binary = false
                    case .data(let data):
                        self.content = String(data: data, encoding: .utf8) ?? ""
                        self.binary = true
                    }
                } else {
                    self.content = ""
                    self.binary = false
                }
                self.deliveredTimestamp = message.deliveredTimestamp
                self.readTimestamp = message.readTimestamp
                self.patchedTimestamp = message.patchedTimestamp
                self.allMentioned = message.isAllMembersMentioned
                if let members: [String] = message.mentionedMembers {
                    let data = try JSONSerialization.data(withJSONObject: members)
                    self.mentionedList = String(data: data, encoding: .utf8)
                } else {
                    self.mentionedList = nil
                }
                self.status = message.underlyingStatus.rawValue
                self.breakpoint = message.breakpoint
            }
            
            enum CodingKeys: String, CodingKey {
                case conversationID = "conversation_id"
                case sentTimestamp = "sent_timestamp"
                case messageID = "message_id"
                case fromPeerID = "from_peer_id"
                case content = "content"
                case binary = "binary"
                case deliveredTimestamp = "delivered_timestamp"
                case readTimestamp = "read_timestamp"
                case patchedTimestamp = "patched_timestamp"
                case allMentioned = "all_mentioned"
                case mentionedList = "mentioned_list"
                case status = "status"
                case breakpoint = "breakpoint"
            }
        }
    }
    
    let dbQueue: FMDatabaseQueue
    
    weak var client: IMClient?
    
    private(set) var isOpened: Bool = false
    
    init?(url: URL) {
        if let dbQueue = FMDatabaseQueue(url: url) {
            self.dbQueue = dbQueue
        } else {
            return nil
        }
    }
    
    init?(path: String) {
        if let dbQueue = FMDatabaseQueue(path: path) {
            self.dbQueue = dbQueue
        } else {
            return nil
        }
    }
    
    static func verboseLogging(database: FMDatabase, SQL: String, values: [Any]? = nil) {
        Logger.shared.verbose(closure: { () -> String in
            var info: String =
            """
            \n\n------ LeanCloud SQL Executing
            \(database) Cached Statements Count: \(database.cachedStatements?.count ?? 0)
            SQL:
            \(SQL)
            """
            if let values = values {
                info += "\n\nVALUES:\n\(values)"
            }
            info += "\n------ END\n"
            return info
        })
    }
    
    func open(completion: @escaping (LCBooleanResult) -> Void) {
        self.dbQueue.inDatabase { (db) in
            let callbackError = {
                let error = LCError(error: db.lastError())
                self.client?.serialQueue.async {
                    completion(.failure(error: error))
                }
            }
            
            guard db.open() else {
                callbackError()
                return
            }
            
            let convKey = Table.Conversation.CodingKeys.self
            let creatingConverstionTableSQL: String =
            """
            create table if not exists \(Table.conversation)
            (
            \(convKey.id.rawValue) text primary key,
            \(convKey.raw_data.rawValue) blob,
            \(convKey.updated_timestamp.rawValue) integer,
            \(convKey.created_timestamp.rawValue) integer,
            \(convKey.outdated.rawValue) integer
            );
            create index if not exists \(Table.conversation)_\(convKey.updated_timestamp.rawValue)
            on \(Table.conversation)(\(convKey.updated_timestamp.rawValue));
            create index if not exists \(Table.conversation)_\(convKey.created_timestamp.rawValue)
            on \(Table.conversation)(\(convKey.created_timestamp.rawValue));
            """
            IMLocalStorage.verboseLogging(database: db, SQL: creatingConverstionTableSQL)
            guard db.executeStatements( creatingConverstionTableSQL) else {
                callbackError()
                return
            }
            
            let creatingLastMessageTableSQL: String =
            """
            create table if not exists \(Table.lastMessage)
            (
            \(Table.LastMessage.CodingKeys.conversation_id.rawValue) text primary key,
            \(Table.LastMessage.CodingKeys.raw_data.rawValue) blob,
            \(Table.LastMessage.CodingKeys.sent_timestamp.rawValue) integer
            );
            create index if not exists \(Table.lastMessage)_\(Table.LastMessage.CodingKeys.sent_timestamp.rawValue)
            on \(Table.lastMessage)(\(Table.LastMessage.CodingKeys.sent_timestamp.rawValue));
            """
            IMLocalStorage.verboseLogging(database: db, SQL: creatingLastMessageTableSQL)
            guard db.executeStatements(creatingLastMessageTableSQL)
                else
            {
                callbackError()
                return
            }
            
            let msgKey = Table.Message.CodingKeys.self
            let creatingMessageTableSQL: String =
            """
            create table if not exists \(Table.message)
            (
            \(msgKey.conversationID.rawValue) text,
            \(msgKey.sentTimestamp.rawValue) integer,
            \(msgKey.messageID.rawValue) text,
            \(msgKey.fromPeerID.rawValue) text,
            \(msgKey.content.rawValue) blob,
            \(msgKey.binary.rawValue) integer,
            \(msgKey.deliveredTimestamp.rawValue) integer,
            \(msgKey.readTimestamp.rawValue) integer,
            \(msgKey.patchedTimestamp.rawValue) integer,
            \(msgKey.allMentioned.rawValue) integer,
            \(msgKey.mentionedList.rawValue) blob,
            \(msgKey.status.rawValue) integer,
            \(msgKey.breakpoint.rawValue) integer,
            primary key
            (
            \(msgKey.conversationID.rawValue),
            \(msgKey.sentTimestamp.rawValue),
            \(msgKey.messageID.rawValue)
            )
            );
            """
            IMLocalStorage.verboseLogging(database: db, SQL: creatingMessageTableSQL)
            guard db.executeStatements(creatingMessageTableSQL) else {
                callbackError()
                return
            }
            
            if db.userVersion < Version.current.rawValue {
                db.userVersion = Version.current.rawValue
            }
            db.shouldCacheStatements = true
            
            self.isOpened = true
            self.client?.serialQueue.async {
                completion(.success)
            }
        }
    }
    
    func insertOrReplace(
        conversationID: String,
        rawData: IMConversation.RawData,
        convType: IMConversation.ConvType,
        completion: ((LCBooleanResult) -> Void)? = nil)
    {
        guard convType != .temporary, convType != .transient else {
            self.client?.serialQueue.async {
                completion?(.failure(error: LCError(code: .inconsistency)))
            }
            return
        }
        self.dbQueue.inDatabase { (db) in
            guard self.isOpened else {
                self.client?.serialQueue.async {
                    completion?(.failure(error: LCError.localStorageNotOpen))
                }
                return
            }
            do {
                let jsonData: Data = try JSONSerialization.data(withJSONObject: rawData)
                let millisecondFromKey: (IMConversation.Key) -> Int64 = { key in
                    if let dateString: String = rawData[key.rawValue] as? String,
                        let date: Date = LCDate(isoString: dateString)?.value {
                        return Int64(date.timeIntervalSince1970 * 1000.0)
                    } else {
                        return 0
                    }
                }
                let sql: String =
                """
                insert or replace into \(Table.conversation)
                (
                \(Table.Conversation.CodingKeys.id.rawValue),
                \(Table.Conversation.CodingKeys.raw_data.rawValue),
                \(Table.Conversation.CodingKeys.updated_timestamp.rawValue),
                \(Table.Conversation.CodingKeys.created_timestamp.rawValue),
                \(Table.Conversation.CodingKeys.outdated.rawValue)
                )
                values(?,?,?,?,?)
                """
                let values: [Any] = [
                    conversationID,
                    jsonData,
                    millisecondFromKey(.updatedAt),
                    millisecondFromKey(.createdAt),
                    false
                ]
                IMLocalStorage.verboseLogging(database: db, SQL: sql, values: values)
                try db.executeUpdate(sql, values: values)
                self.client?.serialQueue.async {
                    completion?(.success)
                }
            } catch {
                Logger.shared.error(error)
                self.client?.serialQueue.async {
                    completion?(.failure(error: LCError(error: error)))
                }
            }
        }
    }
    
    func updateOrIgnore(
        conversationID: String,
        sets: [Table.Conversation],
        completion: ((LCBooleanResult) -> Void)? = nil)
    {
        guard !sets.isEmpty else {
            self.client?.serialQueue.async {
                completion?(.failure(error: LCError(code: .inconsistency)))
            }
            return
        }
        self.dbQueue.inDatabase { (db) in
            guard self.isOpened else {
                self.client?.serialQueue.async {
                    completion?(.failure(error: LCError.localStorageNotOpen))
                }
                return
            }
            do {
                var names: [String] = []
                var bindingSymbols: [String] = []
                var values: [Any] = []
                for item in sets {
                    assert(!names.contains(item.key))
                    names.append(item.key)
                    bindingSymbols.append("?")
                    values.append(item.value)
                }
                values.append(conversationID)
                let sql =
                """
                update or ignore \(Table.conversation)
                set (\(names.joined(separator: ","))) = (\(bindingSymbols.joined(separator: ",")))
                where \(Table.Conversation.CodingKeys.id.rawValue) = ?
                """
                IMLocalStorage.verboseLogging(database: db, SQL: sql, values: values)
                try db.executeUpdate(sql, values: values)
                self.client?.serialQueue.async {
                    completion?(.success)
                }
            } catch {
                Logger.shared.error(error)
                self.client?.serialQueue.async {
                    completion?(.failure(error: LCError(error: error)))
                }
            }
        }
    }
    
    private func handleStoredConversation(
        result: FMResultSet,
        client: IMClient,
        needSequence: Bool = false)
        -> ([IMConversation], [String: IMConversation])
    {
        let convKey = IMLocalStorage.Table.Conversation.CodingKeys.self
        var conversations: [IMConversation] = []
        var conversationMap: [String: IMConversation] = [:]
        while result.next() {
            guard
                let conversationID: String = result.string(forColumn: convKey.id.rawValue),
                let jsonData: Data = result.data(forColumn: convKey.raw_data.rawValue)
                else
            {
                continue
            }
            do {
                if let rawData = try JSONSerialization.jsonObject(with: jsonData) as? IMConversation.RawData {
                    let outdated: Bool = result.bool(forColumn: convKey.outdated.rawValue)
                    let conversation = IMConversation.instance(
                        ID: conversationID,
                        rawData: rawData,
                        client: client,
                        caching: false
                    )
                    conversation.isOutdated = outdated
                    if needSequence {
                        conversations.append(conversation)
                    }
                    conversationMap[conversationID] = conversation
                }
            } catch {
                Logger.shared.error(error)
            }
        }
        result.close()
        return (conversations, conversationMap)
    }
    
    @discardableResult
    private func handleStoredLastMessage(
        result: FMResultSet,
        client: IMClient,
        conversationMap: [String: IMConversation],
        needSequence: Bool = false)
        -> [IMConversation]
    {
        let lastMsgKey = IMLocalStorage.Table.LastMessage.CodingKeys.self
        var mutableConversationMap: [String: IMConversation] = conversationMap
        var conversations: [IMConversation] = []
        while result.next() {
            guard let data: Data = result.data(forColumn: lastMsgKey.raw_data.rawValue) else {
                continue
            }
            do {
                let table = try JSONDecoder().decode(IMLocalStorage.Table.Message.self, from: data)
                if let conversation = mutableConversationMap.removeValue(forKey: table.conversationID) {
                    var content: IMMessage.Content?
                    if let tableContent = table.content {
                        if table.binary, let data = tableContent.data(using: .utf8) {
                            content = .data(data)
                        } else {
                            content = .string(tableContent)
                        }
                    }
                    var mentionedMembers: [String]?
                    if let mentionedList = table.mentionedList, let data = mentionedList.data(using: .utf8) {
                        mentionedMembers = try JSONSerialization.jsonObject(with: data) as? [String]
                    }
                    let message = IMMessage.instance(
                        application: client.application,
                        isTransient: false,
                        conversationID: table.conversationID,
                        currentClientID: client.ID,
                        fromClientID: table.fromPeerID,
                        timestamp: table.sentTimestamp,
                        patchedTimestamp: table.patchedTimestamp,
                        messageID: table.messageID,
                        content: content,
                        isAllMembersMentioned: table.allMentioned,
                        mentionedMembers: mentionedMembers
                    )
                    message.deliveredTimestamp = table.deliveredTimestamp
                    message.readTimestamp = table.readTimestamp
                    conversation.safeUpdatingLastMessage(
                        newMessage: message,
                        client: client,
                        caching: false,
                        notifying: false
                    )
                    if needSequence {
                        conversations.append(conversation)
                    }
                }
            } catch {
                Logger.shared.error(error)
            }
        }
        result.close()
        if needSequence {
            return conversations + Array(mutableConversationMap.values)
        } else {
            return conversations
        }
    }
    
    func selectConversations(
        order: IMClient.StoredConversationOrder = .lastMessageSentTimestamp(descending: true),
        completion: @escaping (IMClient, LCGenericResult<(conversationMap: [String: IMConversation], conversations: [IMConversation])>) -> Void)
    {
        self.dbQueue.inDatabase { (db) in
            guard let client = self.client else {
                return
            }
            guard self.isOpened else {
                client.serialQueue.async {
                    completion(client, .failure(error: LCError.localStorageNotOpen))
                }
                return
            }
            var selectConversationSQL: String = "select * from \(Table.conversation)"
            var selectLastMessageSQL: String = "select * from \(Table.lastMessage)"
            do {
                switch order {
                case .createdTimestamp, .updatedTimestamp:
                    selectConversationSQL += " order by \(order.key) \(order.sqlOrder)"
                default:
                    break
                }
                IMLocalStorage.verboseLogging(database: db, SQL: selectConversationSQL)
                let conversationResult = try db.executeQuery(selectConversationSQL, values: nil)
                
                switch order {
                case .lastMessageSentTimestamp:
                    selectLastMessageSQL += " order by \(order.key) \(order.sqlOrder)"
                default:
                    break
                }
                IMLocalStorage.verboseLogging(database: db, SQL: selectLastMessageSQL)
                let lastMessageResult = try db.executeQuery(selectLastMessageSQL, values: nil)
                
                let conversations: [IMConversation]
                let conversationMap: [String: IMConversation]
                
                switch order {
                case .createdTimestamp, .updatedTimestamp:
                    let tuple = self.handleStoredConversation(
                        result: conversationResult,
                        client: client,
                        needSequence: true
                    )
                    conversations = tuple.0
                    conversationMap = tuple.1
                    self.handleStoredLastMessage(
                        result: lastMessageResult,
                        client: client,
                        conversationMap: conversationMap
                    )
                case .lastMessageSentTimestamp:
                    let tuple = self.handleStoredConversation(
                        result: conversationResult,
                        client: client
                    )
                    conversationMap = tuple.1
                    conversations = self.handleStoredLastMessage(
                        result: lastMessageResult,
                        client: client,
                        conversationMap: conversationMap,
                        needSequence: true
                    )
                }
                
                client.serialQueue.async {
                    completion(client, .success(value: (conversationMap, conversations)))
                }
            } catch {
                Logger.shared.error(error)
                client.serialQueue.async {
                    completion(client, .failure(error: LCError(underlyingError: error)))
                }
            }
            db.cachedStatements?.removeObjects(forKeys: [selectConversationSQL, selectLastMessageSQL])
        }
    }
    
    func deleteConversationAndMessages(
        IDs: Set<String>,
        completion: @escaping (LCBooleanResult) -> Void)
    {
        guard !IDs.isEmpty else {
            self.client?.serialQueue.async {
                completion(.failure(error: LCError(code: .inconsistency)))
            }
            return
        }
        self.dbQueue.inDatabase { (db) in
            guard self.isOpened else {
                self.client?.serialQueue.async {
                    completion(.failure(error: LCError.localStorageNotOpen))
                }
                return
            }
            var deleteConverationSQL: String = ""
            var deleteLastMessageSQL: String = ""
            var deleteMessageSQL: String = ""
            do {
                let joinedString = ("\"" + IDs.joined(separator: "\",\"") + "\"")
                
                deleteConverationSQL = "delete from \(Table.conversation) where \(Table.Conversation.CodingKeys.id.rawValue) in (\(joinedString))"
                IMLocalStorage.verboseLogging(database: db, SQL: deleteConverationSQL)
                try db.executeUpdate(deleteConverationSQL, values: nil)
                
                deleteLastMessageSQL = "delete from \(Table.lastMessage) where \(Table.LastMessage.CodingKeys.conversation_id.rawValue) in (\(joinedString))"
                IMLocalStorage.verboseLogging(database: db, SQL: deleteLastMessageSQL)
                try db.executeUpdate(deleteLastMessageSQL, values: nil)
                
                deleteMessageSQL = "delete from \(Table.message) where \(Table.Message.CodingKeys.conversationID.rawValue) in (\(joinedString))"
                IMLocalStorage.verboseLogging(database: db, SQL: deleteMessageSQL)
                try db.executeUpdate(deleteMessageSQL, values: nil)
                
                self.client?.serialQueue.async {
                    completion(.success)
                }
            } catch {
                Logger.shared.error(error)
                self.client?.serialQueue.async {
                    completion(.failure(error: LCError(error: error)))
                }
            }
            db.cachedStatements?.removeObjects(forKeys: [deleteConverationSQL, deleteLastMessageSQL, deleteMessageSQL])
        }
    }
    
    func insertOrReplace(
        conversationID: String,
        lastMessage: IMMessage,
        completion: ((LCBooleanResult) -> Void)? = nil)
    {
        guard lastMessage.notTransientMessage, lastMessage.notWillMessage else {
            completion?(.failure(error: LCError(code: .inconsistency)))
            return
        }
        self.dbQueue.inDatabase { (db) in
            guard self.isOpened else {
                self.client?.serialQueue.async {
                    completion?(.failure(error: LCError.localStorageNotOpen))
                }
                return
            }
            do {
                let table = try Table.Message(message: lastMessage)
                let rawData: Data = try JSONEncoder().encode(table)
                let sql: String =
                """
                insert or replace into \(Table.lastMessage)
                (
                \(Table.LastMessage.CodingKeys.conversation_id.rawValue),
                \(Table.LastMessage.CodingKeys.raw_data.rawValue),
                \(Table.LastMessage.CodingKeys.sent_timestamp.rawValue)
                )
                values(?,?,?)
                """
                let values: [Any] = [table.conversationID, rawData, table.sentTimestamp]
                IMLocalStorage.verboseLogging(database: db, SQL: sql)
                try db.executeUpdate(sql, values: values)
                self.client?.serialQueue.async {
                    completion?(.success)
                }
            } catch {
                Logger.shared.error(error)
                self.client?.serialQueue.async {
                    completion?(.failure(error: LCError(error: error)))
                }
            }
        }
    }
    
    private func newestAndOldestMessage(from messages: [IMMessage]) -> (newest: IMMessage, oldest: IMMessage)? {
        guard
            let first = messages.first,
            let last = messages.last,
            let firstSentTimestamp = first.sentTimestamp,
            let lastSentTimestamp = last.sentTimestamp,
            let firstMessageID = first.ID,
            let lastMessageID = last.ID
            else
        {
            return nil
        }
        if firstSentTimestamp > lastSentTimestamp {
            return (first, last)
        } else if firstSentTimestamp == lastSentTimestamp {
            if firstMessageID > lastMessageID {
                return (first, last)
            } else {
                return (last, first)
            }
        } else {
            return (last, first)
        }
    }
    
    private func setupBreakpoint(message: IMMessage, newest: Bool, db: FMDatabase) throws {
        guard let conversationID = message.conversationID else {
            throw LCError(code: .inconsistency, reason: "Message's Conversation ID not found.")
        }
        guard let sentTimestamp = message.sentTimestamp else {
            throw LCError(code: .inconsistency, reason: "Message's Sent Timestamp not found.")
        }
        guard let messageID = message.ID else {
            throw LCError(code: .inconsistency, reason: "Message's ID not found.")
        }
        let key = Table.Message.CodingKeys.self
        let comparisonSymbol = (newest ? ">" : "<")
        let order = (newest ? "asc" : "desc")
        let sql =
        """
        select \(key.sentTimestamp.rawValue),\(key.messageID.rawValue),\(key.breakpoint.rawValue)
        from \(Table.message)
        where \(key.conversationID.rawValue) = ?
        and
        (
        (\(key.sentTimestamp.rawValue) = ? and \(key.messageID.rawValue) \(comparisonSymbol)= ?)
        or
        (\(key.sentTimestamp.rawValue) \(comparisonSymbol) ?)
        )
        and \(key.status.rawValue) != ?
        order by \(key.sentTimestamp.rawValue) \(order),\(key.messageID.rawValue) \(order)
        limit ?
        """
        let values: [Any] = [
            conversationID,
            sentTimestamp,
            messageID,
            sentTimestamp,
            IMMessage.Status.failed.rawValue,
            2
        ]
        IMLocalStorage.verboseLogging(database: db, SQL: sql, values: values)
        let result = try db.executeQuery(sql, values: values)
        var index = 0
        message.breakpoint = true
        while result.next() {
            let breakpoint = result.bool(forColumn: key.breakpoint.rawValue)
            if index == 0 {
                if
                    result.longLongInt(forColumn: key.sentTimestamp.rawValue) == sentTimestamp,
                    result.string(forColumn: key.messageID.rawValue) == messageID
                {
                    if breakpoint {
                        index += 1
                        continue
                    } else {
                        message.breakpoint = false
                        break
                    }
                } else {
                    break
                }
            } else if index == 1 {
                message.breakpoint = breakpoint
                break
            }
        }
        result.close()
    }
    
    func insertOrReplace(
        messages: [IMMessage],
        completion: ((LCBooleanResult) -> Void)? = nil)
    {
        guard
            messages.count > 2,
            let messageTuple = self.newestAndOldestMessage(from: messages)
            else
        {
            self.client?.serialQueue.async {
                completion?(.failure(error: LCError(code: .inconsistency)))
            }
            return
        }
        let newestMessage = messageTuple.newest
        let oldestMessage = messageTuple.oldest
        self.dbQueue.inImmediateTransaction { (db, rollback) in
            guard self.isOpened else {
                self.client?.serialQueue.async {
                    completion?(.failure(error: LCError.localStorageNotOpen))
                }
                return
            }
            do {
                try self.setupBreakpoint(message: newestMessage, newest: true, db: db)
                try self.setupBreakpoint(message: oldestMessage, newest: false, db: db)
                let key = Table.Message.CodingKeys.self
                let sql: String =
                """
                insert or replace into \(Table.message)
                (
                \(key.conversationID.rawValue),
                \(key.sentTimestamp.rawValue),
                \(key.messageID.rawValue),
                \(key.fromPeerID.rawValue),
                \(key.content.rawValue),
                \(key.binary.rawValue),
                \(key.deliveredTimestamp.rawValue),
                \(key.readTimestamp.rawValue),
                \(key.patchedTimestamp.rawValue),
                \(key.allMentioned.rawValue),
                \(key.mentionedList.rawValue),
                \(key.status.rawValue),
                \(key.breakpoint.rawValue)
                )
                values(?,?,?,?,?,?,?,?,?,?,?,?,?)
                """
                for message in messages {
                    let table = try Table.Message(message: message)
                    let values: [Any] = [
                        table.conversationID,
                        table.sentTimestamp,
                        table.messageID,
                        table.fromPeerID as Any,
                        table.content as Any,
                        table.binary,
                        table.deliveredTimestamp as Any,
                        table.readTimestamp as Any,
                        table.patchedTimestamp as Any,
                        table.allMentioned as Any,
                        table.mentionedList as Any,
                        table.status,
                        table.breakpoint
                    ]
                    IMLocalStorage.verboseLogging(database: db, SQL: sql, values: values)
                    try db.executeUpdate(sql, values: values)
                }
                self.client?.serialQueue.async {
                    completion?(.success)
                }
            } catch {
                Logger.shared.error(error)
                rollback.pointee = true
                self.client?.serialQueue.async {
                    completion?(.failure(error: LCError(error: error)))
                }
            }
        }
    }
    
    func updateOrIgnore(
        message: IMMessage,
        completion: ((LCBooleanResult) -> Void)? = nil)
        throws
    {
        let table = try Table.Message(message: message)
        self.dbQueue.inDatabase { (db) in
            guard self.isOpened else {
                self.client?.serialQueue.async {
                    completion?(.failure(error: LCError.localStorageNotOpen))
                }
                return
            }
            do {
                let key = Table.Message.CodingKeys.self
                let sql: String =
                """
                update or ignore \(Table.message)
                set
                (
                \(key.fromPeerID.rawValue),
                \(key.content.rawValue),
                \(key.binary.rawValue),
                \(key.patchedTimestamp.rawValue),
                \(key.allMentioned.rawValue),
                \(key.mentionedList.rawValue)
                )
                = (?,?,?,?,?,?)
                where \(key.conversationID.rawValue) = ? and \(key.sentTimestamp.rawValue) = ? and \(key.messageID.rawValue) = ?
                """
                let values: [Any] = [
                    table.fromPeerID as Any,
                    table.content as Any,
                    table.binary,
                    table.patchedTimestamp as Any,
                    table.allMentioned as Any,
                    table.mentionedList as Any,
                    table.conversationID,
                    table.sentTimestamp,
                    table.messageID
                ]
                IMLocalStorage.verboseLogging(database: db, SQL: sql, values: values)
                try db.executeUpdate(sql, values: values)
                self.client?.serialQueue.async {
                    completion?(.success)
                }
            } catch {
                Logger.shared.error(error)
                self.client?.serialQueue.async {
                    completion?(.failure(error: LCError(error: error)))
                }
            }
        }
    }
    
    private func messageBoundary(
        order: IMConversation.MessageQueryDirection,
        start: IMConversation.MessageQueryEndpoint?,
        end: IMConversation.MessageQueryEndpoint?)
        -> (newestBoundary: IMConversation.MessageQueryEndpoint?, oldestBoundary: IMConversation.MessageQueryEndpoint?)?
    {
        var newestBoundary: IMConversation.MessageQueryEndpoint?
        var oldestBoundary: IMConversation.MessageQueryEndpoint?
        if let startTimestamp = start?.sentTimestamp, let endTimestamp = end?.sentTimestamp {
            if startTimestamp > endTimestamp {
                newestBoundary = start
                oldestBoundary = end
            } else if startTimestamp == endTimestamp {
                if
                    let startMessageID = start?.messageID,
                    let endMessageID = end?.messageID
                {
                    if startMessageID > endMessageID {
                        newestBoundary = start
                        oldestBoundary = end
                    } else {
                        newestBoundary = end
                        oldestBoundary = start
                    }
                } else {
                    newestBoundary = start
                    oldestBoundary = end
                }
            } else {
                newestBoundary = end
                oldestBoundary = start
            }
        } else if let _ = start?.sentTimestamp {
            if order == .newToOld {
                newestBoundary = start
            } else {
                oldestBoundary = start
            }
        } else if let _ = end?.sentTimestamp {
            if order == .newToOld {
                oldestBoundary = end
            } else {
                newestBoundary = end
            }
        } else {
            return nil
        }
        return (newestBoundary, oldestBoundary)
    }
    
    private func messageWhereCondition(
        start: IMConversation.MessageQueryEndpoint? = nil,
        end: IMConversation.MessageQueryEndpoint? = nil,
        direction: IMConversation.MessageQueryDirection? = nil)
        -> String
    {
        let key = Table.Message.CodingKeys.self
        let order: IMConversation.MessageQueryDirection = (direction ?? .newToOld)
        
        guard let messageBoundaryTuple = self.messageBoundary(order: order, start: start, end: end) else {
            let comparison = (order == .newToOld) ? "<" : ">"
            let timestamp = (order == .newToOld) ? Int64(Date().timeIntervalSince1970 * 1000.0) : 0
            return "(\(key.sentTimestamp.rawValue) \(comparison) \(timestamp))"
        }
        
        let boundaryCondition: (IMConversation.MessageQueryEndpoint, Int64, Bool) -> String = { endpoint, timestamp, isNewest in
            let closed: Bool = (endpoint.isClosed ?? false)
            var comparisonSymbol: String
            if isNewest {
                comparisonSymbol = (closed ? "<=" : "<")
            } else {
                comparisonSymbol = (closed ? ">=" : ">")
            }
            var condition: String = ""
            if let messageID = endpoint.messageID {
                condition += "(\(key.sentTimestamp.rawValue) = \(timestamp) and \(key.messageID.rawValue) \(comparisonSymbol) \"\(messageID)\") or "
                comparisonSymbol = (isNewest ? "<" : ">")
            }
            condition += "(\(key.sentTimestamp.rawValue) \(comparisonSymbol) \(timestamp))"
            return "(\(condition))"
        }
        
        let newestBoundary = messageBoundaryTuple.newestBoundary
        let oldestBoundary = messageBoundaryTuple.oldestBoundary
        
        var whereCondition: String = ""
        if let newest = newestBoundary, let newestTimestamp = newest.sentTimestamp {
            whereCondition += boundaryCondition(newest, newestTimestamp, true)
        }
        if let oldest = oldestBoundary, let oldestTimestamp = oldest.sentTimestamp {
            if let _ = newestBoundary?.sentTimestamp {
                whereCondition += " and "
            }
            whereCondition += boundaryCondition(oldest, oldestTimestamp, false)
        }
        return "(\(whereCondition))"
    }
    
    func selectMessages(
        conversationID: String,
        start: IMConversation.MessageQueryEndpoint? = nil,
        end: IMConversation.MessageQueryEndpoint? = nil,
        direction: IMConversation.MessageQueryDirection? = nil,
        limit: Int,
        completion: @escaping (IMClient, LCGenericResult<[IMMessage]>, Bool) -> Void)
    {
        self.dbQueue.inDatabase { (db) in
            guard let client = self.client else {
                return
            }
            guard self.isOpened else {
                client.serialQueue.async {
                    completion(client, .failure(error: LCError.localStorageNotOpen), false)
                }
                return
            }
            var sql: String = ""
            do {
                let key = Table.Message.CodingKeys.self
                let order = (direction ?? .newToOld)
                sql =
                """
                select * from \(Table.message)
                where \(key.conversationID.rawValue) = \"\(conversationID)\"
                and \(self.messageWhereCondition(start: start, end: end, direction: direction))
                order by \(key.sentTimestamp.rawValue) \(order.SQLOrder),\(key.messageID.rawValue) \(order.SQLOrder)
                limit \(limit)
                """
                IMLocalStorage.verboseLogging(database: db, SQL: sql)
                let result = try db.executeQuery(sql, values: nil)
                var messages: [IMMessage] = []
                var breakpointSet: Set<Bool> = []
                while result.next() {
                    let sentTimestamp: Int64 = result.longLongInt(forColumn: key.sentTimestamp.rawValue)
                    guard
                        sentTimestamp != 0,
                        let conversationID: String = result.string(forColumn: key.conversationID.rawValue),
                        let messageID: String = result.string(forColumn: key.messageID.rawValue)
                        else
                    {
                        continue
                    }
                    var content: IMMessage.Content?
                    if let contentString: String = result.string(forColumn: key.content.rawValue) {
                        if result.bool(forColumn: key.binary.rawValue) {
                            if let data = contentString.data(using: .utf8) {
                                content = .data(data)
                            }
                        } else {
                            content = .string(contentString)
                        }
                    }
                    var mentionedMembers: [String]?
                    if
                        let mentionedList: String = result.string(forColumn: key.mentionedList.rawValue),
                        let data = mentionedList.data(using: .utf8)
                    {
                        do {
                            mentionedMembers = try JSONSerialization.jsonObject(with: data) as? [String]
                        } catch {
                            Logger.shared.error(error)
                        }
                    }
                    let message = IMMessage.instance(
                        application: client.application,
                        isTransient: false,
                        conversationID: conversationID,
                        currentClientID: client.ID,
                        fromClientID: result.string(forColumn: key.fromPeerID.rawValue),
                        timestamp: sentTimestamp,
                        patchedTimestamp: result.longLongInt(forColumn: key.patchedTimestamp.rawValue),
                        messageID: messageID,
                        content: content,
                        isAllMembersMentioned: result.bool(forColumn: key.allMentioned.rawValue),
                        mentionedMembers: mentionedMembers
                    )
                    let deliveredTimestamp = result.longLongInt(forColumn: key.deliveredTimestamp.rawValue)
                    if deliveredTimestamp != 0 {
                        message.deliveredTimestamp = deliveredTimestamp
                    }
                    let readTimestamp = result.longLongInt(forColumn: key.readTimestamp.rawValue)
                    if readTimestamp != 0 {
                        message.readTimestamp = readTimestamp
                    }
                    let breakpoint = result.bool(forColumn: key.breakpoint.rawValue)
                    message.breakpoint = breakpoint
                    breakpointSet.insert(breakpoint)
                    if order == .newToOld {
                        messages.insert(message, at: 0)
                    } else {
                        messages.append(message)
                    }
                }
                result.close()
                client.serialQueue.async {
                    completion(client, .success(value: messages), breakpointSet.contains(true))
                }
            } catch {
                Logger.shared.error(error)
                client.serialQueue.async {
                    completion(client, .failure(error: LCError(error: error)), false)
                }
            }
            db.cachedStatements?.removeObject(forKey: sql)
        }
    }
}

extension LCError {
    
    static var localStorageNotOpen: LCError {
        return LCError(
            code: .inconsistency,
            reason: "Local Storage not open."
        )
    }
    
}
