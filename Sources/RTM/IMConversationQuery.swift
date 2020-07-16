//
//  IMConversationQuery.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2019/1/8.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import Foundation

/// IM Conversation Query
public class IMConversationQuery: LCQuery {
    
    /// limit of conversation ID's count in one query.
    public static let limitRangeOfQueryResult = 1...100
    
    /// conversation query option.
    public struct Options: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// the conversations in query result will not contain members info.
        public static let notContainMembers = Options(rawValue: 1 << 0)
        
        /// the conversations in query result will contain the last message if the last message exist.
        public static let containLastMessage = Options(rawValue: 1 << 1)
    }
    
    /// @see `Options`, default is nil.
    public var options: Options? = nil
    
    /// the client which this query belong to.
    public private(set) weak var client: IMClient?
    
    let eventQueue: DispatchQueue?
    
    // MARK: Init
    
    init(client: IMClient, eventQueue: DispatchQueue? = nil) {
        self.eventQueue = eventQueue
        self.client = client
        super.init(application: client.application, className: "_Conversation")
    }
    
    // MARK: Combine
    
    private func validateClient(_ query: IMConversationQuery) throws {
        guard let selfClient = self.client,
              let queryClient = query.client,
              selfClient === queryClient else {
            throw LCError(
                code: .inconsistency,
                reason: "`self.client` !== query.client, they should be the same instance.")
        }
    }
    
    private static func validateClient(_ queries: [IMConversationQuery]) throws {
        guard let first = queries.first else {
            return
        }
        for item in queries {
            try first.validateClient(item)
        }
    }
    
    private static func combine(
        queries: [IMConversationQuery],
        operation: String) throws -> IMConversationQuery?
    {
        guard let first = queries.first else {
            throw LCError(
                code: .inconsistency,
                reason: "`queries` is empty.")
        }
        guard let client = first.client else {
            return nil
        }
        try self.validateClient(queries)
        let query = IMConversationQuery(
            client: client,
            eventQueue: first.eventQueue)
        query.constraintDictionary[operation] = queries.map { $0.constraintDictionary }
        return query
    }
    
    /// Performs a logical AND operation on an array of one or more expressions of query.
    /// - Parameter queries: An array of one or more expressions of query.
    /// - Throws: `LCError`
    /// - Returns: An optional `IMConversationQuery`
    public static func and(_ queries: [IMConversationQuery]) throws -> IMConversationQuery? {
        return try self.combine(queries: queries, operation: "$and")
    }
    
    /// Performs a logical AND operation on self and the query.
    /// - Parameter query: The query.
    /// - Throws: `LCError`
    /// - Returns: An optional `IMConversationQuery`
    public func and(_ query: IMConversationQuery) throws -> IMConversationQuery? {
        return try IMConversationQuery.and([self, query])
    }
    
    /// Performs a logical OR operation on an array of one or more expressions of query.
    /// - Parameter queries: An array of one or more expressions of query.
    /// - Throws: `LCError`
    /// - Returns: An optional `IMConversationQuery`
    public static func or(_ queries: [IMConversationQuery]) throws -> IMConversationQuery? {
        return try self.combine(queries: queries, operation: "$or")
    }
    
    /// Performs a logical OR operation on self and the query.
    /// - Parameter query: The query.
    /// - Throws: `LCError`
    /// - Returns: An optional `IMConversationQuery`
    public func or(_ query: IMConversationQuery) throws -> IMConversationQuery? {
        return try IMConversationQuery.or([self, query])
    }
    
    // MARK: Where
    
    public override func `where`(_ key: String, _ constraint: Constraint) throws {
        switch constraint {
        case .included, .selected:
            throw LCError(
                code: .inconsistency,
                reason: "\(constraint) not support.")
        default:
            break
        }
        try super.where(key, constraint)
    }
    
    // MARK: Find
    
    /// Get Conversation by ID.
    ///
    /// - Parameters:
    ///   - ID: The ID of the conversation.
    ///   - completion: callback.
    public func getConversation(
        by ID: String,
        completion: @escaping (LCGenericResult<IMConversation>) -> Void)
        throws
    {
        try self.where(IMConversation.Key.objectId.rawValue, .equalTo(ID))
        let tuple = try self.whereAndSort()
        self.queryConversations(
            whereString: tuple.whereString,
            limit: 1,
            options: self.options)
        { (result) in
            switch result {
            case .success(value: let conversations):
                if let conversation = conversations.first {
                    completion(.success(value: conversation))
                } else {
                    let error = LCError(code: .conversationNotFound)
                    completion(.failure(error: error))
                }
            case .failure(let error):
                completion(.failure(error: error))
            }
        }
    }
    
    /// Get Conversations by ID set.
    ///
    /// - Parameters:
    ///   - IDs: The set of ID string.
    ///   - completion: callback.
    public func getConversations(
        by IDs: Set<String>,
        completion: @escaping (LCGenericResult<[IMConversation]>) -> Void)
        throws
    {
        guard IMConversationQuery.limitRangeOfQueryResult.contains(IDs.count) else {
            throw LCError.conversationQueryLimitInvalid
        }
        try self.where(IMConversation.Key.objectId.rawValue, .containedIn(Array(IDs)))
        let tuple = try self.whereAndSort()
        self.queryConversations(
            whereString: tuple.whereString,
            sortString: tuple.sortString,
            limit: IDs.count,
            options: self.options,
            completion: completion
        )
    }
    
    /// Get Temporary Conversation by ID.
    /// - Parameters:
    ///   - ID: The ID of the temporary conversation.
    ///   - completion: Result callback.
    public func getTemporaryConversation(
        by ID: String,
        completion: @escaping (LCGenericResult<IMTemporaryConversation>) -> Void)
        throws
    {
        try self.getTemporaryConversations(by: [ID]) { (result) in
            switch result {
            case .success(value: let conversations):
                if let conversation = conversations.first {
                    completion(.success(value: conversation))
                } else {
                    completion(.failure(
                        error: LCError(
                            code: .conversationNotFound)))
                }
            case .failure(error: let error):
                completion(.failure(error: error))
            }
        }
    }
    
    /// Get Temporary Conversations by ID set.
    ///
    /// - Parameters:
    ///   - IDs: The set of ID string.
    ///   - completion: callback.
    public func getTemporaryConversations(
        by IDs: Set<String>,
        completion: @escaping (LCGenericResult<[IMTemporaryConversation]>) -> Void)
        throws
    {
        guard IMConversationQuery.limitRangeOfQueryResult.contains(IDs.count) else {
            throw LCError.conversationQueryLimitInvalid
        }
        self.queryConversations(
            limit: IDs.count,
            tempConvIDs: Array(IDs))
        { result in
            switch result {
            case .success(value: let conversations):
                if let tmpConversations = conversations as? [IMTemporaryConversation] {
                    completion(.success(value: tmpConversations))
                } else {
                    completion(.failure(error: LCError.conversationQueryTypeInvalid))
                }
            case .failure(error: let error):
                completion(.failure(error: error))
            }
        }
    }
    
    /// General conversation query (not support temporary conversation query).
    ///
    /// The default where constraint is {"m": client.ID},
    /// The default sort is -lm,
    /// The default limit is 10,
    /// The default skip is 0.
    ///
    /// - Parameter completion: callback
    public func findConversations(completion: @escaping (LCGenericResult<[IMConversation]>) -> Void) throws {
        if let limit: Int = self.limit {
            guard IMConversationQuery.limitRangeOfQueryResult.contains(limit) else {
                throw LCError.conversationQueryLimitInvalid
            }
        }
        let tuple = try self.whereAndSort()
        self.queryConversations(
            whereString: tuple.whereString,
            sortString: tuple.sortString,
            limit: self.limit,
            skip: self.skip,
            options: self.options,
            completion: completion
        )
    }
    
    // MARK: Unavailable
    
    @available(*, unavailable)
    public override init(application: LCApplication, className: String) {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func copy(with zone: NSZone?) -> Any {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func encode(with aCoder: NSCoder) {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func get<T>(_ objectId: LCStringConvertible, cachePolicy: LCQuery.CachePolicy = .onlyNetwork) -> LCValueResult<T> where T : LCObject {
        fatalError("not support")
    }
    
    public override func get<T>(_ objectId: LCStringConvertible, cachePolicy: LCQuery.CachePolicy = .onlyNetwork, completionQueue: DispatchQueue = .main, completion: @escaping (LCValueResult<T>) -> Void) -> LCRequest where T : LCObject {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func getFirst<T>(cachePolicy: LCQuery.CachePolicy = .onlyNetwork) -> LCValueResult<T> where T : LCObject {
        fatalError("not support")
    }
    
    public override func getFirst<T>(cachePolicy: LCQuery.CachePolicy = .onlyNetwork, completionQueue: DispatchQueue = .main, completion: @escaping (LCValueResult<T>) -> Void) -> LCRequest where T : LCObject {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func find<T>(cachePolicy: LCQuery.CachePolicy = .onlyNetwork) -> LCQueryResult<T> where T : LCObject {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func find<T>(cachePolicy: LCQuery.CachePolicy = .onlyNetwork, completionQueue: DispatchQueue = .main, completion: @escaping (LCQueryResult<T>) -> Void) -> LCRequest where T : LCObject {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func count(cachePolicy: LCQuery.CachePolicy = .onlyNetwork) -> LCCountResult {
        fatalError("not support")
    }
    
    public override func count(cachePolicy: LCQuery.CachePolicy = .onlyNetwork, completionQueue: DispatchQueue = .main, completion: @escaping (LCCountResult) -> Void) -> LCRequest {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override class func and(_ queries: [LCQuery]) throws -> LCQuery {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override class func or(_ queries: [LCQuery]) throws -> LCQuery {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func and(_ query: LCQuery) throws -> LCQuery {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func or(_ query: LCQuery) throws -> LCQuery {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func whereKey(_ key: String, _ constraint: LCQuery.Constraint) {
        fatalError("not support")
    }
}

private extension IMConversationQuery {
    
    func queryConversations(
        whereString: String? = nil,
        sortString: String? = nil,
        limit: Int? = nil,
        skip: Int? = nil,
        options: Options? = nil,
        tempConvIDs: [String]? = nil,
        completion: @escaping (LCGenericResult<[IMConversation]>) -> Void)
    {
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .query
            var convCommand = IMConvCommand()
            if let limit = limit {
                convCommand.limit = Int32(limit)
            }
            if let tempConvIDs = tempConvIDs {
                convCommand.tempConvIds = tempConvIDs
            } else {
                if let whereString = whereString {
                    var jsonCommand = IMJsonObjectMessage()
                    jsonCommand.data = whereString
                    convCommand.where = jsonCommand
                }
                if let sort = sortString {
                    convCommand.sort = sort
                }
                if let skip = skip {
                    convCommand.skip = Int32(skip)
                }
                if let flag = options {
                    convCommand.flag = Int32(flag.rawValue)
                }
            }
            outCommand.convMessage = convCommand
            return outCommand
        }, completion: { (client, commandCallbackResult) in
            let callback: (LCGenericResult<[IMConversation]>) -> Void = { result in
                if let queue = self.eventQueue {
                    queue.async { completion(result) }
                } else {
                    completion(result)
                }
            }
            switch commandCallbackResult {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                do {
                    let conversations = try self.conversations(command: inCommand, client: client)
                    callback(.success(value: conversations))
                } catch {
                    let error = LCError(error: error)
                    callback(.failure(error: error))
                }
            case .error(let error):
                callback(.failure(error: error))
            }
        })
    }
    
    func whereAndSort() throws -> (whereString: String?, sortString: String?) {
        let whereString = try self.lconWhereString()
        let sortString = self.orderedKeys
        return (whereString, sortString)
    }
    
    func conversations(command: IMGenericCommand, client: IMClient) throws -> [IMConversation] {
        assert(client.specificAssertion)
        guard
            let convMessage: IMConvCommand = (command.hasConvMessage ? command.convMessage : nil),
            let jsonMessage: IMJsonObjectMessage = (convMessage.hasResults ? convMessage.results : nil),
            let jsonString: String = (jsonMessage.hasData ? jsonMessage.data : nil),
            let rawDatas: [IMConversation.RawData] = try jsonString.jsonObject() else
        {
            throw LCError(code: .commandInvalid)
        }
        var conversations: [IMConversation] = []
        for rawData in rawDatas {
            guard let objectId: String = rawData[IMConversation.Key.objectId.rawValue] as? String else {
                throw LCError.conversationQueryObjectIDNotFound
            }
            let instance: IMConversation
            if let existConversation: IMConversation = client.convCollection[objectId] {
                existConversation.safeExecuting(operation: .rawDataReplaced(by: rawData), client: client)
                instance = existConversation
            } else {
                instance = IMConversation.instance(ID: objectId, rawData: rawData, client: client, caching: true)
                client.convCollection[objectId] = instance
            }
            conversations.append(instance)
        }
        return conversations
    }
    
}

fileprivate extension LCError {
    
    static var conversationQueryObjectIDNotFound: LCError {
        return LCError(
            code: .malformedData,
            reason: "The object ID of result not found"
        )
    }
    
    static var conversationQueryLimitInvalid: LCError {
        return LCError(
            code: .inconsistency,
            reason: "The limit of query shoule in \(IMConversationQuery.limitRangeOfQueryResult)"
        )
    }
    
    static var conversationQueryTypeInvalid: LCError {
        return LCError(
            code: .invalidType,
            reason: "The type of query result is invalid"
        )
    }
    
}
