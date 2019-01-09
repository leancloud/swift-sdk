//
//  ConversationQuery.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2019/1/8.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import Foundation

/// IM Conversation Query
public final class LCConversationQuery {
    
    #if DEBUG
    private let specificKey: DispatchSpecificKey<Int>?
    // whatever random Int is OK.
    private let specificValue: Int?
    private var specificAssertion: Bool {
        if let key = specificKey, let value = specificValue {
            return value == DispatchQueue.getSpecific(key: key)
        } else {
            return true
        }
    }
    #else
    private var specificAssertion: Bool {
        return true
    }
    #endif
    
    private weak var client: LCClient?
    
    private let eventQueue: DispatchQueue?
    
    init(client: LCClient, eventQueue: DispatchQueue? = nil) {
        #if DEBUG
        self.specificKey = client.specificKey
        self.specificValue = client.specificValue
        #endif
        self.client = client
        self.eventQueue = eventQueue
    }
    
    /// Get Conversation by ID.
    ///
    /// - Parameters:
    ///   - ID: The ID of the conversation.
    ///   - completion: callback.
    /// - Throws: if `ID` invalid, then throw error.
    public func getConversation<T: LCConversation>(by ID: String, completion: @escaping (LCGenericResult<T>) -> Void) throws {
        try self.queryConversations(IDs: [ID]) { result in
            switch result {
            case .success(value: let conversations):
                if let conversation: T = conversations.first as? T {
                    completion(.success(value: conversation))
                } else {
                    let error = LCError(code: .conversationNotFound)
                    completion(.failure(error: error))
                }
            case .failure(error: let error):
                completion(.failure(error: error))
            }
        }
    }
    
    /// Get Conversations by ID set.
    ///
    /// - Parameters:
    ///   - IDs: The ID set of the conversations, should not empty.
    ///   - completion: callback.
    /// - Throws: if `IDs` invalid, then throw error.
    public func getConversations<T: LCConversation>(by IDs: Set<String>, completion: @escaping (LCGenericResult<[T]>) -> Void) throws {
        try self.queryConversations(IDs: Array<String>(IDs), completion: completion)
    }
    
    /// Get Temporary Conversations by ID set.
    ///
    /// - Parameters:
    ///   - IDs: The ID set of the temporary conversations, should not empty.
    ///   - completion: callback.
    /// - Throws: if `IDs` invalid, then throw error.
    public func getTemporaryConversations(by IDs: Set<String>, completion: @escaping (LCGenericResult<[LCTemporaryConversation]>) -> Void) throws {
        try self.queryConversations(IDs: Array<String>(IDs), isTemporary: true, completion: completion)
    }
    
}

private extension LCConversationQuery {
    
    func queryConversations<T: LCConversation>(
        IDs: [String],
        isTemporary: Bool = false,
        completion: @escaping (LCGenericResult<[T]>) -> Void)
        throws
    {
        guard !IDs.isEmpty else {
            throw LCError.conversationQueriedIDsNotFound
        }
        var whereString: String = ""
        if !isTemporary {
            whereString = try self.whereString(IDs: IDs)
        }
        var outCommand = IMGenericCommand()
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            outCommand.cmd = .conv
            outCommand.op = .query
            var convCommand = IMConvCommand()
            convCommand.limit = Int32(IDs.count)
            if isTemporary {
                convCommand.tempConvIds = IDs
            } else {
                var jsonCommand = IMJsonObjectMessage()
                jsonCommand.data = whereString
                convCommand.where = jsonCommand
            }
            outCommand.convMessage = convCommand
            return outCommand
        }, completion: { (commandCallbackResult) in
            let callback: (LCGenericResult<[T]>) -> Void = { result in
                if let queue = self.eventQueue {
                    queue.async { completion(result) }
                } else {
                    completion(result)
                }
            }
            switch commandCallbackResult {
            case .inCommand(let inCommand):
                assert(self.specificAssertion)
                guard let client = self.client else { return }
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
    
    func whereString(IDs: [String]) throws -> String {
        var value: Any
        if let ID = IDs.first, IDs.count == 1 {
            value = ID
        } else {
            value = ["$in": IDs]
        }
        let json: [String: Any] = [LCConversation.Key.objectId.rawValue: value]
        let data: Data = try JSONSerialization.data(withJSONObject: json)
        guard let string = String(data: data, encoding: .utf8) else {
            throw LCError.conversationQueryWhereNotFound
        }
        return string
    }
    
    func conversations<T: LCConversation>(command: IMGenericCommand, client: LCClient) throws -> [T] {
        let convMessage: IMConvCommand? = (command.hasConvMessage ? command.convMessage : nil)
        let jsonMessage: IMJsonObjectMessage? = ((convMessage?.hasResults ?? false) ? convMessage?.results : nil)
        guard let jsonString: String = ((jsonMessage?.hasData ?? false) ? jsonMessage?.data : nil) else {
            throw LCError(code: .commandInvalid)
        }
        guard let rawDatas: [LCConversation.RawData] = try jsonString.json(), !rawDatas.isEmpty else {
            throw LCError(code: .conversationNotFound)
        }
        var conversations: [T] = []
        for rawData in rawDatas {
            guard let objectId: String = rawData[LCConversation.Key.objectId.rawValue] as? String else {
                throw LCError.conversationIDNotFound
            }
            let instance = LCConversation.instance(ID: objectId, rawData: rawData, client: client)
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
    
    static var conversationQueriedIDsNotFound: LCError {
        return LCError(
            code: .inconsistency,
            reason: "The array of conversation ID to be to be queried is empty"
        )
    }
    
    static var conversationQueryWhereNotFound: LCError {
        return LCError(
            code: .inconsistency,
            reason: "The where condition of conversation-query not found"
        )
    }
    
    static var conversationIDNotFound: LCError {
        return LCError(
            code: .malformedData,
            reason: "The objectId of conversation-query-result not found"
        )
    }
    
}
