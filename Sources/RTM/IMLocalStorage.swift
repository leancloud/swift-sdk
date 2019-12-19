//
//  IMLocalStorage.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2019/4/18.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

#if canImport(GRDB)
import Foundation
import GRDB

class IMLocalStorage {
    
    struct Table {
        static let conversation = "conversation"
        static let lastMessage = "last_message"
        static let message = "message"
        
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
            
            var value: DatabaseValueConvertible {
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
            
            var value: DatabaseValueConvertible {
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
        
        struct Message: Codable {
            let conversationID: String
            let sentTimestamp: Int64
            let messageID: String
            let fromPeerID: String?
            let content: String?
            let binary: Bool?
            let deliveredTimestamp: Int64?
            let readTimestamp: Int64?
            let patchedTimestamp: Int64?
            let allMentioned: Bool?
            let mentionedList: String?
            let status: Int
            let breakpoint: Bool
            
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
            
            init(message: IMMessage) throws {
                guard message.underlyingStatus == .sent,
                    let conversationID = message.conversationID,
                    let sentTimestamp = message.sentTimestamp,
                    let messageID = message.ID else {
                        throw LCError(
                            code: .inconsistency,
                            reason: "storing message invalid.")
                }
                self.conversationID = conversationID
                self.sentTimestamp = sentTimestamp
                self.messageID = messageID
                self.fromPeerID = message.fromClientID
                let tuple = message.content?.encodeToDatabaseValue()
                self.content = tuple?.string
                self.binary = tuple?.binary
                self.deliveredTimestamp = message.deliveredTimestamp
                self.readTimestamp = message.readTimestamp
                self.patchedTimestamp = message.patchedTimestamp
                self.allMentioned = message.isAllMembersMentioned
                self.mentionedList = try message.mentionedMembers?.jsonString()
                self.status = IMMessage.Status.sent.rawValue
                self.breakpoint = message.breakpoint
            }
            
            init(failedMessage: IMMessage) throws {
                guard failedMessage.underlyingStatus == .failed,
                    !failedMessage.isTransient,
                    !failedMessage.isWill,
                    let conversationID = failedMessage.conversationID,
                    let sendingTimestamp = failedMessage.sendingTimestamp,
                    let dToken = failedMessage.dToken else {
                        throw LCError(
                            code: .inconsistency,
                            reason: "storing failed message invalid.")
                }
                self.conversationID = conversationID
                self.sentTimestamp = sendingTimestamp
                self.messageID = dToken
                self.fromPeerID = failedMessage.fromClientID
                let tuple = failedMessage.content?.encodeToDatabaseValue()
                self.content = tuple?.string
                self.binary = tuple?.binary
                self.deliveredTimestamp = nil
                self.readTimestamp = nil
                self.patchedTimestamp = nil
                self.allMentioned = failedMessage.isAllMembersMentioned
                self.mentionedList = try failedMessage.mentionedMembers?.jsonString()
                self.status = IMMessage.Status.failed.rawValue
                self.breakpoint = false
            }
            
            func message(client: IMClient) throws -> IMMessage {
                let message = IMMessage.instance(
                    application: client.application,
                    conversationID: self.conversationID,
                    currentClientID: client.ID,
                    fromClientID: self.fromPeerID,
                    timestamp: self.sentTimestamp,
                    patchedTimestamp: self.patchedTimestamp,
                    messageID: self.messageID,
                    content: self.content?.decodeToMessageContent(binary: self.binary),
                    isAllMembersMentioned: self.allMentioned,
                    mentionedMembers: try self.mentionedList?.jsonObject())
                message.deliveredTimestamp = self.deliveredTimestamp
                message.readTimestamp = self.readTimestamp
                return message
            }
        }
    }
    
    let dbPool: DatabasePool
    
    init(path: String, clientID: String) throws {
        var configuration = Configuration()
        configuration.label = "\(IMLocalStorage.self).dbQueue"
        configuration.trace = {
            Logger.shared.verbose("""
                \n------ LeanCloud SQL Executing
                \(IMClient.self)<ID: \"\(clientID)\">
                \($0)
                ------ END
                """)
        }
        try self.dbPool = DatabasePool(path: path, configuration: configuration)
    }
}

extension IMLocalStorage {
    
    // MARK: Table Create
    
    func createTablesIfNotExists() throws {
        try self.dbPool.write { db in
            try self.createConversationTableIfNotExists(db: db)
            try self.createLastMessageTableIfNotExists(db: db)
            try self.createMessageTableIfNotExists(db: db)
        }
    }
    
    private func createConversationTableIfNotExists(db: Database) throws {
        let tableName: String = Table.conversation
        let key = Table.Conversation.CodingKeys.self
        let sql: String = """
        create table if not exists \(tableName) (
        \(key.id.rawValue) text primary key,
        \(key.raw_data.rawValue) blob,
        \(key.updated_timestamp.rawValue) integer,
        \(key.created_timestamp.rawValue) integer,
        \(key.outdated.rawValue) integer
        );
        create index if not exists \(tableName)_\(key.updated_timestamp.rawValue)
        on \(tableName)(\(key.updated_timestamp.rawValue));
        create index if not exists \(tableName)_\(key.created_timestamp.rawValue)
        on \(tableName)(\(key.created_timestamp.rawValue));
        """
        try db.execute(sql: sql)
    }
    
    private func createLastMessageTableIfNotExists(db: Database) throws {
        let tableName: String = Table.lastMessage
        let key = Table.LastMessage.CodingKeys.self
        let sql: String = """
        create table if not exists \(tableName) (
        \(key.conversation_id.rawValue) text primary key,
        \(key.raw_data.rawValue) blob,
        \(key.sent_timestamp.rawValue) integer
        );
        create index if not exists \(tableName)_\(key.sent_timestamp.rawValue)
        on \(tableName)(\(key.sent_timestamp.rawValue));
        """
        try db.execute(sql: sql)
    }
    
    private func createMessageTableIfNotExists(db: Database) throws {
        let tableName: String = Table.message
        let key = Table.Message.CodingKeys.self
        let sql: String = """
        create table if not exists \(tableName) (
        \(key.conversationID.rawValue) text,
        \(key.sentTimestamp.rawValue) integer,
        \(key.messageID.rawValue) text,
        \(key.fromPeerID.rawValue) text,
        \(key.content.rawValue) blob,
        \(key.binary.rawValue) integer,
        \(key.deliveredTimestamp.rawValue) integer,
        \(key.readTimestamp.rawValue) integer,
        \(key.patchedTimestamp.rawValue) integer,
        \(key.allMentioned.rawValue) integer,
        \(key.mentionedList.rawValue) blob,
        \(key.status.rawValue) integer,
        \(key.breakpoint.rawValue) integer,
        primary key (\(key.conversationID.rawValue),\(key.sentTimestamp.rawValue),\(key.messageID.rawValue))
        );
        """
        try db.execute(sql: sql)
    }
}

extension IMLocalStorage {
    
    // MARK: Conversation Update
    
    func insertOrReplace(
        conversationID: String,
        rawData: IMConversation.RawData,
        convType: IMConversation.ConvType)
        throws
    {
        guard convType != .temporary, convType != .transient else {
            return
        }
        let key = Table.Conversation.CodingKeys.self
        let sql: String = """
        insert or replace into \(Table.conversation) (
        \(key.id.rawValue),
        \(key.raw_data.rawValue),
        \(key.updated_timestamp.rawValue),
        \(key.created_timestamp.rawValue),
        \(key.outdated.rawValue)
        ) values(?,?,?,?,?)
        """
        let millisecondFromKey: (IMConversation.Key) -> Int64 = { key in
            if let dateString: String = rawData[key.rawValue] as? String,
                let date: Date = LCDate(isoString: dateString)?.value {
                return Int64(date.timeIntervalSince1970 * 1000.0)
            } else {
                return 0
            }
        }
        let createdTS = millisecondFromKey(.createdAt)
        let updatedTS = millisecondFromKey(.updatedAt)
        let arguments: StatementArguments = [
            conversationID,
            try JSONSerialization.data(withJSONObject: rawData),
            (updatedTS > 0 ? updatedTS : createdTS),
            createdTS,
            false]
        try self.dbPool.write { db in
            try db.execute(sql: sql, arguments: arguments)
        }
    }
    
    func updateOrIgnore(
        conversationID: String,
        sets: [Table.Conversation])
        throws
    {
        guard !sets.isEmpty else {
            return
        }
        var columnNames: [String] = []
        var bindingSymbols: [String] = []
        var values: [DatabaseValueConvertible] = []
        for item in sets {
            assert(!columnNames.contains(item.key))
            columnNames.append(item.key)
            bindingSymbols.append("?")
            values.append(item.value)
        }
        values.append(conversationID)
        let sql: String = """
        update or ignore \(Table.conversation)
        set (\(columnNames.joined(separator: ","))) = (\(bindingSymbols.joined(separator: ",")))
        where \(Table.Conversation.CodingKeys.id.rawValue) = ?
        """
        try self.dbPool.write { db in
            try db.execute(sql: sql, arguments: StatementArguments(values))
        }
    }
    
    func insertOrReplace(
        conversationID: String,
        lastMessage: IMMessage)
        throws
    {
        guard !lastMessage.isTransient, !lastMessage.isWill else {
            return
        }
        let key = Table.LastMessage.CodingKeys.self
        let sql: String = """
        insert or replace into \(Table.lastMessage) (
        \(key.conversation_id.rawValue),
        \(key.raw_data.rawValue),
        \(key.sent_timestamp.rawValue)
        ) values(?,?,?)
        """
        let messageTable = try Table.Message(message: lastMessage)
        let arguments: StatementArguments = [
            conversationID,
            try JSONEncoder().encode(messageTable),
            messageTable.sentTimestamp]
        try self.dbPool.write { db in
            try db.execute(sql: sql, arguments: arguments)
        }
    }
    
    func deleteConversationAndMessages(IDs: Set<String>) throws {
        guard !IDs.isEmpty else {
            return
        }
        let bindings: String = [String](repeating: "?", count: IDs.count)
            .joined(separator: ",")
        let arguments = StatementArguments(IDs)
        try self.dbPool.write { db in
            try db.execute(
                sql: """
                delete from \(Table.conversation)
                where \(Table.Conversation.CodingKeys.id.rawValue)
                in (\(bindings))
                """,
                arguments: arguments)
            try db.execute(
                sql: """
                delete from \(Table.lastMessage)
                where \(Table.LastMessage.CodingKeys.conversation_id.rawValue)
                in (\(bindings))
                """,
                arguments: arguments)
            try db.execute(
                sql: """
                delete from \(Table.message)
                where \(Table.Message.CodingKeys.conversationID.rawValue)
                in (\(bindings))
                """,
                arguments: arguments)
        }
    }
    
}

extension IMLocalStorage {
    
    // MARK: Conversation Query
    
    func selectConversations(
        order: IMClient.StoredConversationOrder,
        client: IMClient)
        throws
        -> (conversationMap: [String: IMConversation], conversations: [IMConversation])
    {
        var selectConversationSQL: String = "select * from \(Table.conversation)"
        var selectLastMessageSQL: String = "select * from \(Table.lastMessage)"
        let orderCondition: String = " order by \(order.key) \(order.sqlOrder)"
        let isLastMessageSentTimestampOrder: Bool
        switch order {
        case .createdTimestamp, .updatedTimestamp:
            selectConversationSQL += orderCondition
            isLastMessageSentTimestampOrder = false
        case .lastMessageSentTimestamp:
            selectLastMessageSQL += orderCondition
            isLastMessageSentTimestampOrder = true
        }
        
        return try self.dbPool.read { db in
            let conversationRows = try Row.fetchCursor(db, sql: selectConversationSQL)
            let lastMessageRows = try Row.fetchCursor(db, sql: selectLastMessageSQL)
            
            var conversationMap: [String: IMConversation] = [:]
            var conversations: [IMConversation] = []
            
            while let row = try conversationRows.next() {
                let key = Table.Conversation.CodingKeys.self
                guard
                    let conversationID: String = row[key.id.rawValue] as String?,
                    let data: Data = row[key.raw_data.rawValue] as Data?,
                    let outdated: Bool = row[key.outdated.rawValue] as Bool?,
                    let rawData = try JSONSerialization.jsonObject(with: data) as? IMConversation.RawData else
                { continue }
                let conversation: IMConversation = IMConversation.instance(
                    ID: conversationID,
                    rawData: rawData,
                    client: client,
                    caching: false)
                conversation.isOutdated = outdated
                conversationMap[conversationID] = conversation
                if !isLastMessageSentTimestampOrder {
                    conversations.append(conversation)
                }
            }
            
            var conversationMapCopy = conversationMap
            while let row = try lastMessageRows.next() {
                let key = Table.LastMessage.CodingKeys.self
                guard
                    let conversationID: String = row[key.conversation_id.rawValue] as String?,
                    let conversation: IMConversation = conversationMapCopy.removeValue(forKey: conversationID),
                    let data: Data = row[key.raw_data.rawValue] as Data? else
                { continue }
                let lastMessage: IMMessage = try JSONDecoder()
                    .decode(IMLocalStorage.Table.Message.self, from: data)
                    .message(client: client)
                conversation.safeUpdatingLastMessage(
                    newMessage: lastMessage,
                    client: client,
                    caching: false,
                    notifying: false)
                if isLastMessageSentTimestampOrder {
                    conversations.append(conversation)
                }
            }
            if isLastMessageSentTimestampOrder {
                let remainConversations = conversationMapCopy.values
                conversations.append(contentsOf: remainConversations)
            }
            
            return (conversationMap, conversations)
        }
    }
    
}

extension IMLocalStorage {
    
    // MARK: Message Update
    
    private func insertOrReplaceMessageSQL() -> String {
        let key = Table.Message.CodingKeys.self
        return """
        insert or replace into \(Table.message) (
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
        ) values(?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
    }
    
    private func insertOrReplaceMessageArguments(table: Table.Message) -> StatementArguments {
        return [
            table.conversationID,
            table.sentTimestamp,
            table.messageID,
            table.fromPeerID,
            table.content,
            table.binary,
            table.deliveredTimestamp,
            table.readTimestamp,
            table.patchedTimestamp,
            table.allMentioned,
            table.mentionedList,
            table.status,
            table.breakpoint]
    }
    
    private func newestAndOldestMessage(from messages: [IMMessage]) -> (newest: IMMessage, oldest: IMMessage)? {
        guard let first = messages.first,
            let last = messages.last,
            let firstSentTimestamp = first.sentTimestamp,
            let lastSentTimestamp = last.sentTimestamp,
            let firstMessageID = first.ID,
            let lastMessageID = last.ID else {
                return nil
        }
        if firstSentTimestamp == lastSentTimestamp {
            return firstMessageID > lastMessageID ? (first, last) : (last, first)
        } else if firstSentTimestamp > lastSentTimestamp {
            return (first, last)
        } else {
            return (last, first)
        }
    }
    
    func insertOrReplace(messages: [IMMessage]) throws {
        guard messages.count > 2,
            let tuple = self.newestAndOldestMessage(from: messages) else {
                return
        }
        try self.setupBreakpoint(message: tuple.newest, newest: true)
        try self.setupBreakpoint(message: tuple.oldest, newest: false)
        let sql = self.insertOrReplaceMessageSQL()
        try self.dbPool.write { db in
            for message in messages {
                try db.execute(
                    sql: sql,
                    arguments: self.insertOrReplaceMessageArguments(
                        table: try Table.Message(message: message)))
            }
        }
    }
    
    func insertOrReplace(failedMessage message: IMMessage) throws {
        try self.dbPool.write { db in
            try db.execute(
                sql: self.insertOrReplaceMessageSQL(),
                arguments: self.insertOrReplaceMessageArguments(
                    table: try Table.Message(failedMessage: message)))
        }
    }
    
    func delete(failedMessage message: IMMessage) throws {
        guard message.underlyingStatus == .failed,
            let conversationID = message.conversationID,
            let sendingTimestamp = message.sendingTimestamp,
            let dToken = message.dToken else {
                throw LCError(
                    code: .inconsistency,
                    reason: "deleting failed message invalid.")
        }
        let key = Table.Message.CodingKeys.self
        let sql = """
        delete from \(Table.message)
        where \(key.conversationID.rawValue) = ?
        and \(key.sentTimestamp.rawValue) = ?
        and \(key.messageID.rawValue) = ?
        and \(key.status.rawValue) = \(IMMessage.Status.failed.rawValue)
        """
        let arguments: StatementArguments = [
            conversationID,
            sendingTimestamp,
            dToken]
        try self.dbPool.write { db in
            try db.execute(sql: sql, arguments: arguments)
        }
    }
    
    func updateOrIgnore(message: IMMessage) throws {
        let table = try Table.Message(message: message)
        let key = Table.Message.CodingKeys.self
        let sql: String = """
        update or ignore \(Table.message) set (
        \(key.fromPeerID.rawValue),
        \(key.content.rawValue),
        \(key.binary.rawValue),
        \(key.patchedTimestamp.rawValue),
        \(key.allMentioned.rawValue),
        \(key.mentionedList.rawValue)
        ) = (?,?,?,?,?,?)
        where \(key.conversationID.rawValue) = ?
        and \(key.sentTimestamp.rawValue) = ?
        and \(key.messageID.rawValue) = ?
        """
        let arguments: StatementArguments = [
            table.fromPeerID,
            table.content,
            table.binary,
            table.patchedTimestamp,
            table.allMentioned,
            table.mentionedList,
            table.conversationID,
            table.sentTimestamp,
            table.messageID]
        try self.dbPool.write { db in
            try db.execute(sql: sql, arguments: arguments)
        }
    }
}

extension IMLocalStorage {
    
    // MARK: Message Query
    
    func selectMessages(
        client: IMClient,
        conversationID: String,
        start: IMConversation.MessageQueryEndpoint?,
        end: IMConversation.MessageQueryEndpoint?,
        direction: IMConversation.MessageQueryDirection?,
        limit: Int)
        throws
        -> (messages: [IMMessage], hasBreakpoint: Bool)
    {
        let order = (direction ?? .newToOld)
        let messageWhereCondition = self.messageWhereCondition(order: order, start: start, end: end)
        
        let key = Table.Message.CodingKeys.self
        let sql: String = """
        select * from \(Table.message)
        where \(key.conversationID.rawValue) = ?
        and (\(messageWhereCondition.condition))
        order by \(key.sentTimestamp.rawValue) \(order.SQLOrder),\(key.messageID.rawValue) \(order.SQLOrder)
        limit ?
        """
        
        var values: [DatabaseValueConvertible] = messageWhereCondition.values
        values.insert(conversationID, at: 0)
        values.append(limit)
        
        return try self.dbPool.read { db in
            let rows = try Row.fetchCursor(db, sql: sql, arguments: StatementArguments(values))
            var messages: [IMMessage] = []
            var breakpointSet: Set<Bool> = []
            
            while let row = try rows.next() {
                guard let sentTimestamp: Int64 = row[key.sentTimestamp.rawValue] as Int64?,
                    let messageID: String = row[key.messageID.rawValue] as String? else {
                        breakpointSet.insert(true)
                        break
                }
                let content = (row[key.content.rawValue] as String?)?
                    .decodeToMessageContent(
                        binary: row[key.binary.rawValue] as Bool?)
                let isAllMembersMentioned = row[key.allMentioned.rawValue] as Bool?
                let mentionedMembers: [String]? = try (row[key.mentionedList.rawValue] as String?)?
                    .jsonObject()
                let message: IMMessage
                if ((row[key.status.rawValue] as Int?)
                    ?? IMMessage.Status.sent.rawValue)
                    == IMMessage.Status.failed.rawValue  {
                    message = IMMessage.instance(
                        application: client.application,
                        conversationID: conversationID,
                        currentClientID: client.ID,
                        fromClientID: client.ID,
                        timestamp: nil,
                        patchedTimestamp: nil,
                        messageID: nil,
                        content: content,
                        isAllMembersMentioned: isAllMembersMentioned,
                        mentionedMembers: mentionedMembers,
                        underlyingStatus: .failed)
                    message.sendingTimestamp = sentTimestamp
                    message.dToken = messageID
                } else {
                    message = IMMessage.instance(
                        application: client.application,
                        conversationID: conversationID,
                        currentClientID: client.ID,
                        fromClientID: row[key.fromPeerID.rawValue] as String?,
                        timestamp: sentTimestamp,
                        patchedTimestamp: row[key.patchedTimestamp.rawValue] as Int64?,
                        messageID: messageID,
                        content: content,
                        isAllMembersMentioned: isAllMembersMentioned,
                        mentionedMembers: mentionedMembers)
                    message.deliveredTimestamp = row[key.deliveredTimestamp.rawValue] as Int64?
                    message.readTimestamp = row[key.readTimestamp.rawValue] as Int64?
                }
                if let breakpoint: Bool = row[key.breakpoint.rawValue] as Bool? {
                    message.breakpoint = breakpoint
                }
                if order == .newToOld {
                    messages.insert(message, at: 0)
                } else {
                    messages.append(message)
                }
                breakpointSet.insert(message.breakpoint)
            }
            
            return (messages, breakpointSet.contains(true))
        }
    }
    
    private func messageWhereCondition(
        order: IMConversation.MessageQueryDirection,
        start: IMConversation.MessageQueryEndpoint? = nil,
        end: IMConversation.MessageQueryEndpoint? = nil)
        -> (condition: String, values: [DatabaseValueConvertible])
    {
        let key = Table.Message.CodingKeys.self
        
        guard let messageBoundaryTuple = self.messageBoundary(order: order, start: start, end: end) else {
            return ("\(key.sentTimestamp.rawValue) \(order == .newToOld ? "<" : ">") ?",
                [order == .newToOld ? Int64(Date().timeIntervalSince1970 * 1000.0) : 0])
        }
        
        let newestBoundary = messageBoundaryTuple.newestBoundary
        let oldestBoundary = messageBoundaryTuple.oldestBoundary
        var whereCondition: String = ""
        var values: [DatabaseValueConvertible] = []
        
        let boundaryCondition: (IMConversation.MessageQueryEndpoint, Int64, Bool) -> String = { endpoint, timestamp, isNewest in
            var condition: String = ""
            let closed: Bool = endpoint.isClosed ?? false
            var comparisonSymbol: String = isNewest ? (closed ? "<=" : "<") : (closed ? ">=" : ">")
            if let messageID: String = endpoint.messageID {
                condition += "(\(key.sentTimestamp.rawValue) = ? and \(key.messageID.rawValue) \(comparisonSymbol) ?) or "
                values.append(timestamp)
                values.append(messageID)
                comparisonSymbol = (isNewest ? "<" : ">")
            }
            condition += "\(key.sentTimestamp.rawValue) \(comparisonSymbol) ?"
            values.append(timestamp)
            return condition
        }
        
        if let newest = newestBoundary, let newestTimestamp = newest.sentTimestamp {
            whereCondition = boundaryCondition(newest, newestTimestamp, true)
        }
        if let oldest = oldestBoundary, let oldestTimestamp = oldest.sentTimestamp {
            let condition: String = boundaryCondition(oldest, oldestTimestamp, false)
            if let _ = newestBoundary?.sentTimestamp {
                whereCondition = "(\(whereCondition)) and (\(condition))"
            } else {
                whereCondition = condition
            }
        }
        return (whereCondition, values)
    }
    
    private func messageBoundary(
        order: IMConversation.MessageQueryDirection,
        start: IMConversation.MessageQueryEndpoint?,
        end: IMConversation.MessageQueryEndpoint?)
        -> (newestBoundary: IMConversation.MessageQueryEndpoint?, oldestBoundary: IMConversation.MessageQueryEndpoint?)?
    {
        if let startTimestamp = start?.sentTimestamp, let endTimestamp = end?.sentTimestamp {
            if startTimestamp == endTimestamp {
                if let startMessageID = start?.messageID, let endMessageID = end?.messageID {
                    return startMessageID > endMessageID ? (start, end) : (end, start)
                } else {
                    return (start, end)
                }
            } else {
                return startTimestamp > endTimestamp ? (start, end) : (end, start)
            }
        } else if let _ = start?.sentTimestamp {
            return order == .newToOld ? (start, nil) : (nil, start)
        } else if let _ = end?.sentTimestamp {
            return order == .newToOld ? (nil, end) : (end, nil)
        } else {
            return nil
        }
    }
    
    private func setupBreakpoint(message: IMMessage, newest: Bool) throws {
        guard
            let conversationID = message.conversationID,
            let sentTimestamp = message.sentTimestamp,
            let messageID = message.ID else
        {
            throw LCError(code: .inconsistency, reason: "\(IMLocalStorage.self): message invalid.")
        }
        let key = Table.Message.CodingKeys.self
        let comparison = newest ? ">" : "<"
        let order = newest ? "asc" : "desc"
        let sql: String = """
        select \(key.sentTimestamp.rawValue),\(key.messageID.rawValue),\(key.breakpoint.rawValue)
        from \(Table.message)
        where \(key.conversationID.rawValue) = ?
        and ((\(key.sentTimestamp.rawValue) = ?
        and \(key.messageID.rawValue) \(comparison)= ?)
        or \(key.sentTimestamp.rawValue) \(comparison) ?)
        and \(key.status.rawValue) != \(IMMessage.Status.failed.rawValue)
        order by \(key.sentTimestamp.rawValue) \(order),\(key.messageID.rawValue) \(order)
        limit 2
        """
        let arguments: StatementArguments = [
            conversationID,
            sentTimestamp,
            messageID,
            sentTimestamp]
        try self.dbPool.read { db in
            let rows = try Row.fetchCursor(db, sql: sql, arguments: arguments)
            message.breakpoint = true
            var index = 0
            while let row = try rows.next() {
                guard
                    let rowBreakpoint = row[key.breakpoint.rawValue] as Bool?,
                    let rowSentTimestamp = row[key.sentTimestamp.rawValue] as Int64?,
                    let rowMessageID = row[key.messageID.rawValue] as String? else
                { break }
                if index == 0 {
                    guard rowSentTimestamp == sentTimestamp, rowMessageID == messageID else {
                        break
                    }
                    if !rowBreakpoint {
                        message.breakpoint = false
                        break
                    }
                    index += 1
                } else if index == 1 {
                    message.breakpoint = rowBreakpoint
                }
            }
        }
    }
}

private extension String {
    
    func decodeToMessageContent(binary: Bool?) -> IMMessage.Content? {
        guard let binary: Bool = binary else {
            return nil
        }
        var content: IMMessage.Content?
        if binary {
            if let data: Data = self.data(using: .utf8) {
                content = .data(data)
            }
        } else {
            content = .string(self)
        }
        return content
    }
}

private extension IMMessage.Content {
    
    func encodeToDatabaseValue() -> (string: String, binary: Bool)? {
        switch self {
        case let .data(data):
            if let string = String(data: data, encoding: .utf8) {
                return (string, true)
            } else {
                return nil
            }
        case let .string(string):
            return (string, false)
        }
    }
}

private extension LCError {
    
    static var cannotImportGRDB: LCError {
        return LCError(
            code: .inconsistency,
            reason: "can not import GRDB.")
    }
}
#endif
