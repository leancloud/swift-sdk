//
//  Conversation.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/11/26.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/// IM Conversation
public class LCConversation {
    
    typealias RawData = [String: Any]
    
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
    
    public enum LCType: Int {
        case normal = 1
        case transient = 2
        case system = 3
        case temporary = 4
    }
    
    public private(set) weak var client: LCClient?

    public let ID: String
    
    public let clientID: String
    
    public let type: LCType
    
    public let isUnique: Bool
    
    public let uniqueID: String?

    public var name: String? {
        return safeDecodingRawData(with: .name)
    }
    
    public var creator: String? {
        return safeDecodingRawData(with: .creator)
    }

    public var createdAt: Date? {
        if let str: String = safeDecodingRawData(with: .createdAt) {
            return LCDate(isoString: str)?.value
        } else {
            return nil
        }
    }
    
    public var updatedAt: Date? {
        if let str: String = safeDecodingRawData(with: .updatedAt) {
            return LCDate(isoString: str)?.value
        } else {
            return nil
        }
    }
    
    public var attributes: [String: Any]? {
        return safeDecodingRawData(with: .attributes)
    }
    
    public var members: [String]? {
        return safeDecodingRawData(with: .members)
    }
    
    public var isMuted: Bool {
        if let mutedMembers: [String] = safeDecodingRawData(with: .mutedMembers),
            mutedMembers.contains(clientID) {
            return true
        } else {
            return false
        }
    }
    
    public private(set) var isOutdated: Bool {
        set {
            self.mutex.lock()
            self.underlyingOutdated = newValue
            self.mutex.unlock()
        }
        get {
            let value: Bool
            self.mutex.lock()
            value = self.underlyingOutdated
            self.mutex.unlock()
            return value
        }
    }
    private var underlyingOutdated: Bool = false
    
    public var lastMessage: LCMessage? {
        var message: LCMessage? = nil
        self.mutex.lock()
        message = self.underlyingLastMessage
        self.mutex.unlock()
        return message
    }
    private var underlyingLastMessage: LCMessage? = nil
    
    public var unreadMessageCount: Int {
        var count: Int = 0
        self.mutex.lock()
        count = self.underlyingUnreadMessageCount
        self.mutex.unlock()
        return count
    }
    private var underlyingUnreadMessageCount: Int = 0
    
    public var isUnreadMessageContainMention: Bool {
        get {
            var value: Bool
            self.mutex.lock()
            value = self.underlyingIsUnreadMessageContainMention
            self.mutex.unlock()
            return value
        }
        set {
            self.mutex.lock()
            self.underlyingIsUnreadMessageContainMention = newValue
            self.mutex.unlock()
        }
    }
    private var underlyingIsUnreadMessageContainMention: Bool = false
    
    public subscript(key: String) -> Any? {
        get { return safeDecodingRawData(with: key) }
    }
    
    static func instance(ID: String, rawData: RawData, client: LCClient) -> LCConversation {
        var type: LCType = .normal
        if let convType: Int = rawData[Key.convType.rawValue] as? Int,
            let validType = LCType(rawValue: convType) {
            type = validType
        } else {
            if let transient: Bool = rawData[Key.transient.rawValue] as? Bool,
                transient == true {
                type = .transient
            } else if let system: Bool = rawData[Key.system.rawValue] as? Bool,
                system == true {
                type = .system
            } else if let temporary: Bool = rawData[Key.temporary.rawValue] as? Bool,
                temporary == true {
                type = .temporary
            } else if ID.hasPrefix(LCTemporaryConversation.prefixOfID) {
                type = .temporary
            }
        }
        switch type {
        case .normal:
            return LCConversation(ID: ID, rawData: rawData, type: type, client: client)
        case .transient:
            return LCChatRoom(ID: ID, rawData: rawData, type: type, client: client)
        case .system:
            return LCServiceConversation(ID: ID, rawData: rawData, type: type, client: client)
        case .temporary:
            return LCTemporaryConversation(ID: ID, rawData: rawData, type: type, client: client)
        }
    }

    init(ID: String, rawData: RawData, type: LCType, client: LCClient) {
        #if DEBUG
        self.specificKey = client.specificKey
        self.specificValue = client.specificValue
        #endif
        self.ID = ID
        self.client = client
        self.rawData = rawData
        self.clientID = client.ID
        self.eventQueue = client.eventQueue
        self.type = type
        self.isUnique = (rawData[Key.unique.rawValue] as? Bool) ?? false
        self.uniqueID = (rawData[Key.uniqueId.rawValue] as? String)
        self.decodingLastMessage()
    }
    
    private let eventQueue: DispatchQueue
    
    private var rawData: RawData
    
    private let mutex = NSLock()
    
    var notTransientConversation: Bool {
        return self.type != .transient
    }

}

// MARK: - Message Sending

extension LCConversation {
    
    public struct MessageSendOptions: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let `default`: MessageSendOptions = []
        public static let needReceipt = MessageSendOptions(rawValue: 1 << 0)
        public static let isTransient = MessageSendOptions(rawValue: 1 << 1)
        public static let isAutoDeliveringWhenOffline = MessageSendOptions(rawValue: 1 << 2)
    }
    
    public func send(
        message: LCMessage,
        options: MessageSendOptions = .default,
        priority: LCChatRoom.MessagePriority? = nil,
        pushData: [String: Any]? = nil,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
    {
        guard message.status == .none || message.status == .failed else {
            throw LCError(
                code: .inconsistency,
                reason: "Only the message that status is \(LCMessage.Status.none) or \(LCMessage.Status.failed) can be sent"
            )
        }
        message.setup(clientID: self.clientID, conversationID: self.ID)
        message.update(status: .sending)
        message.isTransient = options.contains(.isTransient)
        if message.notTransientMessage, self.notTransientConversation, message.dToken == nil {
            // if not transient message and not transient conversation
            // then using a token to prevent Message Duplicating.
            message.dToken = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            message.sendingTimestamp = Int64(Date().timeIntervalSince1970 * 1000.0)
        }
        try self.preprocess(message: message, pushData: pushData, progress: progress) { (pushDataString: String?, error: LCError?) in
            if let error: LCError = error {
                message.update(status: .failed)
                self.eventQueue.async {
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
                if options.contains(.isAutoDeliveringWhenOffline) {
                    directCommand.will = true
                }
                if options.contains(.needReceipt) {
                    directCommand.r = true
                }
                if let pushData: String = pushDataString {
                    directCommand.pushData = pushData
                }
                if message.isTransient {
                    directCommand.transient = true
                }
                if let dt: String = message.dToken {
                    directCommand.dt = dt
                }
                outCommand.directMessage = directCommand
                return outCommand
            }, completion: { (result) in
                switch result {
                case .inCommand(let inCommand):
                    assert(self.specificAssertion)
                    if let ack: IMAckCommand = (inCommand.hasAckMessage ? inCommand.ackMessage : nil),
                        let messageID: String = (ack.hasUid ? ack.uid : nil),
                        let timestamp: Int64 = (ack.hasT ? ack.t : nil) {
                        message.update(status: .sent, ID: messageID, timestamp: timestamp)
                        self.eventQueue.async {
                            completion(.success)
                        }
                    } else if let ack: IMAckCommand = (inCommand.hasAckMessage ? inCommand.ackMessage : nil),
                        ack.hasCode || ack.hasAppCode {
                        var userInfo: LCError.UserInfo? = [:]
                        let code: Int = Int(ack.code)
                        let reason: String? = (ack.hasReason ? ack.reason : nil)
                        if ack.hasAppCode { userInfo?["appCode"] = ack.appCode }
                        do {
                            userInfo = try userInfo?.jsonObject()
                        } catch {
                            Logger.shared.error(error)
                        }
                        message.update(status: .failed)
                        self.eventQueue.async {
                            let error = LCError(code: code, reason: reason, userInfo: userInfo)
                            completion(.failure(error: error))
                        }
                    } else {
                        message.update(status: .failed)
                        self.eventQueue.async {
                            let error = LCError(code: .commandInvalid)
                            completion(.failure(error: error))
                        }
                    }
                case .error(let error):
                    message.update(status: .failed)
                    self.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            })
        }
    }
    
    private func preprocess(
        message: LCMessage,
        pushData: [String: Any]?,
        progress: ((Double) -> Void)?,
        completion: @escaping (String?, LCError?) -> Void)
        throws
    {
        var pushDataString: String? = nil
        if let pushData: [String: Any] = pushData {
            let data: Data = try JSONSerialization.data(withJSONObject: pushData, options: [])
            pushDataString = String(data: data, encoding: .utf8)
        }
        guard let categorizedMessage: LCCategorizedMessage = message as? LCCategorizedMessage else {
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

// MARK: - Internal

internal extension LCConversation {
    
    enum RawDataChangeOperation {
        
        case rawDataMerging(data: RawData)
        
        case rawDataReplaced(by: RawData)
        
        case append(members: Set<String>)
        
        case remove(members: Set<String>)
        
    }
    
    func safeChangingRawData(operation: RawDataChangeOperation) {
        self.mutex.lock()
        switch operation {
        case .rawDataMerging(data: let data):
            self.rawData = self.rawData.merging(data) { (_, new) in new }
        case .rawDataReplaced(by: let data):
            self.rawData = data
        case .append(members: let joinedMembers):
            guard !joinedMembers.isEmpty else { break }
            if var originMembers: [String] = self.decodingRawData(with: .members) {
                let originMembersSet: Set<String> = Set<String>(originMembers)
                for member in joinedMembers {
                    if !originMembersSet.contains(member) {
                        originMembers.append(member)
                    }
                }
                self.rawData[Key.members.rawValue] = originMembers
            } else {
                self.rawData[Key.members.rawValue] = joinedMembers
            }
        case .remove(members: let leftMembers):
            guard
                !leftMembers.isEmpty,
                var originMembers: [String] = self.decodingRawData(with: .members)
                else
            { break }
            for member in leftMembers {
                if let index = originMembers.firstIndex(of: member) {
                    originMembers.remove(at: index)
                }
                if member == self.clientID {
                    /*
                     if this client has left this conversation,
                     then can consider thsi conversation's data is outdated
                     */
                    self.underlyingOutdated = true
                }
            }
            self.rawData[Key.members.rawValue] = originMembers
        }
        self.mutex.unlock()
    }
    
    func safeUpdatingLastMessage(newMessage: LCMessage, unreadCount: Int? = nil, unreadMentioned: Bool? = nil) {
        guard
            newMessage.notTransientMessage,
            self.notTransientConversation
            else
        { return }
        var messageEvent: LCMessageEvent?
        let updatingClosure: (Bool, Int?) -> Void = { (shouldUpdatingLastMessage, newUnreadCount) in
            if let newCount: Int = newUnreadCount {
                let oldCount: Int = self.underlyingUnreadMessageCount
                self.underlyingUnreadMessageCount = newCount
                if let isMentioned: Bool = unreadMentioned {
                    self.underlyingIsUnreadMessageContainMention = isMentioned
                }
                let isUnreadMessageCountUpdated: Bool = (oldCount != newCount)
                if shouldUpdatingLastMessage {
                    self.underlyingLastMessage = newMessage
                    if isUnreadMessageCountUpdated {
                        messageEvent = .lastMessageAndUnreadMessageCountUpdated
                    } else {
                        messageEvent = .lastMessageUpdated
                    }
                } else if isUnreadMessageCountUpdated {
                    messageEvent = .unreadMessageCountUpdated
                }
            } else if shouldUpdatingLastMessage {
                self.underlyingLastMessage = newMessage
                messageEvent = .lastMessageUpdated
            }
        }
        self.mutex.lock()
        if let oldMessage = self.underlyingLastMessage,
            let newTimestamp: Int64 = newMessage.sentTimestamp,
            let oldTimestamp: Int64 = oldMessage.sentTimestamp,
            let newMessageID: String = newMessage.ID,
            let oldMessageID: String = oldMessage.ID {
            if newTimestamp > oldTimestamp {
                let realUnreadCount: Int = unreadCount ?? (self.underlyingUnreadMessageCount + 1)
                updatingClosure(true, realUnreadCount)
            } else if newTimestamp == oldTimestamp {
                let timestampCompareResult: ComparisonResult = newMessageID.compare(oldMessageID)
                if timestampCompareResult == .orderedDescending {
                    let realUnreadCount: Int = unreadCount ?? (self.underlyingUnreadMessageCount + 1)
                    updatingClosure(true, realUnreadCount)
                } else if timestampCompareResult == .orderedSame {
                    let newPatchTimestamp: Int64? = newMessage.patchedTimestamp
                    let oldPatchTimestamp: Int64? = oldMessage.patchedTimestamp
                    if let newValue: Int64 = newPatchTimestamp,
                        let oldValue: Int64 = oldPatchTimestamp,
                        newValue > oldValue {
                        updatingClosure(true, unreadCount)
                    } else if newPatchTimestamp != nil, oldPatchTimestamp == nil {
                        updatingClosure(true, unreadCount)
                    } else {
                        updatingClosure(false, unreadCount)
                    }
                } else {
                    updatingClosure(false, unreadCount)
                }
            } else {
                updatingClosure(false, unreadCount)
            }
        } else {
            let realUnreadCount: Int = unreadCount ?? (self.underlyingUnreadMessageCount + 1)
            updatingClosure(true, realUnreadCount)
        }
        self.mutex.unlock()
        if let client = self.client, let event = messageEvent {
            self.eventQueue.async {
                let conversationEvent = LCConversationEvent.message(event: event)
                client.delegate?.client(client, conversation: self, event: conversationEvent)
            }
        }
    }
    
    func process(unreadTuple: IMUnreadTuple) {
        guard
            self.notTransientConversation,
            unreadTuple.hasUnread
            else
        { return }
        let unreadCount: Int = Int(unreadTuple.unread)
        let unreadMentioned: Bool? = (unreadTuple.hasMentioned ? unreadTuple.mentioned : nil)
        let lastMessage: LCMessage? = {
            guard
                let timestamp: Int64 = (unreadTuple.hasTimestamp ? unreadTuple.timestamp : nil),
                let messageID: String = (unreadTuple.hasMid ? unreadTuple.mid : nil)
                else
            { return nil }
            var content: LCMessage.Content? = nil
            if unreadTuple.hasData {
                content = .string(unreadTuple.data)
            } else if unreadTuple.hasBinaryMsg {
                content = .data(unreadTuple.binaryMsg)
            }
            let message = LCMessage.instance(
                isTransient: false,
                conversationID: self.ID,
                localClientID: self.clientID,
                fromClientID: (unreadTuple.hasFrom ? unreadTuple.from : nil),
                timestamp: timestamp,
                patchedTimestamp: (unreadTuple.hasPatchTimestamp ? unreadTuple.patchTimestamp : nil),
                messageID: messageID,
                content: content,
                isAllMembersMentioned: nil,
                mentionedMembers: nil,
                status: .sent
            )
            return message
        }()
        if let message: LCMessage = lastMessage {
            self.safeUpdatingLastMessage(
                newMessage: message,
                unreadCount: unreadCount,
                unreadMentioned: unreadMentioned
            )
        } else {
            var unreadEvent: LCMessageEvent?
            self.mutex.lock()
            let oldUnreadCount: Int = self.underlyingUnreadMessageCount
            self.underlyingUnreadMessageCount = unreadCount
            if let isMentioned: Bool = unreadMentioned {
                self.underlyingIsUnreadMessageContainMention = isMentioned
            }
            if oldUnreadCount != unreadCount {
                unreadEvent = .unreadMessageCountUpdated
            }
            self.mutex.unlock()
            if let client = self.client, let messageEvent = unreadEvent {
                self.eventQueue.async {
                    let event = LCConversationEvent.message(event: messageEvent)
                    client.delegate?.client(client, conversation: self, event: event)
                }
            }
        }
    }
    
}

// MARK: - Private

private extension LCConversation {
    
    func safeDecodingRawData<T>(with key: Key) -> T? {
        return self.safeDecodingRawData(with: key.rawValue)
    }
    
    func safeDecodingRawData<T>(with string: String) -> T? {
        var value: T? = nil
        self.mutex.lock()
        value = self.decodingRawData(with: string)
        self.mutex.unlock()
        return value
    }
    
    func decodingRawData<T>(with key: Key) -> T? {
        return self.decodingRawData(with: key.rawValue)
    }
    
    func decodingRawData<T>(with string: String) -> T? {
        return self.rawData[string] as? T
    }
    
    func decodingLastMessage() {
        guard
            self.notTransientConversation,
            let timestamp: Int64 = self.decodingRawData(with: .lastMessageTimestamp),
            let messageID: String = self.decodingRawData(with: .lastMessageId)
            else
        { return }
        var content: LCMessage.Content? = nil
        if let string: String = self.decodingRawData(with: .lastMessageString) {
            content = .string(string)
        } else if let data: Data = self.decodingRawData(with: .lastMessageBinary) {
            content = .data(data)
        }
        let message = LCMessage.instance(
            isTransient: false,
            conversationID: self.ID,
            localClientID: self.clientID,
            fromClientID: self.decodingRawData(with: .lastMessageFrom),
            timestamp: timestamp,
            patchedTimestamp: self.decodingRawData(with: .lastMessagePatchTimestamp),
            messageID: messageID,
            content: content,
            isAllMembersMentioned: self.decodingRawData(with: .lastMessageMentionAll),
            mentionedMembers: self.decodingRawData(with: .lastMessageMentionPids),
            status: .sent
        )
        /// set in initialization, so no need mutex.
        self.underlyingLastMessage = message
    }
    
}

/// IM Chat Room
public class LCChatRoom: LCConversation {
    
    public enum MessagePriority: Int {
        case high = 1
        case normal = 2
        case low = 3
    }
    
}

/// IM Service Conversation
public class LCServiceConversation: LCConversation {}

/// IM Temporary Conversation
public class LCTemporaryConversation: LCConversation {
    
    static let prefixOfID: String = "_tmp:"
    
    public var timeToLive: Int? {
        return safeDecodingRawData(with: .temporaryTTL)
    }
    
}
