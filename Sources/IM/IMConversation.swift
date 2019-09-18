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
        return safeDecodingRawData(with: .name)
    }
    
    /// The creator of the conversation.
    public var creator: String? {
        return safeDecodingRawData(with: .creator)
    }
    
    /// The creation date of the conversation.
    public var createdAt: Date? {
        if let str: String = safeDecodingRawData(with: .createdAt) {
            return LCDate.dateFromString(str)
        } else {
            return nil
        }
    }
    
    /// The updated date of the conversation.
    public var updatedAt: Date? {
        if let str: String = safeDecodingRawData(with: .updatedAt) {
            return LCDate.dateFromString(str)
        } else {
            return nil
        }
    }
    
    /// The attributes of the conversation.
    public var attributes: [String: Any]? {
        return safeDecodingRawData(with: .attributes)
    }
    
    /// The members of the conversation.
    public var members: [String]? {
        return safeDecodingRawData(with: .members)
    }
    
    /// Indicates whether the conversation has been muted.
    public var isMuted: Bool {
        if let mutedMembers: [String] = safeDecodingRawData(with: .mutedMembers) {
            return mutedMembers.contains(self.clientID)
        } else {
            return false
        }
    }
    
    /// Indicates whether the data of conversation is outdated,
    /// after refresh, this property will be false.
    public internal(set) var isOutdated: Bool {
        set {
            guard self.convType != .temporary else {
                return
            }
            sync(self.underlyingOutdated = newValue)
        }
        get {
            var value: Bool = false
            guard self.convType != .temporary else {
                return value
            }
            sync(value = self.underlyingOutdated)
            return value
        }
    }
    private var underlyingOutdated: Bool = false
    
    /// The last message of the conversation.
    public private(set) var lastMessage: IMMessage? {
        set {
            sync(self.underlyingLastMessage = newValue)
        }
        get {
            var message: IMMessage? = nil
            sync(message = self.underlyingLastMessage)
            return message
        }
    }
    private var underlyingLastMessage: IMMessage? = nil
    
    /// The unread message count of the conversation
    public internal(set) var unreadMessageCount: Int {
        set {
            sync(self.underlyingUnreadMessageCount = newValue)
        }
        get {
            var count: Int = 0
            sync(count = self.underlyingUnreadMessageCount)
            return count
        }
    }
    private var underlyingUnreadMessageCount: Int = 0
    
    /// Indicates whether has unread message mentioning the client.
    public var isUnreadMessageContainMention: Bool {
        set {
            sync(self.underlyingIsUnreadMessageContainMention = newValue)
        }
        get {
            var value: Bool = false
            sync(value = self.underlyingIsUnreadMessageContainMention)
            return value
        }
    }
    private var underlyingIsUnreadMessageContainMention: Bool = false
    
    /// The table of member infomation.
    public var memberInfoTable: [String: MemberInfo]? {
        var value: [String: MemberInfo]?
        self.sync(value = self.underlyingMemberInfoTable)
        return value
    }
    private var underlyingMemberInfoTable: [String: MemberInfo]?
    
    /// Get value via subscript syntax.
    public subscript(key: String) -> Any? {
        get { return safeDecodingRawData(with: key) }
    }
    
    static func instance(ID: String, rawData: RawData, client: IMClient, caching: Bool) -> IMConversation {
        var convType: ConvType = .normal
        if let typeRawValue: Int = rawData[Key.convType.rawValue] as? Int,
            let validType = ConvType(rawValue: typeRawValue) {
            convType = validType
        } else {
            if let transient: Bool = rawData[Key.transient.rawValue] as? Bool, transient {
                convType = .transient
            } else if let system: Bool = rawData[Key.system.rawValue] as? Bool, system {
                convType = .system
            } else if let temporary: Bool = rawData[Key.temporary.rawValue] as? Bool, temporary {
                convType = .temporary
            } else if ID.hasPrefix(IMTemporaryConversation.prefixOfID) {
                convType = .temporary
            }
        }
        switch convType {
        case .normal:
            return IMConversation(
                ID: ID,
                rawData: rawData,
                convType: convType,
                client: client,
                caching: caching
            )
        case .transient:
            return IMChatRoom(
                ID: ID,
                rawData: rawData,
                convType: convType,
                client: client,
                caching: caching
            )
        case .system:
            return IMServiceConversation(
                ID: ID,
                rawData: rawData,
                convType: convType,
                client: client,
                caching: caching
            )
        case .temporary:
            return IMTemporaryConversation(
                ID: ID,
                rawData: rawData,
                convType: convType,
                client: client,
                caching: caching
            )
        }
    }

    init(ID: String, rawData: RawData, convType: ConvType, client: IMClient, caching: Bool) {
        self.ID = ID
        self.client = client
        self.rawData = rawData
        self.clientID = client.ID
        self.convType = convType
        self.isUnique = (rawData[Key.unique.rawValue] as? Bool) ?? false
        self.uniqueID = (rawData[Key.uniqueId.rawValue] as? String)
        if let message = self.decodingLastMessage(data: rawData, client: client) {
            self.safeUpdatingLastMessage(
                newMessage: message,
                client: client,
                caching: caching,
                notifying: false
            )
        }
        if caching {
            client.localStorage?.insertOrReplace(
                conversationID: ID,
                rawData: rawData,
                convType: convType
            )
        }
    }
    
    private(set) var rawData: RawData
    
    let lock: NSLock = NSLock()
    
    /// Clear unread messages that its sent timestamp less than the sent timestamp of the parameter message.
    ///
    /// - Parameter message: The default is the last message.
    public func read(message: IMMessage? = nil) {
        self._read(message: message)
    }
    
    /// Get the timestamp flag of message receipt.
    ///
    /// - Parameter completion: callback.
    public func getMessageReceiptFlag(completion: @escaping (LCGenericResult<MessageReceiptFlag>) -> Void) throws {
        try self._getMessageReceiptFlag(completion: completion)
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
    
}

extension IMConversation: InternalSynchronizing {
    
    var mutex: NSLock {
        return self.lock
    }
    
}

// MARK: Message Sending

extension IMConversation {
    
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
    ///   - message: The message to be sent.
    ///   - options: @see `MessageSendOptions`.
    ///   - priority: @see `IMChatRoom.MessagePriority`.
    ///   - pushData: The push data of APNs.
    ///   - progress: The file uploading progress.
    ///   - completion: callback.
    public func send(
        message: IMMessage,
        options: MessageSendOptions = .default,
        priority: IMChatRoom.MessagePriority? = nil,
        pushData: [String: Any]? = nil,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
    {
        guard message.status == .none || message.status == .failed else {
            throw LCError(
                code: .inconsistency,
                reason: "Only the message that status is \(IMMessage.Status.none) or \(IMMessage.Status.failed) can be sent"
            )
        }
        message.setup(clientID: self.clientID, conversationID: self.ID)
        message.update(status: .sending)
        message.isTransient = options.contains(.isTransient)
        message.isWill = options.contains(.isAutoDeliveringWhenOffline)
        if
            !message.isTransient,
            self.convType != .transient,
            message.dToken == nil
        {
            message.dToken = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            message.sendingTimestamp = Int64(Date().timeIntervalSince1970 * 1000.0)
        }
        try self.preprocess(message: message, pushData: pushData, progress: progress) { (pushDataString: String?, error: LCError?) in
            if let error: LCError = error {
                message.update(status: .failed)
                self.client?.eventQueue.async {
                    completion(.failure(error: error))
                }
                return
            }
            self.client?.sendCommand(constructor: { () -> IMGenericCommand in
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
                if let value: Bool = message.isAllMembersMentioned {
                    directCommand.mentionAll = value
                }
                if let value: [String] = message.mentionedMembers {
                    directCommand.mentionPids = value
                }
                if options.contains(.needReceipt) {
                    directCommand.r = true
                }
                if let pushData: String = pushDataString {
                    directCommand.pushData = pushData
                }
                if message.isWill {
                    directCommand.will = true
                }
                if message.isTransient {
                    directCommand.transient = true
                }
                if let dt: String = message.dToken {
                    directCommand.dt = dt
                }
                outCommand.directMessage = directCommand
                return outCommand
            }, completion: { (client, result) in
                switch result {
                case .inCommand(let inCommand):
                    assert(client.specificAssertion)
                    let ackCommand = (inCommand.hasAckMessage ? inCommand.ackMessage : nil)
                    if
                        let ack: IMAckCommand = ackCommand,
                        let messageID: String = (ack.hasUid ? ack.uid : nil),
                        let timestamp: Int64 = (ack.hasT ? ack.t : nil)
                    {
                        message.update(status: .sent, ID: messageID, timestamp: timestamp)
                        self.safeUpdatingLastMessage(newMessage: message, client: client)
                        client.eventQueue.async {
                            completion(.success)
                        }
                    }
                    else if
                        let ack: IMAckCommand = ackCommand,
                        let error: LCError = ack.lcError
                    {
                        client.eventQueue.async {
                            completion(.failure(error: error))
                        }
                    }
                    else
                    {
                        message.update(status: .failed)
                        client.eventQueue.async {
                            let error = LCError(code: .commandInvalid)
                            completion(.failure(error: error))
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
        progress: ((Double) -> Void)?,
        completion: @escaping (String?, LCError?) -> Void)
        throws
    {
        guard let client = self.client else {
            throw LCError(code: .inconsistency, reason: "client not found.")
        }
        var pushDataString: String? = nil
        if let pushData: [String: Any] = pushData {
            let data: Data = try JSONSerialization.data(withJSONObject: pushData, options: [])
            pushDataString = String(data: data, encoding: .utf8)
        }
        guard let categorizedMessage: IMCategorizedMessage = message as? IMCategorizedMessage else {
            completion(pushDataString, nil)
            return
        }
        let normallyCompletedClosure: () throws -> Void = {
            categorizedMessage.tryEncodingFileMetaData()
            try categorizedMessage.encodingMessageContent()
            completion(pushDataString, nil)
        }
        guard let file: LCFile = categorizedMessage.file else {
            try normallyCompletedClosure()
            return
        }
        guard file.application === client.application else {
            throw LCError(code: .inconsistency, reason: "file's application is not equal to client's application.")
        }
        guard !file.hasObjectId else {
            try normallyCompletedClosure()
            return
        }
        let _ = file.save(progress: { (value) in
            // TODO: maybe should support custom callback dispatch queue
            progress?(value)
        }) { (result) in
            // TODO: maybe should support custom callback dispatch queue
            switch result {
            case .success:
                DispatchQueue.global(qos: .background).async {
                    do {
                        try normallyCompletedClosure()
                    } catch {
                        completion(nil, LCError(error: error))
                    }
                }
            case .failure(error: let error):
                completion(nil, error)
            }
        }
    }
    
}

// MARK: Message Reading

extension IMConversation {
    
    private func _read(message: IMMessage?) {
        guard
            self.unreadMessageCount > 0,
            let readMessage: IMMessage = message ?? self.lastMessage,
            let messageID: String = readMessage.ID,
            let timestamp: Int64 = readMessage.sentTimestamp else
        {
            return
        }
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
        let newUnreadCount: Int = Int(unreadTuple.unread)
        let newUnreadMentioned: Bool? = (unreadTuple.hasMentioned ? unreadTuple.mentioned : nil)
        let newLastMessage: IMMessage? = {
            guard
                let timestamp: Int64 = (unreadTuple.hasTimestamp ? unreadTuple.timestamp : nil),
                let messageID: String = (unreadTuple.hasMid ? unreadTuple.mid : nil)
                else
            { return nil }
            var content: IMMessage.Content? = nil
            /*
             For Compatibility,
             Should check `binaryMsg` at first.
             Then check `data`.
             */
            if unreadTuple.hasBinaryMsg {
                content = .data(unreadTuple.binaryMsg)
            } else if unreadTuple.hasData {
                content = .string(unreadTuple.data)
            }
            let message = IMMessage.instance(
                application: client.application,
                isTransient: false,
                conversationID: self.ID,
                currentClientID: self.clientID,
                fromClientID: (unreadTuple.hasFrom ? unreadTuple.from : nil),
                timestamp: timestamp,
                patchedTimestamp: (unreadTuple.hasPatchTimestamp ? unreadTuple.patchTimestamp : nil),
                messageID: messageID,
                content: content,
                isAllMembersMentioned: nil,
                mentionedMembers: nil
            )
            return message
        }()
        if let message: IMMessage = newLastMessage {
            self.safeUpdatingLastMessage(newMessage: message, client: client)
        }
        if self.unreadMessageCount != newUnreadCount {
            self.unreadMessageCount = newUnreadCount
            if let isMentioned: Bool = newUnreadMentioned {
                self.isUnreadMessageContainMention = isMentioned
            }
            client.eventQueue.async {
                client.delegate?.client(client, conversation: self, event: .unreadMessageCountUpdated)
            }
        }
    }
    
}

// MARK: Message Updating

extension IMConversation {
    
    /// Update the content of a sent message.
    ///
    /// - Parameters:
    ///   - oldMessage: The sent message to be updated.
    ///   - newMessage: The message which has new content.
    ///   - progress: The file uploading progress.
    ///   - completion: callback.
    public func update(
        oldMessage: IMMessage,
        to newMessage: IMMessage,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
    {
        guard
            let oldMessageID: String = oldMessage.ID,
            let oldMessageTimestamp: Int64 = oldMessage.sentTimestamp,
            oldMessage.isSent
            else
        {
            throw LCError(code: .updatingMessageNotSent)
        }
        guard
            let oldMessageConvID: String = oldMessage.conversationID,
            oldMessageConvID == self.ID,
            oldMessage.fromClientID == self.clientID
            else
        {
            throw LCError(code: .updatingMessageNotAllowed)
        }
        guard newMessage.status == .none else {
            throw LCError(
                code: .inconsistency,
                reason: "new message's status should be \(IMMessage.Status.none)."
            )
        }
        try self.preprocess(message: newMessage, progress: progress) { (_, error: LCError?) in
            if let error: LCError = error {
                self.client?.eventQueue.async {
                    completion(.failure(error: error))
                }
                return
            }
            self.client?.sendCommand(constructor: { () -> IMGenericCommand in
                var outCommand = IMGenericCommand()
                outCommand.cmd = .patch
                outCommand.op = .modify
                var patchMessage = IMPatchCommand()
                var patchItem = IMPatchItem()
                patchItem.cid = oldMessageConvID
                patchItem.mid = oldMessageID
                patchItem.timestamp = oldMessageTimestamp
                if let content: IMMessage.Content = newMessage.content {
                    switch content {
                    case .data(let data):
                        patchItem.binaryMsg = data
                    case .string(let string):
                        patchItem.data = string
                    }
                }
                if let mentionAll: Bool = newMessage.isAllMembersMentioned {
                    patchItem.mentionAll = mentionAll
                }
                if let mentionList: [String] = newMessage.mentionedMembers {
                    patchItem.mentionPids = mentionList
                }
                patchMessage.patches = [patchItem]
                outCommand.patchMessage = patchMessage
                return outCommand
            }, completion: { (client, result) in
                switch result {
                case .inCommand(let inCommand):
                    assert(client.specificAssertion)
                    if inCommand.hasPatchMessage, inCommand.patchMessage.hasLastPatchTime {
                        newMessage.patchedTimestamp = inCommand.patchMessage.lastPatchTime
                        newMessage.update(
                            status: oldMessage.status,
                            ID: oldMessageID,
                            timestamp: oldMessageTimestamp
                        )
                        newMessage.setup(
                            clientID: self.clientID,
                            conversationID: self.ID
                        )
                        newMessage.deliveredTimestamp = oldMessage.deliveredTimestamp
                        newMessage.readTimestamp = oldMessage.readTimestamp
                        self.safeUpdatingLastMessage(newMessage: newMessage, client: client)
                        if let localStorage = client.localStorage {
                            do {
                                try localStorage.updateOrIgnore(message: newMessage)
                            } catch {
                                Logger.shared.error(error)
                            }
                        }
                        client.eventQueue.async {
                            completion(.success)
                        }
                    } else {
                        client.eventQueue.async {
                            let error = LCError(code: .commandInvalid)
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
    
    /// Recall a sent message.
    ///
    /// - Parameters:
    ///   - message: The message has been sent.
    ///   - completion: callback.
    public func recall(message: IMMessage, completion: @escaping (LCGenericResult<IMRecalledMessage>) -> Void) throws {
        let recalledMessage = IMRecalledMessage()
        try self.update(oldMessage: message, to: recalledMessage, completion: { (result) in
            switch result {
            case .success:
                completion(.success(value: recalledMessage))
            case .failure(error: let error):
                completion(.failure(error: error))
            }
        })
    }
    
    func process(patchItem: IMPatchItem, client: IMClient) {
        assert(client.specificAssertion)
        guard
            let timestamp: Int64 = (patchItem.hasTimestamp ? patchItem.timestamp : nil),
            let messageID: String = (patchItem.hasMid ? patchItem.mid : nil)
            else
        {
            return
        }
        var content: IMMessage.Content? = nil
        /*
         For Compatibility,
         Should check `binaryMsg` at first.
         Then check `data`.
         */
        if patchItem.hasBinaryMsg {
            content = .data(patchItem.binaryMsg)
        } else if patchItem.hasData {
            content = .string(patchItem.data)
        }
        let patchedMessage = IMMessage.instance(
            application: client.application,
            isTransient: false,
            conversationID: self.ID,
            currentClientID: self.clientID,
            fromClientID: (patchItem.hasFrom ? patchItem.from : nil),
            timestamp: timestamp,
            patchedTimestamp: (patchItem.hasPatchTimestamp ? patchItem.patchTimestamp : nil),
            messageID: messageID,
            content: content,
            isAllMembersMentioned: (patchItem.hasMentionAll ? patchItem.mentionAll : nil),
            mentionedMembers: (patchItem.mentionPids.count > 0 ? patchItem.mentionPids : nil)
        )
        self.safeUpdatingLastMessage(newMessage: patchedMessage, client: client)
        if let localStorage = client.localStorage {
            do {
                try localStorage.updateOrIgnore(message: patchedMessage)
            } catch {
                Logger.shared.error(error)
            }
        }
        var reason: IMMessage.PatchedReason? = nil
        if patchItem.hasPatchCode || patchItem.hasPatchReason {
            reason = IMMessage.PatchedReason(
                code: (patchItem.hasPatchCode ? Int(patchItem.patchCode) : nil),
                reason: (patchItem.hasPatchReason ? patchItem.patchReason : nil)
            )
        }
        client.eventQueue.async {
            let messageEvent = IMMessageEvent.updated(updatedMessage: patchedMessage, reason: reason)
            client.delegate?.client(client, conversation: self, event: .message(event: messageEvent))
        }
    }
    
}

// MARK: Message Receipt Timestamp

extension IMConversation {
    
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
    
    private func _getMessageReceiptFlag(completion: @escaping (LCGenericResult<MessageReceiptFlag>) -> Void) throws {
        if let options = self.client?.options {
            guard options.isProtobuf3 else {
                throw LCError(
                    code: .inconsistency,
                    reason: "only client init with \(IMClient.Options.receiveUnreadMessageCountAfterSessionDidOpen) support this function."
                )
            }
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
                client.eventQueue.async {
                    if inCommand.hasConvMessage {
                        let convMessage = inCommand.convMessage
                        let readFlagTimestamp: Int64? = (convMessage.hasMaxReadTimestamp ? convMessage.maxReadTimestamp : nil)
                        let deliveredFlagTimestamp = (convMessage.hasMaxAckTimestamp ? convMessage.maxAckTimestamp : nil)
                        let flag = MessageReceiptFlag(
                            readFlagTimestamp: readFlagTimestamp,
                            deliveredFlagTimestamp: deliveredFlagTimestamp
                        )
                        completion(.success(value: flag))
                    } else {
                        let error = LCError(code: .commandInvalid)
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

// MARK: Message Query

extension IMConversation {
    
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
        case onlyCache
        case cacheThenNetwork
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
                reason: "limit should in range \(IMConversation.limitRangeOfMessageQuery)"
            )
        }
        var underlyingPolicy: MessageQueryPolicy = policy
        if [ConvType.transient, ConvType.temporary].contains(self.convType) || type != nil {
            underlyingPolicy = .onlyNetwork
        } else {
            if underlyingPolicy == .default {
                if let client = self.client, client.options.contains(.usingLocalStorage) {
                    underlyingPolicy = .cacheThenNetwork
                } else {
                    underlyingPolicy = .onlyNetwork
                }
            }
        }
        switch underlyingPolicy {
        case .default:
            fatalError("never happen")
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
        case .onlyCache:
            guard let localStorage = self.client?.localStorage else {
                throw LCError.clientLocalStorageNotFound
            }
            self.queryMessageOnlyCache(
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
            guard let localStorage = self.client?.localStorage else {
                throw LCError.clientLocalStorageNotFound
            }
            self.queryMessageOnlyCache(
                localStorage: localStorage,
                start: start,
                end: end,
                direction: direction,
                limit: limit)
            { (client, result, hasBreakpoint) in
                var shouldUseNetwork: Bool = (hasBreakpoint || result.isFailure)
                if !shouldUseNetwork, let value = result.value {
                    shouldUseNetwork = (value.count != limit)
                }
                if shouldUseNetwork {
                    self.queryMessageOnlyNetwork(
                        start: start,
                        end: end,
                        direction: direction,
                        limit: limit,
                        type: nil)
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
                    if
                        [ConvType.normal, ConvType.system].contains(self.convType),
                        let localStorage = client.localStorage
                    {
                        localStorage.insertOrReplace(messages: messages)
                    }
                    completion(client, .success(value: messages))
                } catch {
                    completion(client, .failure(error: LCError(error: error)))
                }
            case .error(let error):
                completion(client, .failure(error: error))
            }
        })
    }
    
    private func queryMessageOnlyCache(
        localStorage: IMLocalStorage,
        start: MessageQueryEndpoint?,
        end: MessageQueryEndpoint?,
        direction: MessageQueryDirection?,
        limit: Int,
        completion: @escaping (IMClient, LCGenericResult<[IMMessage]>, Bool) -> Void)
    {
        localStorage.selectMessages(
            conversationID: self.ID,
            start: start,
            end: end,
            direction: direction,
            limit: limit,
            completion: completion
        )
    }
    
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
            guard
                let messageID = (item.hasMsgID ? item.msgID : nil),
                let timestamp = (item.hasTimestamp ? item.timestamp : nil)
                else
            { continue }
            var content: IMMessage.Content? = nil
            if item.hasData {
                /*
                 For Compatibility,
                 Should check `binaryMsg` at first.
                 Then check `msg`.
                 */
                if item.hasBin {
                    /* should use base64 for decoding stored binary data string */
                    if let decodedData = Data(base64Encoded: item.data) {
                        content = .data(decodedData)
                    }
                } else {
                    content = .string(item.data)
                }
            }
            let message = IMMessage.instance(
                application: client.application,
                isTransient: false,
                conversationID: self.ID,
                currentClientID: client.ID,
                fromClientID: (item.hasFrom ? item.from : nil),
                timestamp: timestamp,
                patchedTimestamp: (item.hasPatchTimestamp ? item.patchTimestamp : nil),
                messageID: messageID,
                content: content,
                isAllMembersMentioned: (item.hasMentionAll ? item.mentionAll : nil),
                mentionedMembers: (item.mentionPids.isEmpty ? nil : item.mentionPids)
            )
            message.deliveredTimestamp = (item.hasAckAt ? item.ackAt : nil)
            message.readTimestamp = (item.hasReadAt ? item.readAt : nil)
            messages.append(message)
        }
        if let newestMessage = messages.last {
            self.safeUpdatingLastMessage(newMessage: newestMessage, client: client)
        }
        return messages
    }
    
}

// MARK: Members

extension IMConversation {
    
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
        if self.convType == .normal, let signatureDelegate = self.client?.signatureDelegate {
            let action: IMSignature.Action
            if op == .add {
                action = .add(memberIDs: members, toConversation: self)
            } else {
                action = .remove(memberIDs: members, fromConversation: self)
            }
            self.client?.eventQueue.async {
                if let client = self.client {
                    signatureDelegate.client(client, action: action, signatureHandler: { (client, signature) in
                        client.serialQueue.async {
                            let command = self.newConvAddRemoveCommand(members: members, op: op, signature: signature)
                            completion(client, command)
                        }
                    })
                }
            }
            
        } else if let client = self.client {
            let command = self.newConvAddRemoveCommand(members: members, op: op)
            completion(client, command)
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
    
}

// MARK: Mute

extension IMConversation {
    
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

// MARK: Member Info

extension IMConversation {
    
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
                    let httpClient: HTTPClient = client.application.httpClient
                    let header: [String: String] = [
                        "X-LC-IM-Session-Token": token
                    ]
                    let parameters: [String: Any] = [
                        "client_id": client.ID,
                        "cid": self.ID
                    ]
                    _ = httpClient.request(
                        .get,
                        "classes/_ConversationMemberInfo",
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
                            self.sync(self.underlyingMemberInfoTable = table)
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
                    creator: self.creator
                )
                self.sync { self.underlyingMemberInfoTable?[info.ID] = info }
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

// MARK: Blacklist

extension IMConversation {
    
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
        if self.convType == .normal, let signatureDelegate = self.client?.signatureDelegate {
            let action: IMSignature.Action
            if op == .block {
                action = .conversationBlocking(self, blockedMemberIDs: members)
            } else {
                action = .conversationUnblocking(self, unblockedMemberIDs: members)
            }
            self.client?.eventQueue.async {
                if let client = self.client {
                    signatureDelegate.client(client, action: action, signatureHandler: { (client, signature) in
                        client.serialQueue.async {
                            let command = self.newBlacklistBlockUnblockCommand(members: members, op: op, signature: signature)
                            completion(client, command)
                        }
                    })
                }
            }
        } else if let client = self.client {
            let command = self.newBlacklistBlockUnblockCommand(members: members, op: op)
            completion(client, command)
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

// MARK: Shutup

extension IMConversation {
    
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

// MARK: Data Updating

extension IMConversation {
    
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
        var rawData: RawData?
        sync {
            self.rawData.merge(data) { (_, new) in new }
            rawData = self.rawData
        }
        self.tryUpdateLocalStorageData(client: client, rawData: rawData)
    }
    
    private func operationRawDataReplaced(data: RawData, client: IMClient) {
        sync {
            self.rawData = data
            self.underlyingOutdated = false
        }
        if let message = self.decodingLastMessage(data: data, client: client) {
            self.safeUpdatingLastMessage(newMessage: message, client: client)
        }
        client.localStorage?.insertOrReplace(conversationID: self.ID, rawData: data, convType: self.convType)
    }
    
    private func needUpdateMembers(members: [String], updatedDateString: String?) -> Bool {
        guard
            self.convType != .transient,
            self.convType != .system,
            !members.isEmpty else
        {
            return false
        }
        if let dateString: String = updatedDateString,
            let newUpdatedDate: Date = LCDate.dateFromString(dateString) {
            if let originUpdatedDate: Date = self.updatedAt {
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
        if let udateString: String = udate {
            self.safeUpdatingRawData(key: .updatedAt, value: udateString)
        }
        if let _ = client.localStorage {
            var rawData: RawData?
            sync(rawData = self.rawData)
            self.tryUpdateLocalStorageData(client: client, rawData: rawData)
        }
    }
    
    private func operationRemove(members leftMembers: [String], udate: String?, client: IMClient) {
        guard self.needUpdateMembers(members: leftMembers, updatedDateString: udate) else {
            return
        }
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
        if let udateString: String = udate {
            self.safeUpdatingRawData(key: .updatedAt, value: udateString)
        }
        if let _ = client.localStorage {
            var rawData: RawData?
            var outdated: Bool?
            self.sync {
                rawData = self.rawData
                outdated = self.underlyingOutdated
            }
            self.tryUpdateLocalStorageData(client: client, rawData: rawData, outdated: outdated)
        }
        self.sync {
            if let _ = self.underlyingMemberInfoTable {
                for member in leftMembers {
                    self.underlyingMemberInfoTable?.removeValue(forKey: member)
                }
            }
        }
    }
    
    private class KeyAndDictionary {
        let key: String
        var dictionary: [String: Any]
        init(key: String, dictionary: [String: Any]) {
            self.key = key
            self.dictionary = dictionary
        }
    }
    
    private func operationRawDataUpdated(attr: [String: Any], attrModified: [String: Any], udate: String?, client: IMClient) {
        guard
            let udateString: String = udate,
            let newUpdatedDate: Date = LCDate.dateFromString(udateString),
            let originUpdateDate = self.updatedAt,
            newUpdatedDate > originUpdateDate
            else
        {
            return
        }
        var rawDataCopy: RawData! = nil
        sync(rawDataCopy = self.rawData)
        for keyPath in attr.keys {
            var stack: [KeyAndDictionary] = []
            var modifiedValue: Any? = nil
            for key in keyPath.components(separatedBy: ".") {
                if stack.isEmpty {
                    stack.insert(KeyAndDictionary(
                        key: key,
                        dictionary: rawDataCopy
                    ), at: 0)
                    modifiedValue = attrModified[key]
                } else {
                    let first: KeyAndDictionary = stack[0]
                    stack.insert(KeyAndDictionary(
                        key: key,
                        dictionary: (first.dictionary[first.key] as? [String: Any]) ?? [:]
                    ), at: 0)
                    if let modifiedDic = modifiedValue as? [String: Any] {
                        modifiedValue = modifiedDic[key]
                    }
                }
            }
            for (index, item) in stack.enumerated() {
                if index == 0 {
                    if let value = modifiedValue {
                        item.dictionary[item.key] = value
                    } else {
                        item.dictionary.removeValue(forKey: item.key)
                    }
                } else {
                    let leafItem = stack[index - 1]
                    item.dictionary[item.key] = leafItem.dictionary
                }
            }
            if let newRawData = stack.last?.dictionary {
                rawDataCopy = newRawData
            }
        }
        rawDataCopy[Key.updatedAt.rawValue] = udateString
        sync(self.rawData = rawDataCopy)
        self.tryUpdateLocalStorageData(client: client, rawData: rawDataCopy)
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
            self.sync { self.underlyingMemberInfoTable?[info.ID] = info }
        }
    }
    
    private func safeUpdatingMutedMembers(op: IMOpType, udate: String?, client: IMClient) {
        guard let udate: String = udate else {
            return
        }
        let key = Key.mutedMembers
        var newMutedMembers: [String]
        switch op {
        case .mute:
            if let originMutedMembers: [String] = self.safeDecodingRawData(with: key) {
                var set = Set(originMutedMembers)
                set.insert(self.clientID)
                newMutedMembers = Array(set)
            } else {
                newMutedMembers = [self.clientID]
            }
        case .unmute:
            if let originMutedMembers: [String] = self.safeDecodingRawData(with: key) {
                var set = Set(originMutedMembers)
                set.remove(self.clientID)
                newMutedMembers = Array(set)
            } else {
                newMutedMembers = []
            }
        default:
            return
        }
        var rawData: RawData?
        sync {
            self.updatingRawData(key: key, value: newMutedMembers)
            self.updatingRawData(key: .updatedAt, value: udate)
            rawData = self.rawData
        }
        self.tryUpdateLocalStorageData(client: client, rawData: rawData)
    }
    
    @discardableResult
    func safeUpdatingLastMessage(
        newMessage: IMMessage,
        client: IMClient,
        caching: Bool = true,
        notifying: Bool = true)
        -> Bool
    {
        var isUnreadMessageIncreased: Bool = false
        guard
            newMessage.notTransientMessage,
            newMessage.notWillMessage,
            self.convType != .transient else
        {
            return isUnreadMessageIncreased
        }
        var messageEvent: IMConversationEvent? = nil
        let updatingLastMessageClosure: (Bool) -> Void = { shouldIncreased in
            self.lastMessage = newMessage
            if self.convType != .temporary, caching {
                client.localStorage?.insertOrReplace(conversationID: self.ID, lastMessage: newMessage)
            }
            if notifying {
                let isNewMessageReplacing: Bool = shouldIncreased
                messageEvent = .lastMessageUpdated(newMessage: isNewMessageReplacing)
            }
            if shouldIncreased && newMessage.ioType == .in {
                isUnreadMessageIncreased = true
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
        if let event = messageEvent {
            client.eventQueue.async {
                client.delegate?.client(client, conversation: self, event: event)
            }
        }
        return isUnreadMessageIncreased
    }
    
    private func decodingLastMessage(data: RawData, client: IMClient) -> IMMessage? {
        guard
            self.convType != .transient,
            let timestamp: Int64 = IMConversation.decoding(key: .lastMessageTimestamp, from: data),
            let messageID: String = IMConversation.decoding(key: .lastMessageId, from: data) else
        {
            return nil
        }
        var content: IMMessage.Content? = nil
        /*
         For Compatibility,
         Should check `lastMessageBinary` at first.
         Then check `lastMessageString`.
         */
        if let data: Data = IMConversation.decoding(key: .lastMessageBinary, from: data) {
            content = .data(data)
        } else if let string: String = IMConversation.decoding(key: .lastMessageString, from: data) {
            content = .string(string)
        }
        let message = IMMessage.instance(
            application: client.application,
            isTransient: false,
            conversationID: self.ID,
            currentClientID: self.clientID,
            fromClientID: IMConversation.decoding(key: .lastMessageFrom, from: data),
            timestamp: timestamp,
            patchedTimestamp: IMConversation.decoding(key: .lastMessagePatchTimestamp, from: data),
            messageID: messageID,
            content: content,
            isAllMembersMentioned: IMConversation.decoding(key: .lastMessageMentionAll, from: data),
            mentionedMembers: IMConversation.decoding(key: .lastMessageMentionPids, from: data)
        )
        return message
    }
    
    func tryUpdateLocalStorageData(client: IMClient, rawData: RawData? = nil, outdated: Bool? = nil) {
        guard let localStorage = client.localStorage else {
            return
        }
        var sets: [IMLocalStorage.Table.Conversation] = []
        if let rawData = rawData {
            do {
                let data = try JSONSerialization.data(withJSONObject: rawData)
                sets.append(.rawData(data))
                if
                    let updatedAt: String = IMConversation.decoding(key: .updatedAt, from: rawData),
                    let date: Date = LCDate.dateFromString(updatedAt)
                {
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
        localStorage.updateOrIgnore(conversationID: self.ID, sets: sets)
    }
    
}

// MARK: Misc

private extension IMConversation {
    
    func safeDecodingRawData<T>(with key: Key) -> T? {
        return self.safeDecodingRawData(with: key.rawValue)
    }
    
    func safeDecodingRawData<T>(with string: String) -> T? {
        var value: T? = nil
        sync(value = self.decodingRawData(with: string))
        return value
    }
    
    func decodingRawData<T>(with key: Key) -> T? {
        return self.decodingRawData(with: key.rawValue)
    }
    
    func decodingRawData<T>(with string: String) -> T? {
        return IMConversation.decoding(string: string, from: self.rawData)
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
        sync(self.updatingRawData(string: string, value: value))
    }
    
    func updatingRawData(key: Key, value: Any) {
        self.updatingRawData(string: key.rawValue, value: value)
    }
    
    func updatingRawData(string: String, value: Any) {
        self.rawData[string] = value
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
    public override func read(message: IMMessage? = nil) {}
    
    @available(*, unavailable)
    public override func getMessageReceiptFlag(completion: @escaping (LCGenericResult<IMConversation.MessageReceiptFlag>) -> Void) throws {
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
    
    /// Get count of online clients in this Chat Room.
    ///
    /// - Parameter completion: callback.
    public func getOnlineMembersCount(completion: @escaping (LCCountResult) -> Void) {
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .count
            var convCommand = IMConvCommand()
            convCommand.cid = self.ID
            outCommand.convMessage = convCommand
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                if inCommand.hasConvMessage, inCommand.convMessage.hasCount {
                    client.eventQueue.async {
                        let count = Int(inCommand.convMessage.count)
                        completion(.success(count: count))
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
    
    /// Check whether subscribed this Service Conversation.
    ///
    /// - Parameter completion: callback, dispatch to client.eventQueue .
    public func checkSubscription(completion: @escaping (LCGenericResult<Bool>) -> Void) {
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
                    if
                        let convMessage = (inCommand.hasConvMessage ? inCommand.convMessage : nil),
                        let jsonObject = (convMessage.hasResults ? convMessage.results : nil),
                        let dataString = (jsonObject.hasData ? jsonObject.data : nil),
                        let results: [String: Any] = try dataString.jsonObject(),
                        let boolValue: Bool = results[self.ID] as? Bool
                    {
                        client.eventQueue.async {
                            completion(.success(value: boolValue))
                        }
                    } else {
                        client.eventQueue.async {
                            completion(.failure(error: LCError(code: .commandInvalid)))
                        }
                    }
                } catch {
                    client.eventQueue.async {
                        completion(.failure(error: LCError(underlyingError: error)))
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

/// IM Temporary Conversation
/// Temporary Conversation is unique in it's Life Cycle.
public class IMTemporaryConversation: IMConversation {
    
    static let prefixOfID: String = "_tmp:"
    
    /// Expiration.
    public var expiration: Date? {
        guard
            let ttl = self.timeToLive,
            let createDate: Date = self.createdAt
            else
        {
            return nil
        }
        return Date(timeInterval: TimeInterval(ttl), since: createDate)
    }
    
    /// Time to Live.
    public var timeToLive: Int? {
        return safeDecodingRawData(with: .temporaryTTL)
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
    
    /// Refresh temporary conversation's data.
    ///
    /// - Parameter completion: callback
    public override func refresh(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self.client?.conversationQuery.getTemporaryConversations(by: [self.ID], completion: { (result) in
            switch result {
            case .success(value: let tempConvs):
                if tempConvs.isEmpty {
                    let error = LCError(code: .conversationNotFound)
                    completion(.failure(error: error))
                } else {
                    completion(.success)
                }
            case .failure(error: let error):
                completion(.failure(error: error))
            }
        })
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
