//
//  IMConversation.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/11/26.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/// IM Conversation
public class IMConversation {

    public typealias RawData = [String: Any]

    enum Key: String {
        case objectId = "objectId"
        case uniqueId = "uniqueId"
        case name = "name"
        case creator = "c"
        case createdAt = "createdAt"
        case updatedAt = "updatedAt"
        case attributes = "attr"
        case members = "m"
        case mutedMembers = "mu"
        case unique = "unique"
        case transient = "tr"
        case system = "sys"
        case joined = "joined"
        case joinedAt = "joinedAt"
        case muted = "muted"
        case temporary = "temp"
        case temporaryTTL = "ttl"
        case convType = "conv_type"
        case lastMessageString = "msg"
        case lastMessageBinary = "bin"
        case lastMessageId = "msg_mid"
        case lastMessageFrom = "msg_from"
        case lastMessageTimestamp = "msg_timestamp"
        case lastMessagePatchTimestamp = "patch_timestamp"
        case lastMessageMentionAll = "mention_all"
        case lastMessageMentionPids = "mention_pids"
    }

    enum ConvType: Int {
        case normal = 1
        case transient = 2
        case system = 3
        case temporary = 4
    }

    let convType: ConvType
    
    // MARK: Property

    /// The client which this conversation belong to.
    public private(set) weak var client: IMClient?

    /// The ID of the conversation.
    public let ID: String

    /// The ID of the client.
    public let clientID: IMClient.Identifier

    /// Indicates whether the conversation is unique.
    public let isUnique: Bool

    /// The unique ID of the unique conversation.
    public let uniqueID: String?

    /// The name of the conversation.
    public var name: String? {
        return self.safeDecodingRawData(with: .name)
    }

    /// The creator of the conversation.
    public var creator: String? {
        return self.safeDecodingRawData(with: .creator)
    }

    /// The creation date of the conversation.
    public var createdAt: Date? {
        if let str: String = self.safeDecodingRawData(with: .createdAt) {
            return LCDate.dateFromString(str)
        } else {
            return nil
        }
    }

    /// The updated date of the conversation.
    public var updatedAt: Date? {
        if let str: String = self.safeDecodingRawData(with: .updatedAt) {
            return LCDate.dateFromString(str)
        } else {
            return nil
        }
    }

    /// The attributes of the conversation.
    public var attributes: [String: Any]? {
        return self.safeDecodingRawData(with: .attributes)
    }

    /// The members of the conversation.
    public var members: [String]? {
        return self.safeDecodingRawData(with: .members)
    }

    /// Whether the offline notification of this conversation has been muted by the client.
    public var isMuted: Bool {
        if let mutedMembers: [String] = self.safeDecodingRawData(with: .mutedMembers) {
            return mutedMembers.contains(self.clientID)
        } else {
            return false
        }
    }
    
    /// Raw data of the conversation.
    public private(set) var rawData: RawData {
        set {
            self.sync(self._rawData = newValue)
        }
        get {
            return self.sync(self._rawData)
        }
    }
    private var _rawData: RawData
    
    /// Get value via subscript syntax.
    public subscript(key: String) -> Any? {
        get {
            return self.safeDecodingRawData(with: key)
        }
    }
    
    let lock: NSLock = NSLock()

    /// Indicates whether the data of conversation is outdated,
    /// after refresh, this property will be false.
    public internal(set) var isOutdated: Bool {
        set {
            guard self.convType != .temporary else {
                return
            }
            self.sync(self._isOutdated = newValue)
        }
        get {
            guard self.convType != .temporary else {
                return false
            }
            return self.sync(self._isOutdated)
        }
    }
    private var _isOutdated: Bool = false

    /// The last message of the conversation.
    public private(set) var lastMessage: IMMessage? {
        set {
            self.sync(self._lastMessage = newValue)
        }
        get {
            return self.sync(self._lastMessage)
        }
    }
    private var _lastMessage: IMMessage? = nil
    
    /// The last delivered date of message
    public var lastDeliveredAt: Date? {
        return IMClient.date(
            fromMillisecond: self.lastDeliveredTimestamp)
    }
    
    /// The last delivered timestamp of message
    public internal(set) var lastDeliveredTimestamp: Int64? {
        set {
            self.sync(self._lastDeliveredTimestamp = newValue)
        }
        get {
            return self.sync(self._lastDeliveredTimestamp)
        }
    }
    private var _lastDeliveredTimestamp: Int64?
    
    /// The last read date of message
    public var lastReadAt: Date? {
        return IMClient.date(
            fromMillisecond: self.lastReadTimestamp)
    }
    
    /// The last read timestamp of message
    public internal(set) var lastReadTimestamp: Int64? {
        set {
            self.sync(self._lastReadTimestamp = newValue)
        }
        get {
            return self.sync(self._lastReadTimestamp)
        }
    }
    private var _lastReadTimestamp: Int64?

    /// The unread message count of the conversation
    public internal(set) var unreadMessageCount: Int {
        set {
            self.sync(self._unreadMessageCount = newValue)
        }
        get {
            return self.sync(self._unreadMessageCount)
        }
    }
    private var _unreadMessageCount: Int = 0

    /// Indicates whether has unread message mentioning the client.
    public var isUnreadMessageContainMention: Bool {
        set {
            self.sync(self._isUnreadMessageContainMention = newValue)
        }
        get {
            return self.sync(self._isUnreadMessageContainMention)
        }
    }
    private var _isUnreadMessageContainMention: Bool = false

    /// The table of member infomation.
    public var memberInfoTable: [String: MemberInfo]? {
        return self.sync(self._memberInfoTable)
    }
    private var _memberInfoTable: [String: MemberInfo]?
    
    // MARK: Initializer

    static func instance(
        ID: String,
        rawData: RawData,
        client: IMClient,
        caching: Bool)
        -> IMConversation
    {
        var convType: ConvType = .normal
        if let typeValue = rawData[Key.convType.rawValue] as? Int,
            let validType = ConvType(rawValue: typeValue) {
            convType = validType
        } else {
            if let transient = rawData[Key.transient.rawValue] as? Bool,
                transient {
                convType = .transient
            } else if let system = rawData[Key.system.rawValue] as? Bool,
                system {
                convType = .system
            } else if let temporary = rawData[Key.temporary.rawValue] as? Bool,
                temporary {
                convType = .temporary
            } else if ID.hasPrefix(IMTemporaryConversation.prefixOfID) {
                convType = .temporary
            }
        }
        var rawData = rawData
        rawData[Key.convType.rawValue] = convType.rawValue
        switch convType {
        case .normal:
            return IMConversation(
                ID: ID,
                rawData: rawData,
                convType: convType,
                client: client,
                caching: caching)
        case .transient:
            return IMChatRoom(
                ID: ID,
                rawData: rawData,
                convType: convType,
                client: client,
                caching: caching)
        case .system:
            return IMServiceConversation(
                ID: ID,
                rawData: rawData,
                convType: convType,
                client: client,
                caching: caching)
        case .temporary:
            return IMTemporaryConversation(
                ID: ID,
                rawData: rawData,
                convType: convType,
                client: client,
                caching: caching)
        }
    }

    init(
        ID: String,
        rawData: RawData,
        convType: ConvType,
        client: IMClient,
        caching: Bool)
    {
        self.ID = ID
        self.client = client
        self._rawData = rawData
        self.clientID = client.ID
        self.convType = convType
        let uniqueID = rawData[Key.uniqueId.rawValue] as? String
        self.isUnique = (rawData[Key.unique.rawValue] as? Bool) ?? (uniqueID != nil)
        self.uniqueID = uniqueID
        if let message = self.decodingLastMessage(data: rawData, client: client) {
            self.safeUpdatingLastMessage(
                newMessage: message,
                client: client,
                caching: caching,
                notifying: false)
        }
        #if canImport(GRDB)
        if caching {
            do {
                try client.localStorage?.insertOrReplace(
                    conversationID: ID,
                    rawData: rawData,
                    convType: convType)
            } catch {
                Logger.shared.error(error)
            }
        }
        #endif
    }
    
    // MARK: Function

    /// Clear unread messages that its sent timestamp less than the sent timestamp of the parameter message.
    ///
    /// - Parameter message: The default is the last message.
    public func read(message: IMMessage? = nil) {
        self._read(message: message)
    }
    
    /// Get the last message receipt timestamps in this conversation.
    /// if the timestamps have been updated, then properties of this conversation, *lastReadAt* and *lastDeliveredAt*, will be updated.
    /// after *lastReadAt* or *lastDeliveredAt* has been updated, the client will dispatch relative events, @see `IMConversationEvent`.
    /// - Parameter completion: Result callback.
    public func getMessageReceiptFlag(completion: @escaping (LCGenericResult<MessageReceiptFlag>) -> Void) throws {
        try self._getMessageReceiptFlag(completion: completion)
    }
    
    /// Fetch the last message receipt timestamps in this conversation.
    /// if the timestamps have been updated, then properties of this conversation, *lastReadAt* and *lastDeliveredAt*, will be updated.
    /// after *lastReadAt* or *lastDeliveredAt* has been updated, the client will dispatch relative events, @see `IMConversationEvent`.
    public func fetchReceiptTimestamps() throws {
        try self._getMessageReceiptFlag()
    }

    /// Join in this conversation.
    ///
    /// - Parameter completion: callback.
    public func join(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self.add(members: [self.clientID]) { result in
            switch result {
            case .allSucceeded:
                completion(.success)
            case .failure(error: let error):
                completion(.failure(error: error))
            case .slicing(success: _, failure: let errors):
                let error = (errors.first?.error ?? LCError(code: .malformedData))
                completion(.failure(error: error))
            }
        }
    }

    /// Leave this conversation.
    ///
    /// - Parameter completion: callback.
    public func leave(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self.remove(members: [self.clientID]) { result in
            switch result {
            case .allSucceeded:
                completion(.success)
            case .failure(error: let error):
                completion(.failure(error: error))
            case .slicing(success: _, failure: let errors):
                let error = (errors.first?.error ?? LCError(code: .malformedData))
                completion(.failure(error: error))
            }
        }
    }

    /// Add members to this conversation.
    ///
    /// - Parameters:
    ///   - members: The set of member's ID.
    ///   - completion: callback.
    public func add(members: Set<String>, completion: @escaping (MemberResult) -> Void) throws {
        try self.update(members: members, op: .add, completion: completion)
    }

    /// Remove members from this conversation.
    ///
    /// - Parameters:
    ///   - members: The set of member's ID.
    ///   - completion: callback.
    public func remove(members: Set<String>, completion: @escaping (MemberResult) -> Void) throws {
        try self.update(members: members, op: .remove, completion: completion)
    }
    
    /// Get count of members in this conversation. if it's chat-room, the success result means count of online-members.
    /// - Parameter completion: Result callback.
    public func countMembers(completion: @escaping (LCCountResult) -> Void) {
        self._countMembers(completion: completion)
    }
    
    /// Check whether *client* joined this conversation.
    /// - Parameter completion: Result callback.
    public func checkJoined(completion: @escaping (LCGenericResult<Bool>) -> Void) {
        self._checkJoined(completion: completion)
    }

    /// Mute this conversation.
    ///
    /// - Parameter completion: callback.
    public func mute(completion: @escaping (LCBooleanResult) -> Void) {
        self.muteToggle(op: .mute, completion: completion)
    }

    /// Unmute this conversation.
    ///
    /// - Parameter completion: callback.
    public func unmute(completion: @escaping (LCBooleanResult) -> Void) {
        self.muteToggle(op: .unmute, completion: completion)
    }

    /// Refresh conversation's data.
    ///
    /// - Parameter completion: callback
    public func refresh(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self._refresh(completion: completion)
    }

    /// Update conversation's data.
    ///
    /// - Parameters:
    ///   - data: The data to be updated.
    ///   - completion: callback.
    public func update(attribution data: [String: Any], completion: @escaping (LCBooleanResult) -> Void) throws {
        try self._update(attribution: data, completion: completion)
    }

    /// Fetching the table of member infomation in the conversation.
    /// The result will be cached by the property `memberInfoTable`.
    ///
    /// - Parameter completion: Result of callback.
    public func fetchMemberInfoTable(completion: @escaping (LCBooleanResult) -> Void) {
        self._fetchMemberInfoTable { (client, result) in
            client.eventQueue.async {
                completion(result)
            }
        }
    }

    /// Get infomation of one member in the conversation.
    ///
    /// - Parameters:
    ///   - memberID: The ID of the member.
    ///   - completion: Result of callback.
    public func getMemberInfo(by memberID: String, completion: @escaping (LCGenericResult<MemberInfo?>) -> Void) {
        if let table = self.memberInfoTable {
            let memberInfo = table[memberID]
            self.client?.eventQueue.async {
                completion(.success(value: memberInfo))
            }
        } else {
            self._fetchMemberInfoTable { (client, result) in
                switch result {
                case .success:
                    let memberInfo = self.memberInfoTable?[memberID]
                    client.eventQueue.async {
                        completion(.success(value: memberInfo))
                    }
                case .failure(error: let error):
                    client.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            }
        }
    }

    /// Updating role of the member in the conversaiton.
    ///
    /// - Parameters:
    ///   - role: The role will be updated.
    ///   - memberID: The ID of the member who will be updated.
    ///   - completion: Result of callback.
    /// - Throws: If role parameter is owner, throw error.
    public func update(
        role: MemberRole,
        ofMember memberID: String,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
    {
        try self._update(role: role, ofMember: memberID, completion: completion)
    }

    /// Blocking members in the conversation.
    ///
    /// - Parameters:
    ///   - members: The members will be blocked.
    ///   - completion: Result of callback.
    /// - Throws: When parameter `members` is empty.
    public func block(members: Set<String>, completion: @escaping (MemberResult) -> Void) throws {
        try self.update(blockedMembers: members, op: .block, completion: completion)
    }

    /// Unblocking members in the conversation.
    ///
    /// - Parameters:
    ///   - members: The members will be unblocked.
    ///   - completion: Result of callback.
    /// - Throws: When parameter `members` is empty.
    public func unblock(members: Set<String>, completion: @escaping (MemberResult) -> Void) throws {
        try self.update(blockedMembers: members, op: .unblock, completion: completion)
    }

    /// Get the blocked members in the conversation.
    ///
    /// - Parameters:
    ///   - limit: Count limit.
    ///   - next: Offset.
    ///   - completion: Result of callback.
    /// - Throws: When limit out of range.
    public func getBlockedMembers(
        limit: Int = 50,
        next: String? = nil,
        completion: @escaping (LCGenericResult<BlockedMembersResult>) -> Void)
        throws
    {
        try self._getBlockedMembers(limit: limit, next: next, completion: completion)
    }

    /// Check if one member has been blocked in the conversation.
    ///
    /// - Parameters:
    ///   - ID: The ID of member.
    ///   - completion: Result of callback.
    public func checkBlocking(
        member ID: String,
        completion: @escaping (LCGenericResult<Bool>) -> Void)
    {
        self._checkBlocking(member: ID, completion: completion)
    }

    /// Muting members in the conversation.
    ///
    /// - Parameters:
    ///   - members: The members will be muted.
    ///   - completion: Result of callback.
    /// - Throws: When parameter `members` is empty.
    public func mute(members: Set<String>, completion: @escaping (MemberResult) -> Void) throws {
        try self.update(mutedMembers: members, op: .addShutup, completion: completion)
    }

    /// Unmuting members in the conversation.
    ///
    /// - Parameters:
    ///   - members: The members will be unmuted.
    ///   - completion: Result of callback.
    /// - Throws: When parameter `members` is empty.
    public func unmute(members: Set<String>, completion: @escaping (MemberResult) -> Void) throws {
        try self.update(mutedMembers: members, op: .removeShutup, completion: completion)
    }

    /// Get the muted members in the conversation.
    ///
    /// - Parameters:
    ///   - limit: Count limit.
    ///   - next: Offset.
    ///   - completion: Result of callback.
    /// - Throws: When parameter `limit` out of range.
    public func getMutedMembers(
        limit: Int = 50,
        next: String? = nil,
        completion: @escaping (LCGenericResult<MutedMembersResult>) -> Void)
        throws
    {
        try self._getMutedMembers(limit: limit, next: next, completion: completion)
    }

    /// Check if one member has been muted in the conversation.
    ///
    /// - Parameters:
    ///   - ID: The ID of member.
    ///   - completion: Result of callback.
    public func checkMuting(
        member ID: String,
        completion: @escaping (LCGenericResult<Bool>) -> Void)
    {
        self._checkMuting(member: ID, completion: completion)
    }

    #if canImport(GRDB)
    public func insertFailedMessageToCache(
        _ message: IMMessage,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
    {
        try self._insertFailedMessageToCache(message, completion: completion)
    }

    public func removeFailedMessageFromCache(
        _ message: IMMessage,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
    {
        try self._removeFailedMessageFromCache(message, completion: completion)
    }
    #endif
}

extension IMConversation: InternalSynchronizing {
    // MARK: Internal Synchronizing

    var mutex: NSLock {
        return self.lock
    }
}

extension IMConversation {
    // MARK: Message Sending

    /// Message Sending Option
    public struct MessageSendOptions: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Default option is empty.
        public static let `default`: MessageSendOptions = []

        /// Get Receipt when other client received message or read message.
        public static let needReceipt = MessageSendOptions(rawValue: 1 << 0)

        /// Indicates whether this message is transient.
        public static let isTransient = MessageSendOptions(rawValue: 1 << 1)

        /// Indicates whether this message will be auto delivering to other client when this client disconnected.
        public static let isAutoDeliveringWhenOffline = MessageSendOptions(rawValue: 1 << 2)
    }

    /// Send Message.
    ///
    /// - Parameters:
    ///   - message: The message to be sent. Properties such as `ID` and `sentTimeStamp` are updated.
    ///   - options: @see `MessageSendOptions`.
    ///   - priority: @see `IMChatRoom.MessagePriority`.
    ///   - pushData: The push data of APNs.
    ///   - progressQueue: The queue where the progress be called. default is main.
    ///   - progress: The file uploading progress.
    ///   - completion: callback.
    public func send(
        message: IMMessage,
        options: MessageSendOptions = .default,
        priority: IMChatRoom.MessagePriority? = nil,
        pushData: [String: Any]? = nil,
        progressQueue: DispatchQueue = .main,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
    {
        guard message.status == .none || message.status == .failed else {
            throw LCError(
                code: .inconsistency,
                reason: "only the message that status is `\(IMMessage.Status.none)` or `\(IMMessage.Status.failed)` can do sending.")
        }
        message.setup(clientID: self.clientID, conversationID: self.ID)
        message.isTransient = options.contains(.isTransient)
        message.isWill = options.contains(.isAutoDeliveringWhenOffline)
        if self.convType != .transient,
            !message.isTransient,
            !message.isWill {
            if message.dToken == nil {
                message.dToken = Utility.compactUUID
            }
            message.sendingTimestamp = Int64(Date().timeIntervalSince1970 * 1000.0)
        }
        message.update(status: .sending)
        try self.preprocess(
            message: message,
            pushData: pushData,
            progressQueue: progressQueue,
            progress: progress)
        { (client, pushDataString: String?, error: LCError?) in
            if let error = error {
                message.update(status: .failed)
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
                return
            }
            client.sendCommand(constructor: { () -> IMGenericCommand in
                var outCommand = IMGenericCommand()
                outCommand.cmd = .direct
                if let priority = priority {
                    outCommand.priority = Int32(priority.rawValue)
                }
                var directCommand = IMDirectCommand()
                directCommand.cid = self.ID
                if let content = message.content {
                    switch content {
                    case .data(let data):
                        directCommand.binaryMsg = data
                    case .string(let string):
                        directCommand.msg = string
                    }
                }
                if let mentionAll = message.isAllMembersMentioned {
                    directCommand.mentionAll = mentionAll
                }
                if let mentionPids = message.mentionedMembers {
                    directCommand.mentionPids = mentionPids
                }
                if options.contains(.needReceipt) {
                    directCommand.r = true
                }
                if let pushData = pushDataString {
                    directCommand.pushData = pushData
                }
                if message.isWill {
                    directCommand.will = true
                }
                if message.isTransient {
                    directCommand.transient = true
                }
                if let dt = message.dToken {
                    directCommand.dt = dt
                }
                outCommand.directMessage = directCommand
                return outCommand
            }, completion: { (client, result) in
                switch result {
                case .inCommand(let inCommand):
                    assert(client.specificAssertion)
                    if let ackCommand = (inCommand.hasAckMessage ? inCommand.ackMessage : nil) {
                        if let messageID = (ackCommand.hasUid ? ackCommand.uid : nil),
                            let timestamp = (ackCommand.hasT ? ackCommand.t : nil) {
                            message.update(
                                status: .sent,
                                ID: messageID,
                                timestamp: timestamp)
                        }
                        if let error = ackCommand.lcError {
                            message.update(status: .failed)
                            client.eventQueue.async {
                                completion(.failure(error: error))
                            }
                        } else {
                            self.safeUpdatingLastMessage(newMessage: message, client: client)
                            client.eventQueue.async {
                                completion(.success)
                            }
                        }
                    } else {
                        message.update(status: .failed)
                        client.eventQueue.async {
                            completion(.failure(
                                error: inCommand.ackMessage.lcError
                                    ?? LCError(code: .commandInvalid)))
                        }
                    }
                case .error(let error):
                    message.update(status: .failed)
                    client.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            })
        }
    }

    private func preprocess(
        message: IMMessage,
        pushData: [String: Any]? = nil,
        progressQueue: DispatchQueue,
        progress: ((Double) -> Void)?,
        completion: @escaping (IMClient, String?, LCError?) -> Void)
        throws
    {
        guard let client = self.client else {
            return
        }
        let pushDataString = try pushData?.jsonString()
        guard let categorizedMessage = message as? IMCategorizedMessage else {
            completion(client, pushDataString, nil)
            return
        }
        guard let file = categorizedMessage.file,
            !file.hasObjectId else {
                try categorizedMessage.encodingMessageContent(
                    application: client.application)
                completion(client, pushDataString, nil)
                return
        }
        file.save(
            progressQueue: progressQueue,
            progress: progress,
            completionQueue: client.application.httpClient
                .defaultCompletionConcurrentQueue)
        { (result) in
            switch result {
            case .success:
                do {
                    try categorizedMessage.encodingMessageContent(
                        application: client.application)
                    completion(client, pushDataString, nil)
                } catch {
                    completion(client, nil, LCError(error: error))
                }
            case .failure(error: let error):
                completion(client, nil, error)
            }
        }
    }

}

#if canImport(GRDB)
extension IMConversation {
    // MARK: Failed Message Caching

    private func _insertFailedMessageToCache(
        _ message: IMMessage,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
    {
        guard let client = self.client,
            let localStorage = client.localStorage else {
                throw LCError.clientLocalStorageNotFound
        }
        client.serialQueue.async {
            do {
                try localStorage.insertOrReplace(failedMessage: message)
                client.eventQueue.async {
                    completion(.success)
                }
            } catch {
                client.eventQueue.async {
                    completion(.failure(
                        error: LCError(error: error)))
                }
            }
        }
    }

    private func _removeFailedMessageFromCache(
        _ message: IMMessage,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
    {
        guard let client = self.client,
            let localStorage = client.localStorage else {
                throw LCError.clientLocalStorageNotFound
        }
        client.serialQueue.async {
            do {
                try localStorage.delete(failedMessage: message)
                client.eventQueue.async {
                    completion(.success)
                }
            } catch {
                client.eventQueue.async {
                    completion(.failure(
                        error: LCError(error: error)))
                }
            }
        }
    }
}
#endif

extension IMConversation {
    // MARK: Message Reading

    private func _read(message: IMMessage?) {
        guard
            self.convType != .transient,
            self.unreadMessageCount > 0,
            let message = message ?? self.lastMessage,
            let messageID = message.ID,
            let timestamp = message.sentTimestamp
        else {
            return
        }
        self.isUnreadMessageContainMention = false
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .read
            var readMessage = IMReadCommand()
            var readTuple = IMReadTuple()
            readTuple.cid = self.ID
            readTuple.mid = messageID
            readTuple.timestamp = timestamp
            readMessage.convs = [readTuple]
            outCommand.readMessage = readMessage
            return outCommand
        })
    }

    func process(unreadTuple: IMUnreadTuple, client: IMClient) {
        assert(client.specificAssertion)
        guard unreadTuple.hasUnread else {
            return
        }
        if let timestamp = (unreadTuple.hasTimestamp ? unreadTuple.timestamp : nil),
            let messageID = (unreadTuple.hasMid ? unreadTuple.mid : nil) {
            let message = IMMessage.instance(
                application: client.application,
                conversationID: self.ID,
                currentClientID: self.clientID,
                fromClientID: (unreadTuple.hasFrom ? unreadTuple.from : nil),
                timestamp: timestamp,
                patchedTimestamp: (unreadTuple.hasPatchTimestamp ? unreadTuple.patchTimestamp : nil),
                messageID: messageID,
                content: unreadTuple.lcMessageContent)
            self.safeUpdatingLastMessage(
                newMessage: message,
                client: client)
        }
        let newUnreadCount = Int(unreadTuple.unread)
        if self.unreadMessageCount != newUnreadCount {
            self.unreadMessageCount = newUnreadCount
            if let newUnreadMentioned = (unreadTuple.hasMentioned ? unreadTuple.mentioned : nil) {
                self.isUnreadMessageContainMention = newUnreadMentioned
            }
            client.eventQueue.async {
                client.delegate?.client(
                    client, conversation: self,
                    event: .unreadMessageCountUpdated)
            }
        }
    }

}

extension IMConversation {
    // MARK: Message Updating
    
    /// Update the content of a sent message.
    /// - Parameters:
    ///   - oldMessage: The sent message to be updated.
    ///   - newMessage: The message which has new content.
    ///   - progressQueue: The queue where the *progress* be called, default is main.
    ///   - progress: The file uploading progress.
    ///   - completion: Result callback.
    public func update(
        oldMessage: IMMessage,
        to newMessage: IMMessage,
        progressQueue: DispatchQueue = .main,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
    {
        try self.patch(
            oldMessage: oldMessage,
            newMessage: newMessage,
            progressQueue: progressQueue,
            progress: progress,
            completion: completion)
    }
    
    /// Recall a sent message.
    /// - Parameters:
    ///   - message: The message has been sent.
    ///   - completion: Result callback.
    public func recall(
        message: IMMessage,
        completion: @escaping (LCGenericResult<IMRecalledMessage>) -> Void)
        throws
    {
        let recalledMessage = IMRecalledMessage()
        recalledMessage.isRecall = true
        try self.patch(
            oldMessage: message,
            newMessage: recalledMessage)
        { (result) in
            switch result {
            case .success:
                completion(.success(value: recalledMessage))
            case .failure(error: let error):
                completion(.failure(error: error))
            }
        }
    }
    
    private func patch(
        oldMessage: IMMessage,
        newMessage: IMMessage,
        progressQueue: DispatchQueue = .main,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
    {
        guard let oldMessageID = oldMessage.ID,
            let oldMessageTimestamp = oldMessage.sentTimestamp,
            oldMessage.underlyingStatus == .sent else {
                throw LCError(code: .updatingMessageNotSent)
        }
        guard let oldMessageConvID = oldMessage.conversationID,
            oldMessageConvID == self.ID,
            oldMessage.fromClientID == self.clientID else {
                throw LCError(code: .updatingMessageNotAllowed)
        }
        guard newMessage.status == .none else {
            throw LCError(
                code: .inconsistency,
                reason: "the status of new message should be \(IMMessage.Status.none).")
        }
        try self.preprocess(
            message: newMessage,
            progressQueue: progressQueue,
            progress: progress)
        { (client, _, error: LCError?) in
            if let error: LCError = error {
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
                return
            }
            client.sendCommand(constructor: { () -> IMGenericCommand in
                var outCommand = IMGenericCommand()
                outCommand.cmd = .patch
                outCommand.op = .modify
                var patchMessage = IMPatchCommand()
                var patchItem = IMPatchItem()
                patchItem.cid = oldMessageConvID
                patchItem.mid = oldMessageID
                patchItem.timestamp = oldMessageTimestamp
                if let recalledMessage = newMessage as? IMRecalledMessage,
                    recalledMessage.isRecall {
                    patchItem.recall = true
                }
                if let content: IMMessage.Content = newMessage.content {
                    switch content {
                    case .data(let data):
                        patchItem.binaryMsg = data
                    case .string(let string):
                        patchItem.data = string
                    }
                }
                if let mentionAll = newMessage.isAllMembersMentioned {
                    patchItem.mentionAll = mentionAll
                }
                if let mentionPids = newMessage.mentionedMembers {
                    patchItem.mentionPids = mentionPids
                }
                patchMessage.patches = [patchItem]
                outCommand.patchMessage = patchMessage
                return outCommand
            }, completion: { (client, result) in
                switch result {
                case .inCommand(let inCommand):
                    assert(client.specificAssertion)
                    if let patchMessage = (inCommand.hasPatchMessage ? inCommand.patchMessage : nil),
                        let patchTime = (patchMessage.hasLastPatchTime ? patchMessage.lastPatchTime : nil) {
                        newMessage.setup(
                            clientID: self.clientID,
                            conversationID: self.ID)
                        newMessage.update(
                            status: .sent,
                            ID: oldMessageID,
                            timestamp: oldMessageTimestamp)
                        newMessage.patchedTimestamp = patchTime
                        newMessage.deliveredTimestamp = oldMessage.deliveredTimestamp
                        newMessage.readTimestamp = oldMessage.readTimestamp
                        self.safeUpdatingLastMessage(newMessage: newMessage, client: client)
                        #if canImport(GRDB)
                        do {
                            try client.localStorage?.updateOrIgnore(message: newMessage)
                        } catch {
                            Logger.shared.error(error)
                        }
                        #endif
                        client.eventQueue.async {
                            completion(.success)
                        }
                    } else {
                        client.eventQueue.async {
                            completion(.failure(
                                error: LCError(code: .commandInvalid)))
                        }
                    }
                case .error(let error):
                    client.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            })
        }
    }

    func process(patchItem: IMPatchItem, client: IMClient) {
        assert(client.specificAssertion)
        guard let timestamp = (patchItem.hasTimestamp ? patchItem.timestamp : nil),
            let messageID = (patchItem.hasMid ? patchItem.mid : nil) else {
                return
        }
        let patchedMessage = IMMessage.instance(
            application: client.application,
            conversationID: self.ID,
            currentClientID: self.clientID,
            fromClientID: (patchItem.hasFrom ? patchItem.from : nil),
            timestamp: timestamp,
            patchedTimestamp: (patchItem.hasPatchTimestamp ? patchItem.patchTimestamp : nil),
            messageID: messageID,
            content: patchItem.lcMessageContent,
            isAllMembersMentioned: (patchItem.hasMentionAll ? patchItem.mentionAll : nil),
            mentionedMembers: (patchItem.mentionPids.isEmpty ? nil : patchItem.mentionPids))
        if patchItem.hasRecall,
            patchItem.recall,
            let recalledMessage = patchedMessage as? IMRecalledMessage {
            recalledMessage.isRecall = true
        }
        self.safeUpdatingLastMessage(
            newMessage: patchedMessage,
            client: client)
        #if canImport(GRDB)
        do {
            try client.localStorage?.updateOrIgnore(message: patchedMessage)
        } catch {
            Logger.shared.error(error)
        }
        #endif
        var reason: IMMessage.PatchedReason?
        if patchItem.hasPatchCode || patchItem.hasPatchReason {
            reason = IMMessage.PatchedReason(
                code: (patchItem.hasPatchCode ? Int(patchItem.patchCode) : nil),
                reason: (patchItem.hasPatchReason ? patchItem.patchReason : nil))
        }
        client.eventQueue.async {
            client.delegate?.client(
                client, conversation: self,
                event: .message(
                    event: .updated(updatedMessage: patchedMessage, reason: reason)))
        }
    }
}

extension IMConversation {
    // MARK: Message Receipt Timestamp

    /// The timestamp flag of message receipt.
    public struct MessageReceiptFlag {

        /// Means the messages that its sent timestamp less than this flag timestamp has been read.
        public let readFlagTimestamp: Int64?

        /// Date format of the `readFlagTimestamp`.
        public var readFlagDate: Date? {
            return IMClient.date(fromMillisecond: self.readFlagTimestamp)
        }

        /// Means the messages that its sent timestamp less than this flag timestamp has been delivered.
        public let deliveredFlagTimestamp: Int64?

        /// Date format of the `deliveredFlagTimestamp`.
        public var deliveredFlagDate: Date? {
            return IMClient.date(fromMillisecond: self.deliveredFlagTimestamp)
        }
    }

    private func _getMessageReceiptFlag(completion: ((LCGenericResult<MessageReceiptFlag>) -> Void)? = nil) throws {
        if let options = self.client?.options {
            guard options.isProtobuf3 else {
                throw LCError(
                    code: .inconsistency,
                    reason: "Not support, client options not contains \(IMClient.Options.receiveUnreadMessageCountAfterSessionDidOpen).")
            }
        }
        guard
            self.convType != .transient,
            self.convType != .system
        else {
            let convClassName = (self.convType == .transient)
                ? "\(IMChatRoom.self)"
                : "\(IMServiceConversation.self)"
            throw LCError(
                code: .inconsistency,
                reason: "\(convClassName) NOT support this function.")
        }
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .maxRead
            var convCommand = IMConvCommand()
            convCommand.cid = self.ID
            outCommand.convMessage = convCommand
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                let rcpResult: LCGenericResult<MessageReceiptFlag>
                if let convMessage = (inCommand.hasConvMessage ? inCommand.convMessage : nil) {
                    let maxReadTimestamp = (convMessage.hasMaxReadTimestamp
                        ? convMessage.maxReadTimestamp
                        : nil)
                    let maxDeliveredTimestamp = (convMessage.hasMaxAckTimestamp
                        ? convMessage.maxAckTimestamp
                        : nil)
                    self.process(
                        maxReadTimestamp: maxReadTimestamp,
                        maxDeliveredTimestamp: maxDeliveredTimestamp,
                        client: client)
                    rcpResult = .success(
                        value: MessageReceiptFlag(
                            readFlagTimestamp: maxReadTimestamp,
                            deliveredFlagTimestamp: maxDeliveredTimestamp))
                } else {
                    rcpResult = .failure(
                        error: LCError(
                            code: .commandInvalid))
                }
                if let completion = completion {
                    client.eventQueue.async {
                        completion(rcpResult)
                    }
                }
            case .error(let error):
                if let completion = completion {
                    client.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            }
        })
    }

    private func process(
        maxReadTimestamp: Int64?,
        maxDeliveredTimestamp: Int64?,
        client: IMClient)
    {
        assert(client.specificAssertion)
        if let maxReadTimestamp = maxReadTimestamp,
            maxReadTimestamp > (self.lastReadTimestamp ?? 0) {
            self.lastReadTimestamp = maxReadTimestamp
            client.eventQueue.async {
                client.delegate?.client(
                    client, conversation: self,
                    event: .lastReadAtUpdated)
            }
        }
        if let maxDeliveredTimestamp = maxDeliveredTimestamp,
            maxDeliveredTimestamp > (self.lastDeliveredTimestamp ?? 0) {
            self.lastDeliveredTimestamp = maxDeliveredTimestamp
            client.eventQueue.async {
                client.delegate?.client(
                    client, conversation: self,
                    event: .lastDeliveredAtUpdated)
            }
        }
    }
}

extension IMConversation {
    // MARK: Message Query

    /// The limit of the messge query result.
    public static let limitRangeOfMessageQuery = 1...100

    /// The endpoint of the message queue.
    public struct MessageQueryEndpoint {

        /// The ID of the endpoint(message).
        public let messageID: String?

        /// The sent timestamp of the endpoint(message).
        public let sentTimestamp: Int64?

        /// Interval open or closed.
        public let isClosed: Bool?

        /// Initialization.
        public init(messageID: String?, sentTimestamp: Int64?, isClosed: Bool?) {
            self.messageID = messageID
            self.sentTimestamp = sentTimestamp
            self.isClosed = isClosed
        }
    }

    /// The query direction.
    public enum MessageQueryDirection: Int {
        case newToOld = 1
        case oldToNew = 2

        var protobufEnum: IMLogsCommand.QueryDirection {
            switch self {
            case .newToOld:
                return .old
            case .oldToNew:
                return .new
            }
        }

        var SQLOrder: String {
            switch self {
            case .newToOld:
                return "desc"
            case .oldToNew:
                return "asc"
            }
        }
    }

    /// Policy of Message Query
    ///
    /// - `default`: If using local storage, it is `cacheThenNetwork`. If not using local storage, it is `onlyNetwork`.
    /// - onlyNetwork: Only query remote server
    /// - onlyCache: Only query local storage
    /// - cacheThenNetwork: Query local storage firstly, if not get result, then query remote server.
    public enum MessageQueryPolicy {
        case `default`
        case onlyNetwork
        #if canImport(GRDB)
        case onlyCache
        case cacheThenNetwork
        #endif
    }

    /// Message Query.
    ///
    /// - Parameters:
    ///   - start: start endpoint, @see `MessageQueryEndpoint`.
    ///   - end: end endpoint, @see `MessageQueryEndpoint`.
    ///   - direction: @see `MessageQueryDirection`. default is `MessageQueryDirection.newToOld`.
    ///   - limit: The limit of the query result, should in range `limitRangeOfMessageQuery`. default is 20.
    ///   - type: @see `IMMessageCategorizing.MessageType`. if this parameter did set, `policy` will always be `.onlyNetwork`.
    ///   - policy: @see `IMConversation.MessageQueryPolicy`. if `client.options` contains `.usingLocalStorage`, then default is `.cacheThenNetwork`, else default is `.onlyNetwork`.
    ///   - completion: callback.
    public func queryMessage(
        start: MessageQueryEndpoint? = nil,
        end: MessageQueryEndpoint? = nil,
        direction: MessageQueryDirection? = nil,
        limit: Int = 20,
        type: IMMessageCategorizing.MessageType? = nil,
        policy: MessageQueryPolicy = .default,
        completion: @escaping (LCGenericResult<[IMMessage]>) -> Void)
        throws
    {
        guard IMConversation.limitRangeOfMessageQuery.contains(limit) else {
            throw LCError(
                code: .inconsistency,
                reason: "limit should in range \(IMConversation.limitRangeOfMessageQuery).")
        }
        var realPolicy: MessageQueryPolicy = policy
        if [.transient, .temporary].contains(self.convType) || type != nil {
            realPolicy = .onlyNetwork
        } else if realPolicy == .default {
            #if canImport(GRDB)
            if let client = self.client,
                client.options.contains(.usingLocalStorage) {
                realPolicy = .cacheThenNetwork
            } else {
                realPolicy = .onlyNetwork
            }
            #else
            realPolicy = .onlyNetwork
            #endif
        }
        switch realPolicy {
        case .default:
            fatalError("should never happen")
        case .onlyNetwork:
            self.queryMessageOnlyNetwork(
                start: start,
                end: end,
                direction: direction,
                limit: limit,
                type: type)
            { (client, result) in
                client.eventQueue.async {
                    completion(result)
                }
            }
            #if canImport(GRDB)
        case .onlyCache:
            guard let client = self.client,
                let localStorage = client.localStorage else {
                    throw LCError.clientLocalStorageNotFound
            }
            self.queryMessageOnlyCache(
                client: client,
                localStorage: localStorage,
                start: start,
                end: end,
                direction: direction,
                limit: limit)
            { (client, result, _) in
                client.eventQueue.async {
                    completion(result)
                }
            }
        case .cacheThenNetwork:
            guard let client = self.client,
                let localStorage = client.localStorage else {
                    throw LCError.clientLocalStorageNotFound
            }
            self.queryMessageOnlyCache(
                client: client,
                localStorage: localStorage,
                start: start,
                end: end,
                direction: direction,
                limit: limit)
            { (client, result, hasBreakpoint) in
                var shouldUseNetwork = (hasBreakpoint || result.isFailure)
                if !shouldUseNetwork,
                    let value = result.value {
                    shouldUseNetwork = (value.count != limit)
                }
                if shouldUseNetwork {
                    self.queryMessageOnlyNetwork(
                        start: start,
                        end: end,
                        direction: direction,
                        limit: limit,
                        type: type)
                    { (client, result) in
                        client.eventQueue.async {
                            completion(result)
                        }
                    }
                } else {
                    client.eventQueue.async {
                        completion(result)
                    }
                }
            }
            #endif
        }
    }

    private func queryMessageOnlyNetwork(
        start: MessageQueryEndpoint?,
        end: MessageQueryEndpoint?,
        direction: MessageQueryDirection?,
        limit: Int?,
        type: IMMessageCategorizing.MessageType?,
        completion: @escaping (IMClient, LCGenericResult<[IMMessage]>) -> Void)
    {
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            return self.messageQueryCommand(
                start: start,
                end: end,
                direction: direction,
                limit: limit,
                type: type
            )
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                do {
                    let messages = try self.handleMessageQueryResult(command: inCommand, client: client)
                    #if canImport(GRDB)
                    if [.normal, .system].contains(self.convType),
                        let localStorage = client.localStorage {
                        do {
                            try localStorage.insertOrReplace(messages: messages)
                        } catch {
                            Logger.shared.error(error)
                        }
                    }
                    #endif
                    completion(client, .success(value: messages))
                } catch {
                    completion(client, .failure(error: LCError(error: error)))
                }
            case .error(let error):
                completion(client, .failure(error: error))
            }
        })
    }

    #if canImport(GRDB)
    private func queryMessageOnlyCache(
        client: IMClient,
        localStorage: IMLocalStorage,
        start: MessageQueryEndpoint?,
        end: MessageQueryEndpoint?,
        direction: MessageQueryDirection?,
        limit: Int,
        completion: @escaping (IMClient, LCGenericResult<[IMMessage]>, Bool) -> Void)
    {
        client.serialQueue.async {
            do {
                let result = try localStorage.selectMessages(
                    client: client,
                    conversationID: self.ID,
                    start: start,
                    end: end,
                    direction: direction,
                    limit: limit)
                completion(client, .success(value: result.messages), result.hasBreakpoint)
            } catch {
                completion(client, .failure(error: LCError(error: error)), true)
            }
        }
    }
    #endif

    private func messageQueryCommand(
        start: MessageQueryEndpoint?,
        end: MessageQueryEndpoint?,
        direction: MessageQueryDirection?,
        limit: Int?,
        type: IMMessageCategorizing.MessageType?)
        -> IMGenericCommand
    {
        var outCommand = IMGenericCommand()
        outCommand.cmd = .logs
        var logCommand = IMLogsCommand()
        logCommand.cid = self.ID
        if let endpoint = start {
            if let mid = endpoint.messageID {
                logCommand.mid = mid
            }
            if let t = endpoint.sentTimestamp {
                logCommand.t = t
            }
            if let tIncluded = endpoint.isClosed {
                logCommand.tIncluded = tIncluded
            }
        }
        if let endpoint = end {
            if let tmid = endpoint.messageID {
                logCommand.tmid = tmid
            }
            if let tt = endpoint.sentTimestamp {
                logCommand.tt = tt
            }
            if let ttIncluded = endpoint.isClosed {
                logCommand.ttIncluded = ttIncluded
            }
        }
        if let direction = direction {
            logCommand.direction = direction.protobufEnum
        }
        if let limit = limit {
            logCommand.limit = Int32(limit)
        }
        if let type = type {
            logCommand.lctype = Int32(type)
        }
        outCommand.logsMessage = logCommand
        return outCommand
    }

    private func handleMessageQueryResult(command: IMGenericCommand, client: IMClient) throws -> [IMMessage] {
        guard command.hasLogsMessage else {
            throw LCError(code: .commandInvalid)
        }
        var messages: [IMMessage] = []
        for item in command.logsMessage.logs {
            guard let messageID = (item.hasMsgID ? item.msgID : nil),
                let timestamp = (item.hasTimestamp ? item.timestamp : nil) else {
                    continue
            }
            let message = IMMessage.instance(
                application: client.application,
                conversationID: self.ID,
                currentClientID: client.ID,
                fromClientID: (item.hasFrom ? item.from : nil),
                timestamp: timestamp,
                patchedTimestamp: (item.hasPatchTimestamp ? item.patchTimestamp : nil),
                messageID: messageID,
                content: item.lcMessageContent,
                isAllMembersMentioned: (item.hasMentionAll ? item.mentionAll : nil),
                mentionedMembers: (item.mentionPids.isEmpty ? nil : item.mentionPids))
            message.deliveredTimestamp = (item.hasAckAt ? item.ackAt : nil)
            message.readTimestamp = (item.hasReadAt ? item.readAt : nil)
            messages.append(message)
        }
        if let newestMessage = messages.last {
            self.safeUpdatingLastMessage(
                newMessage: newestMessage,
                client: client)
        }
        return messages
    }

}

extension IMConversation {
    // MARK: Conversation Member

    /// Result for member operation.
    ///
    /// - allSucceeded: Operation for all members are succeeded.
    /// - failure: Operation failed.
    /// - slicing: Operation for part members are succeeded, and for part members are failed.
    public enum MemberResult: LCResultType {
        case allSucceeded
        case failure(error: LCError)
        case slicing(success: [String]?, failure: [(IDs: [String], error: LCError)])

        public var isSuccess: Bool {
            switch self {
            case .allSucceeded:
                return true
            default:
                return false
            }
        }

        public var error: LCError? {
            switch self {
            case .failure(error: let error):
                return error
            default:
                return nil
            }
        }

        public init(error: LCError) {
            self = .failure(error: error)
        }
    }

    private func newConvAddRemoveCommand(
        members: Set<String>,
        op: IMOpType,
        signature: IMSignature? = nil)
        -> IMGenericCommand
    {
        assert(op == .add || op == .remove)
        var outCommand = IMGenericCommand()
        outCommand.cmd = .conv
        outCommand.op = op
        var convCommand = IMConvCommand()
        convCommand.cid = self.ID
        convCommand.m = Array<String>(members)
        if let signature = signature {
            convCommand.s = signature.signature
            convCommand.t = signature.timestamp
            convCommand.n = signature.nonce
        }
        outCommand.convMessage = convCommand
        return outCommand
    }

    private func getConvAddRemoveCommand(
        members: Set<String>,
        op: IMOpType,
        completion: @escaping (IMClient, IMGenericCommand) -> Void)
    {
        guard let client = self.client else {
            return
        }
        if self.convType != .temporary,
            let signatureDelegate = client.signatureDelegate {
            let action: IMSignature.Action
            if op == .add {
                action = .add(
                    memberIDs: members,
                    toConversation: self)
            } else {
                action = .remove(
                    memberIDs: members,
                    fromConversation: self)
            }
            client.eventQueue.async {
                signatureDelegate.client(
                    client, action: action)
                { (client, signature) in
                    client.serialQueue.async {
                        completion(client, self.newConvAddRemoveCommand(
                            members: members,
                            op: op,
                            signature: signature))
                    }
                }
            }
        } else {
            completion(client, self.newConvAddRemoveCommand(
                members: members,
                op: op))
        }
    }

    private func update(members: Set<String>, op: IMOpType, completion: @escaping (MemberResult) -> Void) throws {
        assert(op == .add || op == .remove)
        guard !members.isEmpty else {
            throw LCError(code: .inconsistency, reason: "parameter `members` should not be empty.")
        }
        for memberID in members {
            guard IMClient.lengthRangeOfClientID.contains(memberID.count) else {
                throw LCError.clientIDInvalid
            }
        }
        self.getConvAddRemoveCommand(members: members, op: op) { (client, outCommand) in
            client.sendCommand(constructor: { outCommand }, completion: { (client, result) in
                switch result {
                case .inCommand(let inCommand):
                    assert(client.specificAssertion)
                    guard let convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil) else {
                        client.eventQueue.async {
                            completion(.failure(error: LCError(code: .commandInvalid)))
                        }
                        return
                    }
                    let allowedPids: [String] = convCommand.allowedPids
                    let failedPids: [IMErrorCommand] = convCommand.failedPids
                    let udate: String? = (convCommand.hasUdate ? convCommand.udate : nil)
                    let memberResult: MemberResult
                    if failedPids.isEmpty {
                        memberResult = .allSucceeded
                    } else {
                        let successIDs = (allowedPids.isEmpty ? nil : allowedPids)
                        var failures: [([String], LCError)] = []
                        for errCommand in failedPids {
                            failures.append((errCommand.pids, errCommand.lcError))
                        }
                        memberResult = .slicing(success: successIDs, failure: failures)
                    }
                    switch inCommand.op {
                    case .added:
                        self.safeExecuting(
                            operation: .append(members: allowedPids, udate: udate),
                            client: client
                        )
                    case .removed:
                        self.safeExecuting(
                            operation: .remove(members: allowedPids, udate: udate),
                            client: client
                        )
                    default:
                        break
                    }
                    client.eventQueue.async {
                        completion(memberResult)
                    }
                case .error(let error):
                    client.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            })
        }
    }
    
    private func _countMembers(completion: @escaping (LCCountResult) -> Void) {
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .count
            var convCommand = IMConvCommand()
            convCommand.cid = self.ID
            outCommand.convMessage = convCommand
            return outCommand
        }) { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                if inCommand.hasConvMessage,
                    inCommand.convMessage.hasCount {
                    client.eventQueue.async {
                        completion(.success(
                            count: Int(inCommand.convMessage.count)))
                    }
                } else {
                    client.eventQueue.async {
                        completion(.failure(
                            error: LCError(
                                code: .commandInvalid)))
                    }
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(
                        error: error))
                }
            }
        }
    }
    
    func _checkJoined(completion: @escaping (LCGenericResult<Bool>) -> Void) {
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .isMember
            var convCommand = IMConvCommand()
            convCommand.cids = [self.ID]
            outCommand.convMessage = convCommand
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                do {
                    if let convMessage = (inCommand.hasConvMessage ? inCommand.convMessage : nil),
                        let jsonObject = (convMessage.hasResults ? convMessage.results : nil),
                        let dataString = (jsonObject.hasData ? jsonObject.data : nil),
                        let results: [String: Any] = try dataString.jsonObject(),
                        let boolValue = results[self.ID] as? Bool {
                        client.eventQueue.async {
                            completion(.success(
                                value: boolValue))
                        }
                    } else {
                        client.eventQueue.async {
                            completion(.failure(
                                error: LCError(
                                    code: .commandInvalid)))
                        }
                    }
                } catch {
                    client.eventQueue.async {
                        completion(.failure(
                            error: LCError(
                                error: error)))
                    }
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(
                        error: error))
                }
            }
        })
    }
}

extension IMConversation {
    // MARK: Conversation Mute

    private func muteToggle(op: IMOpType, completion: @escaping (LCBooleanResult) -> Void) {
        assert(op == .mute || op == .unmute)
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = op
            var convMessage = IMConvCommand()
            convMessage.cid = self.ID
            outCommand.convMessage = convMessage
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                if inCommand.hasConvMessage {
                    let convMessage = inCommand.convMessage
                    self.safeUpdatingMutedMembers(
                        op: op,
                        udate: (convMessage.hasUdate ? convMessage.udate : nil),
                        client: client
                    )
                    client.eventQueue.async {
                        completion(.success)
                    }
                } else {
                    let error = LCError(code: .commandInvalid)
                    client.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        })
    }

}

extension IMConversation {
    // MARK: Member Info

    /// Role of the member in the conversation.
    /// Privilege: owner > manager > member.
    ///
    /// - owner: Who owns the conversation.
    /// - manager: Who can manage the conversation.
    /// - member: General member.
    public enum MemberRole: String {
        case owner = "Owner"
        case manager = "Manager"
        case member = "Member"
    }

    /// The infomation of one member in the conversation.
    public struct MemberInfo {

        /// The ID of the member.
        public let ID: String

        /// The role of the member.
        public let role: MemberRole

        let conversationID: String

        init?(rawData: [String: Any], creator: String?) {
            guard
                let clientId: String = rawData["clientId"] as? String,
                let cid: String = rawData["cid"] as? String,
                let role: String = rawData["role"] as? String else
            {
                return nil
            }
            self.ID = clientId
            if let creator = creator, creator == clientId {
                self.role = .owner
            } else {
                switch role {
                case "Manager":
                    self.role = .manager
                default:
                    return nil
                }
            }
            self.conversationID = cid
        }

        init(ID: String, role: MemberRole, conversationID: String, creator: String?) {
            self.ID = ID
            if let creator = creator, creator == ID {
                self.role = .owner
            } else {
                self.role = role
            }
            self.conversationID = conversationID
        }
    }

    private func _fetchMemberInfoTable(completion: @escaping (IMClient, LCBooleanResult) -> Void) {
        self.client?.serialQueue.async {
            self.client?.getSessionToken(completion: { (client, result) in
                assert(client.specificAssertion)
                switch result {
                case .success(value: let token):
                    let header: [String: String] = [
                        "X-LC-IM-Session-Token": token,
                    ]
                    let parameters: [String: Any] = [
                        "client_id": client.ID,
                        "cid": self.ID,
                    ]
                    _ = client.application.httpClient.request(
                        .get, "classes/_ConversationMemberInfo",
                        parameters: parameters,
                        headers: header)
                    { (response) in
                        if let error = LCError(response: response) {
                            completion(client, .failure(error: error))
                        } else if let results = response.results as? [[String: Any]] {
                            let creator = self.creator
                            var table: [String: MemberInfo] = [:]
                            for rawData in results {
                                if let info = MemberInfo(rawData: rawData, creator: creator) {
                                    table[info.ID] = info
                                }
                            }
                            self.sync(self._memberInfoTable = table)
                            completion(client, .success)
                        } else {
                            completion(client, .failure(error: LCError(code: .malformedData)))
                        }
                    }
                case .failure(error: let error):
                    completion(client, .failure(error: error))
                }
            })
        }
    }

    private func _update(role: MemberRole, ofMember memberID: String, completion: @escaping (LCBooleanResult) -> Void) throws {
        guard role != .owner else {
            throw LCError(code: LCError.InternalErrorCode.ownerPromotionNotAllowed)
        }
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .memberInfoUpdate
            var convCommand = IMConvCommand()
            convCommand.cid = self.ID
            convCommand.targetClientID = memberID
            var convMemberInfo = IMConvMemberInfo()
            convMemberInfo.pid = memberID
            convMemberInfo.role = role.rawValue
            convCommand.info = convMemberInfo
            outCommand.convMessage = convCommand
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                guard inCommand.cmd == .conv, inCommand.op == .memberInfoUpdated else {
                    client.eventQueue.async {
                        completion(.failure(error: LCError(code: .commandInvalid)))
                    }
                    return
                }
                let info = MemberInfo(
                    ID: memberID,
                    role: role,
                    conversationID: self.ID,
                    creator: self.creator)
                self.sync(self._memberInfoTable?[info.ID] = info)
                client.eventQueue.async {
                    completion(.success)
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        })
    }

}

extension IMConversation {
    // MARK: Member Blacklist

    private func newBlacklistBlockUnblockCommand(
        members: Set<String>,
        op: IMOpType,
        signature: IMSignature? = nil)
        -> IMGenericCommand
    {
        assert(op == .block || op == .unblock)
        var command = IMGenericCommand()
        command.cmd = .blacklist
        command.op = op
        var blacklistCommand = IMBlacklistCommand()
        blacklistCommand.srcCid = self.ID
        blacklistCommand.toPids = Array(members)
        if let signature = signature {
            blacklistCommand.s = signature.signature
            blacklistCommand.t = signature.timestamp
            blacklistCommand.n = signature.nonce
        }
        command.blacklistMessage = blacklistCommand
        return command
    }

    private func getBlacklistBlockUnblockCommand(
        members: Set<String>,
        op: IMOpType,
        completion: @escaping (IMClient, IMGenericCommand) -> Void)
    {
        guard let client = self.client else {
            return
        }
        if self.convType != .temporary,
            let signatureDelegate = client.signatureDelegate {
            let action: IMSignature.Action
            if op == .block {
                action = .conversationBlocking(
                    self, blockedMemberIDs: members)
            } else {
                action = .conversationUnblocking(
                    self, unblockedMemberIDs: members)
            }
            client.eventQueue.async {
                signatureDelegate.client(
                    client, action: action)
                { (client, signature) in
                    client.serialQueue.async {
                        completion(client, self.newBlacklistBlockUnblockCommand(
                            members: members,
                            op: op,
                            signature: signature))
                    }
                }
            }
        } else {
            completion(client, self.newBlacklistBlockUnblockCommand(
                members: members,
                op: op))
        }
    }

    private func update(
        blockedMembers members: Set<String>,
        op: IMOpType,
        completion: @escaping (MemberResult) -> Void)
        throws
    {
        guard !members.isEmpty else {
            throw LCError(code: .inconsistency, reason: "parameter `members` should not be empty.")
        }
        self.getBlacklistBlockUnblockCommand(members: members, op: op) { (client, outCommand) in
            client.sendCommand(constructor: { () -> IMGenericCommand in
                outCommand
            }, completion: { (client, result) in
                switch result {
                case .inCommand(let inCommand):
                    assert(client.specificAssertion)
                    guard let blacklistMessage = (inCommand.hasBlacklistMessage ? inCommand.blacklistMessage : nil) else {
                        client.eventQueue.async {
                            completion(.failure(error: LCError(code: .commandInvalid)))
                        }
                        return
                    }
                    let allowedPids: [String] = blacklistMessage.allowedPids
                    let failedPids: [IMErrorCommand] = blacklistMessage.failedPids

                    let memberResult: MemberResult
                    if failedPids.isEmpty {
                        memberResult = .allSucceeded
                    } else {
                        let successIDs = (allowedPids.isEmpty ? nil : allowedPids)
                        var failures: [([String], LCError)] = []
                        for errCommand in failedPids {
                            failures.append((errCommand.pids, errCommand.lcError))
                        }
                        memberResult = .slicing(success: successIDs, failure: failures)
                    }

                    client.eventQueue.async {
                        completion(memberResult)
                    }
                case .error(let error):
                    client.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            })
        }
    }

    public typealias BlockedMembersResult = (members: [String], next: String?)

    private func _getBlockedMembers(
        limit: Int,
        next: String?,
        completion: @escaping (LCGenericResult<BlockedMembersResult>) -> Void)
        throws
    {
        let limitRange: ClosedRange<Int> = 1...100
        guard limitRange.contains(limit) else {
            throw LCError(code: .inconsistency, reason: "parameter `limit` should in range \(limitRange)")
        }
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .blacklist
            outCommand.op = .query
            var blacklistCommand = IMBlacklistCommand()
            blacklistCommand.srcCid = self.ID
            blacklistCommand.limit = Int32(limit)
            if let next = next {
                blacklistCommand.next = next
            }
            outCommand.blacklistMessage = blacklistCommand
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                guard let blacklistMessage = (inCommand.hasBlacklistMessage ? inCommand.blacklistMessage : nil) else {
                    client.eventQueue.async {
                        completion(.failure(error: LCError(code: .commandInvalid)))
                    }
                    return
                }
                let members = blacklistMessage.blockedPids
                let next = (blacklistMessage.hasNext ? blacklistMessage.next : nil)
                client.eventQueue.async {
                    completion(.success(value: (members, next)))
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        })
    }

    private func _checkBlocking(
        member ID: String,
        completion: @escaping (LCGenericResult<Bool>) -> Void)
    {
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .blacklist
            outCommand.op = .checkBlock
            var blacklistCommand = IMBlacklistCommand()
            blacklistCommand.srcCid = self.ID
            blacklistCommand.toPids = [ID]
            outCommand.blacklistMessage = blacklistCommand
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                guard let blacklistMessage = (inCommand.hasBlacklistMessage ? inCommand.blacklistMessage : nil) else {
                    client.eventQueue.async {
                        completion(.failure(error: LCError(code: .commandInvalid)))
                    }
                    return
                }
                let isBlocked = blacklistMessage.blockedPids.contains(ID)
                client.eventQueue.async {
                    completion(.success(value: isBlocked))
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        })
    }

}

extension IMConversation {
    // MARK: Member Shutup

    private func update(
        mutedMembers members: Set<String>,
        op: IMOpType,
        completion: @escaping (MemberResult) -> Void)
        throws
    {
        assert(op == .addShutup || op == .removeShutup)
        guard !members.isEmpty else {
            throw LCError(code: .inconsistency, reason: "parameter `members` should not be empty.")
        }
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = op
            var convCommand = IMConvCommand()
            convCommand.cid = self.ID
            convCommand.m = Array(members)
            outCommand.convMessage = convCommand
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                guard let convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil) else {
                    client.eventQueue.async {
                        completion(.failure(error: LCError(code: .commandInvalid)))
                    }
                    return
                }
                let allowedPids: [String] = convCommand.allowedPids
                let failedPids: [IMErrorCommand] = convCommand.failedPids

                let memberResult: MemberResult
                if failedPids.isEmpty {
                    memberResult = .allSucceeded
                } else {
                    let successIDs = (allowedPids.isEmpty ? nil : allowedPids)
                    var failures: [([String], LCError)] = []
                    for errCommand in failedPids {
                        failures.append((errCommand.pids, errCommand.lcError))
                    }
                    memberResult = .slicing(success: successIDs, failure: failures)
                }

                client.eventQueue.async {
                    completion(memberResult)
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        })
    }

    public typealias MutedMembersResult = (members: [String], next: String?)

    private func _getMutedMembers(
        limit: Int,
        next: String?,
        completion: @escaping (LCGenericResult<MutedMembersResult>) -> Void)
        throws
    {
        let limitRange: ClosedRange<Int> = 1...100
        guard limitRange.contains(limit) else {
            throw LCError(code: .inconsistency, reason: "parameter `limit` should in range \(limitRange)")
        }
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .queryShutup
            var convCommand = IMConvCommand()
            convCommand.cid = self.ID
            convCommand.limit = Int32(limit)
            if let next = next {
                convCommand.next = next
            }
            outCommand.convMessage = convCommand
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                guard let convMessage = (inCommand.hasConvMessage ? inCommand.convMessage : nil) else {
                    client.eventQueue.async {
                        completion(.failure(error: LCError(code: .commandInvalid)))
                    }
                    return
                }
                let members = convMessage.m
                let next = (convMessage.hasNext ? convMessage.next : nil)
                client.eventQueue.async {
                    completion(.success(value: (members, next)))
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        })
    }

    private func _checkMuting(
        member ID: String,
        completion: @escaping (LCGenericResult<Bool>) -> Void)
    {
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .checkShutup
            var convCommand = IMConvCommand()
            convCommand.cid = self.ID
            convCommand.m = [ID]
            outCommand.convMessage = convCommand
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                guard let convMessage = (inCommand.hasConvMessage ? inCommand.convMessage : nil) else {
                    client.eventQueue.async {
                        completion(.failure(error: LCError(code: .commandInvalid)))
                    }
                    return
                }
                let isMuted = convMessage.m.contains(ID)
                client.eventQueue.async {
                    completion(.success(value: isMuted))
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        })
    }

}

extension IMConversation {
    // MARK: Conversation Data Updating

    private func _refresh(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self.client?.conversationQuery.getConversation(by: self.ID, completion: { (result) in
            switch result {
            case .success(value: _):
                completion(.success)
            case .failure(error: let error):
                completion(.failure(error: error))
            }
        })
    }

    private func _update(attribution data: [String: Any], completion: @escaping (LCBooleanResult) -> Void) throws {
        guard !data.isEmpty else {
            throw LCError(code: .inconsistency, reason: "parameter invalid.")
        }
        let binaryData = try JSONSerialization.data(withJSONObject: data)
        guard let jsonString = String(data: binaryData, encoding: .utf8) else {
            throw LCError(code: .inconsistency, reason: "parameter invalid.")
        }
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .update
            var convCommand = IMConvCommand()
            convCommand.cid = self.ID
            var jsonObject = IMJsonObjectMessage()
            jsonObject.data = jsonString
            convCommand.attr = jsonObject
            outCommand.convMessage = convCommand
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                guard
                    let convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil),
                    let jsonCommand = (convCommand.hasAttrModified ? convCommand.attrModified : nil),
                    let attrModifiedString = (jsonCommand.hasData ? jsonCommand.data : nil)
                    else
                {
                    client.eventQueue.async {
                        let error = LCError(code: .commandInvalid)
                        completion(.failure(error: error))
                    }
                    return
                }
                do {
                    if let attrModified: [String: Any] = try attrModifiedString.jsonObject(),
                        let udate: String = (convCommand.hasUdate ? convCommand.udate : nil) {
                        self.safeExecuting(
                            operation: .updated(attr: data, attrModified: attrModified, udate: udate),
                            client: client
                        )
                        client.eventQueue.async {
                            completion(.success)
                        }
                    } else {
                        client.eventQueue.async {
                            let error = LCError(code: .commandInvalid)
                            completion(.failure(error: error))
                        }
                    }
                } catch {
                    let err = LCError(error: error)
                    client.eventQueue.async {
                        completion(.failure(error: err))
                    }
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        })
    }

    private func operationRawDataMerging(data: RawData, client: IMClient) {
        guard !data.isEmpty else {
            return
        }
        let rawData = self.sync(closure: { () -> RawData in
            self._rawData.merge(data) { (_, new) in new }
            return self._rawData
        })
        #if canImport(GRDB)
        self.tryUpdateLocalStorageData(client: client, rawData: rawData)
        #endif
    }

    private func operationRawDataReplaced(data: RawData, client: IMClient) {
        self.sync(closure: {
            self._rawData = data
            self._isOutdated = false
        })
        if let message = self.decodingLastMessage(data: data, client: client) {
            self.safeUpdatingLastMessage(newMessage: message, client: client)
        }
        #if canImport(GRDB)
        do {
            try client.localStorage?.insertOrReplace(
                conversationID: self.ID,
                rawData: data,
                convType: self.convType)
        } catch {
            Logger.shared.error(error)
        }
        #endif
    }

    private func needUpdateMembers(members: [String], updatedDateString: String?) -> Bool {
        if (self.convType == .transient) ||
            (self.convType != .system && members.isEmpty) {
            return false
        }
        if let updatedDateString = updatedDateString,
            let newUpdatedDate = LCDate.dateFromString(updatedDateString) {
            if let originUpdatedDate = self.updatedAt ?? self.createdAt {
                return (newUpdatedDate >= originUpdatedDate)
            } else {
                return true
            }
        } else {
            return false
        }
    }

    private func operationAppend(members joinedMembers: [String], udate: String?, client: IMClient) {
        guard self.needUpdateMembers(members: joinedMembers, updatedDateString: udate) else {
            return
        }
        if self.convType == .system {
            self.safeUpdatingRawData(key: .joined, value: true)
        } else {
            let newMembers: [String]
            if var originMembers: [String] = self.members {
                for member in joinedMembers {
                    if !originMembers.contains(member) {
                        originMembers.append(member)
                    }
                }
                newMembers = originMembers
            } else {
                newMembers = joinedMembers
            }
            self.safeUpdatingRawData(key: .members, value: newMembers)
        }
        let rawData = self.sync(closure: { () -> RawData in
            if let udate = udate {
                self.updatingRawData(key: .updatedAt, value: udate)
            }
            return self._rawData
        })
        #if canImport(GRDB)
        if let _ = client.localStorage {
            self.tryUpdateLocalStorageData(
                client: client,
                rawData: rawData)
        }
        #endif
    }

    private func operationRemove(members leftMembers: [String], udate: String?, client: IMClient) {
        guard self.needUpdateMembers(members: leftMembers, updatedDateString: udate) else {
            return
        }
        if self.convType == .system {
            self.safeUpdatingRawData(key: .joined, value: false)
        } else {
            if leftMembers.contains(self.clientID) {
                self.isOutdated = true
            }
            if var originMembers: [String] = self.members {
                for member in leftMembers {
                    if let index = originMembers.firstIndex(of: member) {
                        originMembers.remove(at: index)
                    }
                }
                self.safeUpdatingRawData(key: .members, value: originMembers)
            }
            self.sync(closure: {
                if let _ = self._memberInfoTable {
                    for member in leftMembers {
                        self._memberInfoTable?.removeValue(forKey: member)
                    }
                }
            })
        }
        let tuple = self.sync(closure: { () -> (RawData, Bool) in
            if let udate = udate {
                self.updatingRawData(key: .updatedAt, value: udate)
            }
            return (self._rawData, self._isOutdated)
        })
        #if canImport(GRDB)
        if let _ = client.localStorage {
            self.tryUpdateLocalStorageData(
                client: client,
                rawData: tuple.0,
                outdated: tuple.1)
        }
        #endif
    }

    private class KeyAndDictionary {
        let key: String
        var dictionary: [String: Any]
        init(key: String, dictionary: [String: Any]) {
            self.key = key
            self.dictionary = dictionary
        }
    }

    private func operationRawDataUpdated(
        attr: [String: Any],
        attrModified: [String: Any],
        udate: String?,
        client: IMClient)
    {
        guard let udate = udate,
            let newUpdatedDate = LCDate.dateFromString(udate),
            let originUpdateDate = self.updatedAt ?? self.createdAt,
            newUpdatedDate >= originUpdateDate else {
                return
        }
        var rawDataCopy = self.rawData
        for keyPath in attr.keys {
            var stack: [KeyAndDictionary] = []
            var modifiedValue: Any?
            for (index, key) in keyPath.components(separatedBy: ".").enumerated() {
                stack.insert(
                    KeyAndDictionary(
                        key: key,
                        dictionary: index == 0
                            ? rawDataCopy
                            : (stack[0].dictionary[stack[0].key] as? [String: Any]) ?? [:]),
                    at: 0)
                modifiedValue = index == 0
                    ? attrModified[key]
                    : (modifiedValue as? [String: Any])?[key]
            }
            for (index, item) in stack.enumerated() {
                item.dictionary[item.key] = index == 0
                    ? modifiedValue
                    : stack[index - 1].dictionary
            }
            if let dictionary = stack.last?.dictionary {
                rawDataCopy = dictionary
            }
        }
        rawDataCopy[Key.updatedAt.rawValue] = udate
        self.rawData = rawDataCopy
        #if canImport(GRDB)
        self.tryUpdateLocalStorageData(
            client: client,
            rawData: rawDataCopy)
        #endif
    }

    enum Operation {
        case rawDataMerging(data: RawData)
        case rawDataReplaced(by: RawData)
        case append(members: [String], udate: String?)
        case remove(members: [String], udate: String?)
        case updated(attr: [String: Any], attrModified: [String: Any], udate: String?)
        case memberInfoChanged(info: MemberInfo)
    }

    func safeExecuting(operation: Operation, client: IMClient) {
        assert(client.specificAssertion)
        switch operation {
        case let .rawDataMerging(data: data):
            self.operationRawDataMerging(data: data, client: client)
        case let .rawDataReplaced(by: data):
            self.operationRawDataReplaced(data: data, client: client)
        case let .append(members: joinedMembers, udate: udate):
            self.operationAppend(members: joinedMembers, udate: udate, client: client)
        case let .remove(members: leftMembers, udate: udate):
            self.operationRemove(members: leftMembers, udate: udate, client: client)
        case let .updated(attr: attr, attrModified: attrModified, udate):
            self.operationRawDataUpdated(attr: attr, attrModified: attrModified, udate: udate, client: client)
        case let .memberInfoChanged(info: info):
            self.sync(self._memberInfoTable?[info.ID] = info)
        }
    }

    private func safeUpdatingMutedMembers(op: IMOpType, udate: String?, client: IMClient) {
        guard let udate = udate,
            let newUpdatedDate = LCDate.dateFromString(udate),
            let originUpdatedDate = self.updatedAt ?? self.createdAt,
            newUpdatedDate >= originUpdatedDate else {
                return
        }
        let newMutedMembers: [String]
        switch op {
        case .mute:
            if let originMutedMembers: [String] = self.safeDecodingRawData(with: .mutedMembers) {
                var set = Set(originMutedMembers)
                set.insert(self.clientID)
                newMutedMembers = Array(set)
            } else {
                newMutedMembers = [self.clientID]
            }
        case .unmute:
            if let originMutedMembers: [String] = self.safeDecodingRawData(with: .mutedMembers) {
                var set = Set(originMutedMembers)
                set.remove(self.clientID)
                newMutedMembers = Array(set)
            } else {
                newMutedMembers = []
            }
        default:
            return
        }
        let rawData = self.sync(closure: { () -> RawData in
            self.updatingRawData(key: .mutedMembers, value: newMutedMembers)
            self.updatingRawData(key: .updatedAt, value: udate)
            return self._rawData
        })
        #if canImport(GRDB)
        self.tryUpdateLocalStorageData(client: client, rawData: rawData)
        #endif
    }

    @discardableResult
    func safeUpdatingLastMessage(
        newMessage: IMMessage,
        client: IMClient,
        caching: Bool = true,
        notifying: Bool = true)
        -> Bool
    {
        var shouldIncreaseUnreadMessageCount: Bool = false
        guard !newMessage.isTransient,
            !newMessage.isWill,
            self.convType != .transient else {
                return shouldIncreaseUnreadMessageCount
        }
        var messageEvent: IMConversationEvent?
        let updatingLastMessageClosure: (Bool) -> Void = { isNewMessage in
            self.lastMessage = newMessage
            #if canImport(GRDB)
            if caching,
                self.convType != .temporary {
                do {
                    try client.localStorage?.insertOrReplace(
                        conversationID: self.ID,
                        lastMessage: newMessage)
                } catch {
                    Logger.shared.error(error)
                }
            }
            #endif
            if notifying {
                messageEvent = .lastMessageUpdated(newMessage: isNewMessage)
            }
            if isNewMessage, newMessage.ioType == .in {
                shouldIncreaseUnreadMessageCount = true
            }
        }
        if let oldMessage = self.lastMessage {
            if let newTimestamp: Int64 = newMessage.sentTimestamp,
                let newMessageID: String = newMessage.ID,
                let oldTimestamp: Int64 = oldMessage.sentTimestamp,
                let oldMessageID: String = oldMessage.ID {
                if newTimestamp > oldTimestamp {
                    updatingLastMessageClosure(true)
                } else if newTimestamp == oldTimestamp {
                    if newMessageID > oldMessageID {
                        updatingLastMessageClosure(true)
                    } else if newMessageID == oldMessageID {
                        updatingLastMessageClosure(false)
                    }
                }
            }
        } else {
            updatingLastMessageClosure(true)
        }
        if let messageEvent = messageEvent {
            client.eventQueue.async {
                client.delegate?.client(
                    client, conversation: self,
                    event: messageEvent)
            }
        }
        return shouldIncreaseUnreadMessageCount
    }

    private func decodingLastMessage(data: RawData, client: IMClient) -> IMMessage? {
        guard self.convType != .transient,
            let timestamp: Int64 = IMConversation.decoding(key: .lastMessageTimestamp, from: data),
            let messageID: String = IMConversation.decoding(key: .lastMessageId, from: data) else {
                return nil
        }
        var content: IMMessage.Content? = nil
        if let msg: String = IMConversation.decoding(key: .lastMessageString, from: data) {
            if let isBinary: Bool = IMConversation.decoding(key: .lastMessageBinary, from: data), isBinary,
                let data = Data(base64Encoded: msg) {
                content = .data(data)
            } else {
                content = .string(msg)
            }
        }
        return IMMessage.instance(
            application: client.application,
            conversationID: self.ID,
            currentClientID: self.clientID,
            fromClientID: IMConversation.decoding(key: .lastMessageFrom, from: data),
            timestamp: timestamp,
            patchedTimestamp: IMConversation.decoding(key: .lastMessagePatchTimestamp, from: data),
            messageID: messageID,
            content: content,
            isAllMembersMentioned: IMConversation.decoding(key: .lastMessageMentionAll, from: data),
            mentionedMembers: IMConversation.decoding(key: .lastMessageMentionPids, from: data))
    }

    #if canImport(GRDB)
    func tryUpdateLocalStorageData(client: IMClient, rawData: RawData? = nil, outdated: Bool? = nil) {
        guard let localStorage = client.localStorage else {
            return
        }
        var sets: [IMLocalStorage.Table.Conversation] = []
        if let rawData = rawData {
            do {
                let data = try JSONSerialization.data(withJSONObject: rawData)
                sets.append(.rawData(data))
                if let dateString: String = IMConversation.decoding(key: .updatedAt, from: rawData)
                    ?? IMConversation.decoding(key: .createdAt, from: rawData),
                    let date = LCDate.dateFromString(dateString) {
                    let updatedTimestamp = Int64(date.timeIntervalSince1970 * 1000.0)
                    sets.append(.updatedTimestamp(updatedTimestamp))
                }
            } catch {
                Logger.shared.error(error)
            }
        }
        if let outdated = outdated {
            sets.append(.outdated(outdated))
        }
        do {
            try localStorage.updateOrIgnore(conversationID: self.ID, sets: sets)
        } catch {
            Logger.shared.error(error)
        }
    }
    #endif

    func safeDecodingRawData<T>(with key: Key) -> T? {
        return self.safeDecodingRawData(with: key.rawValue)
    }

    func safeDecodingRawData<T>(with string: String) -> T? {
        return self.sync(self.decodingRawData(with: string))
    }

    func decodingRawData<T>(with key: Key) -> T? {
        return self.decodingRawData(with: key.rawValue)
    }

    func decodingRawData<T>(with string: String) -> T? {
        return IMConversation.decoding(string: string, from: self._rawData)
    }

    static func decoding<T>(key: Key, from data: RawData) -> T? {
        return IMConversation.decoding(string: key.rawValue, from: data)
    }

    static func decoding<T>(string: String, from data: RawData) -> T? {
        return data[string] as? T
    }

    func safeUpdatingRawData(key: Key, value: Any) {
        self.safeUpdatingRawData(string: key.rawValue, value: value)
    }

    func safeUpdatingRawData(string: String, value: Any) {
        self.sync(self.updatingRawData(string: string, value: value))
    }

    func updatingRawData(key: Key, value: Any) {
        self.updatingRawData(string: key.rawValue, value: value)
    }

    func updatingRawData(string: String, value: Any) {
        self._rawData[string] = value
    }
}

/// IM Chat Room
public class IMChatRoom: IMConversation {

    /// Priority for Sending Message in Chat Room.
    ///
    /// - high: high.
    /// - normal: normal.
    /// - low: low.
    public enum MessagePriority: Int {
        case high = 1
        case normal = 2
        case low = 3
    }
    
    @available(*, unavailable)
    public override func checkJoined(completion: @escaping (LCGenericResult<Bool>) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    @available(*, unavailable)
    public override func read(message: IMMessage? = nil) {}

    @available(*, unavailable)
    public override func getMessageReceiptFlag(completion: @escaping (LCGenericResult<IMConversation.MessageReceiptFlag>) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }
    
    @available(*, unavailable)
    public override func fetchReceiptTimestamps() throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func mute(completion: @escaping (LCBooleanResult) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    @available(*, unavailable)
    public override func unmute(completion: @escaping (LCBooleanResult) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    #if canImport(GRDB)
    @available(*, unavailable)
    public override func insertFailedMessageToCache(_ message: IMMessage, completion: @escaping (LCBooleanResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func removeFailedMessageFromCache(_ message: IMMessage, completion: @escaping (LCBooleanResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }
    #endif

    /// Get count of online-members in this chat-room.
    /// - Parameter completion: Result callback.
    public func getOnlineMembersCount(completion: @escaping (LCCountResult) -> Void) {
        self.countMembers(completion: completion)
    }

    /// Get online clients in this Chat Room.
    ///
    /// - Parameters:
    ///   - limit: Max and Default is 50 .
    ///   - completion: callback, dispatch to client.eventQueue .
    public func getOnlineMembers(limit: Int = 50, completion: @escaping (LCGenericResult<[String]>) -> Void) {
        let trimmedLimit: Int = (limit > 50 ? 50 : (limit < 0 ? 0 : limit))
        guard trimmedLimit > 0 else {
            self.client?.eventQueue.async {
                completion(.success(value: []))
            }
            return
        }
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .members
            var convCommand = IMConvCommand()
            convCommand.cid = self.ID
            convCommand.limit = Int32(trimmedLimit)
            outCommand.convMessage = convCommand
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                if let convMessage = (inCommand.hasConvMessage ? inCommand.convMessage : nil) {
                    client.eventQueue.async {
                        completion(.success(value: convMessage.m))
                    }
                } else {
                    client.eventQueue.async {
                        completion(.failure(error: LCError(code: .commandInvalid)))
                    }
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        })
    }

}

/// IM Service Conversation
public class IMServiceConversation: IMConversation {
    
    /// Whether this service conversation has been subscribed by the client.
    public var isSubscribed: Bool? {
        return self.safeDecodingRawData(with: .joined)
    }
    
    /// The date when the client subscribe this service conversation.
    public var subscribedAt: Date? {
        return IMClient.date(
            fromMillisecond: self.subscribedTimestamp)
    }
    
    /// The timestamp when the client subscribe this service conversation, unit of measurement is millisecond.
    public var subscribedTimestamp: Int64? {
        return self.safeDecodingRawData(with: .joinedAt)
    }
    
    /// Whether the offline notification of this service conversation has been muted by the client.
    public override var isMuted: Bool {
        return self.safeDecodingRawData(with: .muted) ?? false
    }
    
    @available(*, unavailable)
    public override func countMembers(completion: @escaping (LCCountResult) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    @available(*, unavailable)
    public override func update(attribution data: [String : Any], completion: @escaping (LCBooleanResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func fetchMemberInfoTable(completion: @escaping (LCBooleanResult) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    @available(*, unavailable)
    public override func getMemberInfo(by memberID: String, completion: @escaping (LCGenericResult<IMConversation.MemberInfo?>) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    @available(*, unavailable)
    public override func update(role: IMConversation.MemberRole, ofMember memberID: String, completion: @escaping (LCBooleanResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func block(members: Set<String>, completion: @escaping (IMConversation.MemberResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func unblock(members: Set<String>, completion: @escaping (IMConversation.MemberResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func getBlockedMembers(limit: Int = 50, next: String? = nil, completion: @escaping (LCGenericResult<IMConversation.BlockedMembersResult>) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func checkBlocking(member ID: String, completion: @escaping (LCGenericResult<Bool>) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    @available(*, unavailable)
    public override func mute(members: Set<String>, completion: @escaping (IMConversation.MemberResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func unmute(members: Set<String>, completion: @escaping (IMConversation.MemberResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func getMutedMembers(limit: Int = 50, next: String? = nil, completion: @escaping (LCGenericResult<IMConversation.MutedMembersResult>) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func checkMuting(member ID: String, completion: @escaping (LCGenericResult<Bool>) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    /// Subscribe this Service Conversation.
    ///
    /// - Parameter completion: callback.
    public func subscribe(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self.join(completion: completion)
    }

    /// Unsubscribe this Service Conversation.
    ///
    /// - Parameter completion: callback.
    public func unsubscribe(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self.leave(completion: completion)
    }
    
    /// Check whether *client* subscribed this conversation.
    /// - Parameter completion: Result callback.
    public func checkSubscription(completion: @escaping (LCGenericResult<Bool>) -> Void) {
        self._checkJoined(completion: completion)
    }
}

/// IM Temporary Conversation
/// Temporary Conversation is unique in it's Life Cycle.
public class IMTemporaryConversation: IMConversation {

    static let prefixOfID: String = "_tmp:"

    /// Expiration.
    public var expiration: Date? {
        guard let ttl = self.timeToLive,
            let createDate = self.createdAt else {
                return nil
        }
        return Date(timeInterval: TimeInterval(ttl), since: createDate)
    }

    /// Time to Live.
    public var timeToLive: Int? {
        return self.safeDecodingRawData(with: .temporaryTTL)
    }

    @available(*, unavailable)
    public override func join(completion: @escaping (LCBooleanResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func leave(completion: @escaping (LCBooleanResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func add(members: Set<String>, completion: @escaping (IMConversation.MemberResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func remove(members: Set<String>, completion: @escaping (IMConversation.MemberResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }
    
    @available(*, unavailable)
    public override func countMembers(completion: @escaping (LCCountResult) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }
    
    @available(*, unavailable)
    public override func checkJoined(completion: @escaping (LCGenericResult<Bool>) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    @available(*, unavailable)
    public override func mute(completion: @escaping (LCBooleanResult) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    @available(*, unavailable)
    public override func unmute(completion: @escaping (LCBooleanResult) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    @available(*, unavailable)
    public override func update(attribution data: [String : Any], completion: @escaping (LCBooleanResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func fetchMemberInfoTable(completion: @escaping (LCBooleanResult) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    @available(*, unavailable)
    public override func getMemberInfo(by memberID: String, completion: @escaping (LCGenericResult<IMConversation.MemberInfo?>) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    @available(*, unavailable)
    public override func update(role: IMConversation.MemberRole, ofMember memberID: String, completion: @escaping (LCBooleanResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func block(members: Set<String>, completion: @escaping (IMConversation.MemberResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func unblock(members: Set<String>, completion: @escaping (IMConversation.MemberResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func getBlockedMembers(limit: Int = 50, next: String? = nil, completion: @escaping (LCGenericResult<IMConversation.BlockedMembersResult>) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func checkBlocking(member ID: String, completion: @escaping (LCGenericResult<Bool>) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    @available(*, unavailable)
    public override func mute(members: Set<String>, completion: @escaping (IMConversation.MemberResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func unmute(members: Set<String>, completion: @escaping (IMConversation.MemberResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func getMutedMembers(limit: Int = 50, next: String? = nil, completion: @escaping (LCGenericResult<IMConversation.MutedMembersResult>) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func checkMuting(member ID: String, completion: @escaping (LCGenericResult<Bool>) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }

    #if canImport(GRDB)
    @available(*, unavailable)
    public override func insertFailedMessageToCache(_ message: IMMessage, completion: @escaping (LCBooleanResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }

    @available(*, unavailable)
    public override func removeFailedMessageFromCache(_ message: IMMessage, completion: @escaping (LCBooleanResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }
    #endif

    /// Refresh data of temporary conversation.
    /// - Parameter completion: Result callback.
    public override func refresh(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self.client?.conversationQuery.getTemporaryConversation(by: self.ID) { (result) in
            switch result {
            case .success:
                completion(.success)
            case .failure(error: let error):
                completion(.failure(error: error))
            }
        }
    }
}

extension LCError {

    static func conversationNotSupport(convType: IMConversation.Type) -> LCError {
        return LCError(
            code: .inconsistency,
            reason: "\(convType) not support this API"
        )
    }

}
