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
    
    init(client: IMClient, eventQueue: DispatchQueue? = nil) {
        self.eventQueue = eventQueue
        self.client = client
        super.init(application: client.application, className: "_Conversation")
    }
    
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
    public override func get<T>(_ objectId: LCStringConvertible) -> LCValueResult<T> where T : LCObject {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func get<T>(_ objectId: LCStringConvertible, completion: @escaping (LCValueResult<T>) -> Void) -> LCRequest where T : LCObject {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func getFirst<T>() -> LCValueResult<T> where T : LCObject {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func getFirst<T>(_ completion: @escaping (LCValueResult<T>) -> Void) -> LCRequest where T : LCObject {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func find<T>() -> LCQueryResult<T> where T : LCObject {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func find<T>(_ completion: @escaping (LCQueryResult<T>) -> Void) -> LCRequest where T : LCObject {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func count() -> LCCountResult {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func count(_ completion: @escaping (LCCountResult) -> Void) -> LCRequest {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func and(_ query: LCQuery) throws -> LCQuery {
        throw LCError(code: .inconsistency, reason: "not support")
    }
    
    @available(*, unavailable)
    public override func or(_ query: LCQuery) throws -> LCQuery {
        throw LCError(code: .inconsistency, reason: "not support")
    }
    
    @available(*, unavailable)
    public override func whereKey(_ key: String, _ constraint: LCQuery.Constraint) {
        fatalError("not support")
    }
    
    /**
     Get logic AND of another query.
     Note that it only combine constraints of two queries, the limit and skip option will be discarded.
     
     - parameter query: The another query.
     - returns: The logic AND of two queries.
     */
    public func and(_ query: IMConversationQuery) throws -> IMConversationQuery? {
        return try self.combine(op: "$and", query: query)
    }
    
    /**
     Get logic OR of another query.
     Note that it only combine constraints of two queries, the limit and skip option will be discarded.
     
     - parameter query: The another query.
     - returns: The logic OR of two queries.
     */
    public func or(_ query: IMConversationQuery) throws -> IMConversationQuery? {
        return try self.combine(op: "$or", query: query)
    }
    
    private func combine(op: String, query: IMConversationQuery) throws -> IMConversationQuery? {
        guard let client = self.client else {
            return nil
        }
        guard client === query.client else {
            throw LCError(code: .inconsistency, reason: "Different IM client.")
        }
        let result = IMConversationQuery(client: client, eventQueue: self.eventQueue)
        result.constraintDictionary[op] = [self.constraintDictionary, query.constraintDictionary]
        return result
    }
    
    /// Add constraint in query.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - constraint: The constraint.
    public override func `where`(_ key: String, _ constraint: Constraint) throws {
        let typeChecker: (LCQuery) throws -> Void = { query in
            guard let _ = query as? IMConversationQuery else {
                throw LCError(code: .inconsistency, reason: "\(type(of: query)) not support")
            }
        }
        switch constraint {
        case .included, .selected:
            throw LCError(code: .inconsistency, reason: "\(constraint) not support")
            /* Query matching. */
        case let .matchedQuery(query):
            try typeChecker(query)
        case let .notMatchedQuery(query):
            try typeChecker(query)
        case let .matchedQueryAndKey(query, _):
            try typeChecker(query)
        case let .notMatchedQueryAndKey(query, _):
            try typeChecker(query)
        default:
            break
        }
        try super.where(key, constraint)
    }
    
    /// Get Conversation by ID.
    ///
    /// - Parameters:
    ///   - ID: The ID of the conversation.
    ///   - completion: callback.
    public func getConversation<T: IMConversation>(
        by ID: String,
        completion: @escaping (LCGenericResult<T>) -> Void)
        throws
    {
        if T.self == IMTemporaryConversation.self {
            throw LCError.conversationQueryTypeInvalid
        }
        try self.where(IMConversation.Key.objectId.rawValue, .equalTo(ID))
        let tuple = try self.whereAndSort()
        self.queryConversations(
            whereString: tuple.whereString,
            limit: 1,
            options: self.options)
        { (result) in
            switch result {
            case .success(value: let conversations):
                if let conversation: T = conversations.first as? T {
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
    public func getConversations<T: IMConversation>(
        by IDs: Set<String>,
        completion: @escaping (LCGenericResult<[T]>) -> Void)
        throws
    {
        if T.self == IMTemporaryConversation.self {
            throw LCError.conversationQueryTypeInvalid
        }
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
            tempConvIDs: Array(IDs),
            completion: completion
        )
    }
    
    /// General conversation query (not support temporary conversation query).
    ///
    /// The default where constraint is {"m": client.ID},
    /// The default sort is -lm,
    /// The default limit is 10,
    /// The default skip is 0.
    ///
    /// - Parameter completion: callback
    public func findConversations<T: IMConversation>(completion: @escaping (LCGenericResult<[T]>) -> Void) throws {
        if T.self == IMTemporaryConversation.self {
            throw LCError.conversationQueryTypeInvalid
        }
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
    
}

private extension IMConversationQuery {
    
    func queryConversations<T: IMConversation>(
        whereString: String? = nil,
        sortString: String? = nil,
        limit: Int? = nil,
        skip: Int? = nil,
        options: Options? = nil,
        tempConvIDs: [String]? = nil,
        completion: @escaping (LCGenericResult<[T]>) -> Void)
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
            let callback: (LCGenericResult<[T]>) -> Void = { result in
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
                    let conversations: [T] = try self.conversations(command: inCommand, client: client)
                    let result = LCGenericResult<[T]>.success(value: conversations)
                    callback(result)
                } catch {
                    let error = LCError(error: error)
                    let result = LCGenericResult<[T]>.failure(error: error)
                    callback(result)
                }
            case .error(let error):
                let result = LCGenericResult<[T]>.failure(error: error)
                callback(result)
            }
        })
    }
    
    func whereAndSort() throws -> (whereString: String?, sortString: String?) {
        let dictionary = self.lconValue
        var whereString: String? = nil
        var sortString: String? = nil
        if let whereCondition: Any = dictionary["where"] {
            let data = try JSONSerialization.data(withJSONObject: whereCondition)
            whereString = String(data: data, encoding: .utf8)
        }
        if let sortCondition: String = dictionary["order"] as? String {
            sortString = sortCondition
        }
        return (whereString, sortString)
    }
    
    func conversations<T: IMConversation>(command: IMGenericCommand, client: IMClient) throws -> [T] {
        assert(client.specificAssertion)
        let convMessage: IMConvCommand? = (command.hasConvMessage ? command.convMessage : nil)
        let jsonMessage: IMJsonObjectMessage? = ((convMessage?.hasResults ?? false) ? convMessage?.results : nil)
        guard let jsonString: String = ((jsonMessage?.hasData ?? false) ? jsonMessage?.data : nil) else {
            throw LCError(code: .commandInvalid)
        }
        guard let rawDatas: [IMConversation.RawData] = try jsonString.jsonObject(), !rawDatas.isEmpty else {
            throw LCError(code: .conversationNotFound)
        }
        var conversations: [T] = []
        for rawData in rawDatas {
            guard let objectId: String = rawData[IMConversation.Key.objectId.rawValue] as? String else {
                throw LCError.conversationQueryObjectIDNotFound
            }
            let instance: IMConversation
            if let existConversation: IMConversation = client.convCollection[objectId] {
                existConversation.safeChangingRawData(operation: .rawDataReplaced(by: rawData), client: client)
                instance = existConversation
            } else {
                instance = IMConversation.instance(ID: objectId, rawData: rawData, client: client, caching: true)
                client.convCollection[objectId] = instance
            }
            guard let conversation: T = instance as? T else {
                throw LCError(
                    code: .invalidType,
                    reason: "conversation<T: \(type(of: instance))> can't cast to type: \(T.self)"
                )
            }
            conversations.append(conversation)
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
            reason: "if result type is \(IMTemporaryConversation.self), should use Get-Temporary-Conversations API"
        )
    }
    
}
