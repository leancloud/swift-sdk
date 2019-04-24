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
            case lastMessageSentTimestamp(Int64)
            case outdated(Bool)
            
            enum CodingKeys: String {
                case id
                case raw_data
                case updated_timestamp
                case created_timestamp
                case last_message_sent_timestamp
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
                case .lastMessageSentTimestamp:
                    return CodingKeys.last_message_sent_timestamp.rawValue
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
                case let .lastMessageSentTimestamp(v):
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
            
            enum CodingKeys: String {
                case conversation_id
                case raw_data
            }
            
            var key: String {
                switch self {
                case .conversationID:
                    return CodingKeys.conversation_id.rawValue
                case .rawData:
                    return CodingKeys.raw_data.rawValue
                }
            }
            
            var value: Any {
                switch self {
                case let .conversationID(v):
                    return v
                case let .rawData(v):
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
            let content: String
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
    
    init?(url: URL, client: IMClient) {
        if let dbQueue = FMDatabaseQueue(url: url) {
            self.dbQueue = dbQueue
            self.client = client
        } else {
            return nil
        }
    }
    
    init?(path: String, client: IMClient) {
        if let dbQueue = FMDatabaseQueue(path: path) {
            self.dbQueue = dbQueue
            self.client = client
        } else {
            return nil
        }
    }
    
    static func verboseLogging(database: FMDatabase, SQL: String, values: [Any]? = nil) {
        Logger.shared.verbose(closure: { () -> String in
            var info: String = "\(database) executing\nSQL: \(SQL)"
            if let values = values {
                info += "\nValues: \(values)"
            }
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
                Logger.shared.error(error)
            }
            
            guard db.open() else {
                callbackError()
                return
            }
            
            let convKey = Table.Conversation.CodingKeys.self
            let msgKey = Table.Message.CodingKeys.self
            
            let creatingConverstionTableSQL: String =
            """
            create table if not exists \(Table.conversation)
            (
            \(convKey.id.rawValue) text primary key,
            \(convKey.raw_data.rawValue) blob,
            \(convKey.updated_timestamp.rawValue) integer,
            \(convKey.created_timestamp.rawValue) integer,
            \(convKey.last_message_sent_timestamp.rawValue) integer
            \(convKey.outdated.rawValue) integer,
            );
            create index if not exists \(Table.conversation)_\(convKey.updated_timestamp.rawValue)
            on \(Table.conversation)(\(convKey.updated_timestamp.rawValue));
            create index if not exists \(Table.conversation)_\(convKey.created_timestamp.rawValue)
            on \(Table.conversation)(\(convKey.created_timestamp.rawValue));
            create index if not exists \(Table.conversation)_\(convKey.last_message_sent_timestamp.rawValue)
            on \(Table.conversation)(\(convKey.last_message_sent_timestamp.rawValue));
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
            \(Table.LastMessage.CodingKeys.raw_data.rawValue) integer
            );
            """
            IMLocalStorage.verboseLogging(database: db, SQL: creatingLastMessageTableSQL)
            guard db.executeStatements(creatingLastMessageTableSQL)
                else
            {
                callbackError()
                return
            }
            
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
            self.client?.serialQueue.async {
                completion(.success)
            }
        }
    }
    
    func insertOrReplace(conversation ID: String, rawData: IMConversation.RawData, lastMessageSentTimestamp: Int64) {
        self.dbQueue.inDatabase { (db) in
            db.shouldCacheStatements = true
            defer {
                db.shouldCacheStatements = false
            }
            do {
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
                \(Table.Conversation.CodingKeys.last_message_sent_timestamp.rawValue),
                \(Table.Conversation.CodingKeys.outdated.rawValue)
                )
                values(?,?,?,?,?,?)
                """
                let values: [Any] = [
                    ID,
                    rawData,
                    millisecondFromKey(.updatedAt),
                    millisecondFromKey(.createdAt),
                    lastMessageSentTimestamp,
                    false
                ]
                IMLocalStorage.verboseLogging(database: db, SQL: sql, values: values)
                try db.executeUpdate(sql, values: values)
            } catch {
                Logger.shared.error(error)
            }
        }
    }
    
    func updateOrIgnore(conversation ID: String, sets: [Table.Conversation]) {
        guard !sets.isEmpty else {
            return
        }
        self.dbQueue.inDatabase { (db) in
            db.shouldCacheStatements = true
            defer {
                db.shouldCacheStatements = false
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
                values.append(ID)
                let sql =
                """
                update or ignore \(Table.conversation)
                set (\(names.joined(separator: ","))) = (\(bindingSymbols.joined(separator: ",")))
                where \(Table.Conversation.CodingKeys.id.rawValue) = ?
                """
                IMLocalStorage.verboseLogging(database: db, SQL: sql, values: values)
                try db.executeUpdate(sql, values: values)
            } catch {
                Logger.shared.error(error)
            }
        }
    }
    
    enum ConversationSelectOrder {
        case updatedTimestamp(descending: Bool)
        case createdTimestamp(descending: Bool)
        case lastMessageSentTimestamp(descending: Bool)
        
        var key: String {
            switch self {
            case .updatedTimestamp:
                return Table.Conversation.CodingKeys.updated_timestamp.rawValue
            case .createdTimestamp:
                return Table.Conversation.CodingKeys.created_timestamp.rawValue
            case .lastMessageSentTimestamp:
                return Table.Conversation.CodingKeys.last_message_sent_timestamp.rawValue
            }
        }
        
        var value: Bool {
            switch self {
            case let .updatedTimestamp(v):
                return v
            case let .createdTimestamp(v):
                return v
            case let .lastMessageSentTimestamp(v):
                return v
            }
        }
        
        var sqlOrder: String {
            if self.value {
                return "desc"
            } else {
                return "asc"
            }
        }
    }
    
    func selectConversations(
        order: ConversationSelectOrder = .lastMessageSentTimestamp(descending: true),
        IDSet: Set<String>? = nil,
        completion: @escaping (LCGenericResult<(conversationResult: FMResultSet, lastMessageResult: FMResultSet)>) -> Void)
    {
        self.dbQueue.inDatabase { (db) in
            do {
                var conversationIDJoinedString: String? = nil
                
                var selectConversationSQL: String = "select * from \(Table.conversation)"
                if let set = IDSet, !set.isEmpty {
                    let joinedString: String = ("\"" + set.joined(separator: "\",\"") + "\"")
                    conversationIDJoinedString = joinedString
                    selectConversationSQL += " where \(Table.Conversation.CodingKeys.id.rawValue) in (\(joinedString))"
                }
                selectConversationSQL += " order by \(order.key) \(order.sqlOrder)"
                IMLocalStorage.verboseLogging(database: db, SQL: selectConversationSQL)
                let conversationResult = try db.executeQuery(selectConversationSQL, values: nil)
                
                var selectLastMessageSQL: String = "select * from \(Table.lastMessage)"
                if let joinedString: String = conversationIDJoinedString {
                    selectLastMessageSQL += " where \(Table.LastMessage.CodingKeys.conversation_id.rawValue) in (\(joinedString))"
                }
                IMLocalStorage.verboseLogging(database: db, SQL: selectLastMessageSQL)
                let lastMessageResult = try db.executeQuery(selectLastMessageSQL, values: nil)
                
                self.client?.serialQueue.async {
                    completion(.success(value: (conversationResult, lastMessageResult)))
                }
            } catch {
                Logger.shared.error(error)
                self.client?.serialQueue.async {
                    completion(.failure(error: LCError(underlyingError: error)))
                }
            }
        }
    }
    
    func deleteConversationAndMessages(IDs: Set<String>) {
        guard !IDs.isEmpty else {
            return
        }
        self.dbQueue.inDatabase { (db) in
            do {
                let joinedString = ("\"" + IDs.joined(separator: "\",\"") + "\"")
                
                let deleteConverationSQL = "delete from \(Table.conversation) where \(Table.Conversation.CodingKeys.id.rawValue) in (\(joinedString))"
                IMLocalStorage.verboseLogging(database: db, SQL: deleteConverationSQL)
                try db.executeUpdate(deleteConverationSQL, values: nil)
                
                let deleteLastMessageSQL = "delete from \(Table.lastMessage) where \(Table.LastMessage.CodingKeys.conversation_id.rawValue) in (\(joinedString))"
                IMLocalStorage.verboseLogging(database: db, SQL: deleteLastMessageSQL)
                try db.executeUpdate(deleteLastMessageSQL, values: nil)
                
                let deleteMessageSQL = "delete from \(Table.message) where \(Table.Message.CodingKeys.conversationID.rawValue) in (\(joinedString))"
                IMLocalStorage.verboseLogging(database: db, SQL: deleteMessageSQL)
                try db.executeUpdate(deleteMessageSQL, values: nil)
            } catch {
                Logger.shared.error(error)
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
            throw LCError(code: .inconsistency, reason: "Message's Conversation-ID not found.")
        }
        guard let sentTimestamp = message.sentTimestamp else {
            throw LCError(code: .inconsistency, reason: "Message's Sent Timestamp not found.")
        }
        guard let messageID = message.ID else {
            throw LCError(code: .inconsistency, reason: "Message's ID not found.")
        }
        let key = Table.Message.CodingKeys.self
        let comparisonSymbol = (newest ? ">=" : "<=")
        let order = (newest ? "asc" : "desc")
        let sql =
        """
        select \(key.sentTimestamp.rawValue),\(key.messageID.rawValue),\(key.breakpoint.rawValue)
        from \(Table.message)
        where \(key.conversationID.rawValue) = \"\(conversationID)\"
        and \(key.sentTimestamp.rawValue) \(comparisonSymbol) \(sentTimestamp)
        and \(key.messageID.rawValue) \(comparisonSymbol) \"\(messageID)\"
        and \(key.status.rawValue) != \(IMMessage.Status.failed.rawValue)
        order by \(key.sentTimestamp.rawValue) \(order),\(key.messageID.rawValue) \(order)
        limit 2
        """
        IMLocalStorage.verboseLogging(database: db, SQL: sql)
        let result = try db.executeQuery(sql, values: nil)
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
    }
    
    func insertOrReplace(messages: [IMMessage]) {
        guard
            messages.count > 2,
            let messageTuple = self.newestAndOldestMessage(from: messages)
            else
        {
            return
        }
        let newestMessage = messageTuple.newest
        let oldestMessage = messageTuple.oldest
        self.dbQueue.inImmediateTransaction { (db, rollback) in
            db.shouldCacheStatements = true
            defer {
                db.shouldCacheStatements = false
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
                        table.content,
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
            } catch {
                Logger.shared.error(error)
                rollback.pointee = true
            }
        }
    }
    
    func updateOrIgnore(message: IMMessage) throws {
        let table = try Table.Message(message: message)
        self.dbQueue.inDatabase { (db) in
            db.shouldCacheStatements = true
            defer {
                db.shouldCacheStatements = false
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
                    table.content,
                    table.binary,
                    table.patchedTimestamp as Any,
                    table.allMentioned as Any,
                    table.mentionedList as Any,
                    table.conversationID,
                    table.sentTimestamp,
                    table.messageID
                ]
                try db.executeUpdate(sql, values: values)
            } catch {
                Logger.shared.error(error)
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
        limit: Int? = nil,
        completion: @escaping (LCGenericResult<[IMMessage]>) -> Void)
    {
        self.dbQueue.inDatabase { (db) in
            guard let client = self.client else {
                return
            }
            do {
                let key = Table.Message.CodingKeys.self
                let sql: String =
                """
                select * from \(Table.message)
                where \(key.conversationID.rawValue) = \"\(conversationID)\"
                and \(self.messageWhereCondition(start: start, end: end, direction: direction))
                order by \(key.sentTimestamp.rawValue) asc,\(key.messageID.rawValue) asc
                limit \(limit ?? 20)
                """
                IMLocalStorage.verboseLogging(database: db, SQL: sql)
                let result = try db.executeQuery(sql, values: nil)
                var messages: [IMMessage] = []
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
                    message.breakpoint = result.bool(forColumn: key.breakpoint.rawValue)
                    messages.append(message)
                }
                client.serialQueue.async {
                    completion(.success(value: messages))
                }
            } catch {
                Logger.shared.error(error)
                client.serialQueue.async {
                    completion(.failure(error: LCError(error: error)))
                }
            }
        }
    }
}
