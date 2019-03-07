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
    
    /// add `lc` prefix to avoid conflict
    let lcType: ConvType
    
    public private(set) weak var client: IMClient?

    public let ID: String
    
    public let clientID: String
    
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
            mutedMembers.contains(self.clientID) {
            return true
        } else {
            return false
        }
    }
    
    public internal(set) var isOutdated: Bool {
        set {
            sync(self.underlyingOutdated = newValue)
        }
        get {
            var value: Bool = false
            sync(value = self.underlyingOutdated)
            return value
        }
    }
    private var underlyingOutdated: Bool = false
    
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
    
    public subscript(key: String) -> Any? {
        get { return safeDecodingRawData(with: key) }
    }
    
    static func instance(ID: String, rawData: RawData, client: IMClient) -> IMConversation {
        var convType: ConvType = .normal
        if let typeRawValue: Int = rawData[Key.convType.rawValue] as? Int,
            let validType = ConvType(rawValue: typeRawValue) {
            convType = validType
        } else {
            if let transient: Bool = rawData[Key.transient.rawValue] as? Bool,
                transient == true {
                convType = .transient
            } else if let system: Bool = rawData[Key.system.rawValue] as? Bool,
                system == true {
                convType = .system
            } else if let temporary: Bool = rawData[Key.temporary.rawValue] as? Bool,
                temporary == true {
                convType = .temporary
            } else if ID.hasPrefix(IMTemporaryConversation.prefixOfID) {
                convType = .temporary
            }
        }
        switch convType {
        case .normal:
            return IMConversation(ID: ID, rawData: rawData, lcType: convType, client: client)
        case .transient:
            return IMChatRoom(ID: ID, rawData: rawData, lcType: convType, client: client)
        case .system:
            return IMServiceConversation(ID: ID, rawData: rawData, lcType: convType, client: client)
        case .temporary:
            return IMTemporaryConversation(ID: ID, rawData: rawData, lcType: convType, client: client)
        }
    }

    init(ID: String, rawData: RawData, lcType: ConvType, client: IMClient) {
        self.ID = ID
        self.client = client
        self.rawData = rawData
        self.lock = client.lock
        self.clientID = client.ID
        self.lcType = lcType
        self.isUnique = (rawData[Key.unique.rawValue] as? Bool) ?? false
        self.uniqueID = (rawData[Key.uniqueId.rawValue] as? String)
        if let message = self.decodingLastMessage(from: rawData) {
            self.safeUpdatingLastMessage(newMessage: message, client: client)
        }
    }
    
    private(set) var rawData: RawData
    
    let lock: NSLock
    
    var notTransientConversation: Bool {
        return self.lcType != .transient
    }
    
    var notServiceConversation: Bool {
        return self.lcType != .system
    }
    
    /* Due to IMTemporaryConversation should override these functions, so they can't define in extension. */
    
    public func join(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self.add(members: [self.clientID]) { result in
            switch result {
            case .allSucceeded:
                completion(.success)
            case .failure(error: let error):
                completion(.failure(error: error))
            case .segment(success: _, failure: let errors):
                let error = (errors.first?.error ?? LCError(code: .malformedData))
                completion(.failure(error: error))
            }
        }
    }
    
    public func leave(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self.remove(members: [self.clientID]) { result in
            switch result {
            case .allSucceeded:
                completion(.success)
            case .failure(error: let error):
                completion(.failure(error: error))
            case .segment(success: _, failure: let errors):
                let error = (errors.first?.error ?? LCError(code: .malformedData))
                completion(.failure(error: error))
            }
        }
    }
    
    public func add(members: Set<String>, completion: @escaping (MemberResult) -> Void) throws {
        try self.update(members: members, op: .add, completion: completion)
    }
    
    public func remove(members: Set<String>, completion: @escaping (MemberResult) -> Void) throws {
        try self.update(members: members, op: .remove, completion: completion)
    }
    
    public func mute(completion: @escaping (LCBooleanResult) -> Void) {
        self.sendMuteOrUnmute(op: .mute, completion: completion)
    }
    
    public func unmute(completion: @escaping (LCBooleanResult) -> Void) {
        self.sendMuteOrUnmute(op: .unmute, completion: completion)
    }
    
    public func refresh(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self.client?.conversationQuery.getConversation(by: self.ID, completion: { (result) in
            switch result {
            case .success(value: _):
                completion(.success)
            case .failure(error: let error):
                completion(.failure(error: error))
            }
        })
    }
    
    public func update(with data: [String: Any], completion: @escaping (LCBooleanResult) -> Void) throws {
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
                        self.safeChangingRawData(operation: .updated(attr: data, attrModified: attrModified, udate: udate), client: client)
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

}

extension IMConversation: InternalSynchronizing {
    
    var mutex: NSLock {
        return self.lock
    }
    
}

// MARK: - Message Sending

extension IMConversation {
    
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
        if message.notTransientMessage, self.notTransientConversation, message.dToken == nil {
            // if not transient message and not transient conversation
            // then using a token to prevent Message Duplicating.
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

// MARK: - Message Reading

extension IMConversation {
    
    public func read(message: IMMessage? = nil) {
        guard
            self.notTransientConversation,
            self.unreadMessageCount > 0,
            let readMessage: IMMessage = message ?? self.lastMessage,
            let messageID: String = readMessage.ID,
            let timestamp: Int64 = readMessage.sentTimestamp
            else
        { return }
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
        guard
            self.notTransientConversation,
            unreadTuple.hasUnread
            else
        { return }
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
                isTransient: false,
                conversationID: self.ID,
                localClientID: self.clientID,
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
                client.delegate?.client(client, conversation: self, event: .unreadMessageUpdated)
            }
        }
    }
    
}

// MARK: - Message Updating

extension IMConversation {
    
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
            isTransient: false,
            conversationID: self.ID,
            localClientID: self.clientID,
            fromClientID: (patchItem.hasFrom ? patchItem.from : nil),
            timestamp: timestamp,
            patchedTimestamp: (patchItem.hasPatchTimestamp ? patchItem.patchTimestamp : nil),
            messageID: messageID,
            content: content,
            isAllMembersMentioned: (patchItem.hasMentionAll ? patchItem.mentionAll : nil),
            mentionedMembers: (patchItem.mentionPids.count > 0 ? patchItem.mentionPids : nil)
        )
        self.safeUpdatingLastMessage(newMessage: patchedMessage, client: client)
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

// MARK: - Message Receipt Timestamp

extension IMConversation {
    
    public struct MessageReceiptFlag {
        public let readFlagTimestamp: Int64?
        public var readFlagDate: Date? {
            return IMClient.date(fromMillisecond: self.readFlagTimestamp)
        }
        public let deliveredFlagTimestamp: Int64?
        public var deliveredFlagDate: Date? {
            return IMClient.date(fromMillisecond: self.deliveredFlagTimestamp)
        }
    }
    
    public func getMessageReceiptFlag(completion: @escaping (LCGenericResult<MessageReceiptFlag>) -> Void) throws {
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

// MARK: - Message Query

extension IMConversation {
    
    public static let limitRangeOfMessageQuery = 1...100
    
    public struct MessageQueryEndpoint {
        public let messageID: String?
        public let sentTimestamp: Int64?
        public let isClosed: Bool?
    }
    
    public enum MessageQueryDirection: Int {
        case newToOld = 1
        case oldToNew = 2
        
        internal var protobufEnum: IMLogsCommand.QueryDirection {
            switch self {
            case .newToOld:
                return .old
            case .oldToNew:
                return .new
            }
        }
    }
    
    public func queryMessage(
        start: MessageQueryEndpoint? = nil,
        end: MessageQueryEndpoint? = nil,
        direction: MessageQueryDirection? = nil,
        limit: Int? = nil,
        type: IMMessageCategorizing.MessageType? = nil,
        completion: @escaping (LCGenericResult<[IMMessage]>) -> Void)
        throws
    {
        if let limit: Int = limit {
            guard IMConversation.limitRangeOfMessageQuery.contains(limit) else {
                throw LCError(
                    code: .inconsistency,
                    reason: "limit should in range \(IMConversation.limitRangeOfMessageQuery)"
                )
            }
        }
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
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
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                if inCommand.hasLogsMessage {
                    var messages: [IMMessage] = []
                    for item in inCommand.logsMessage.logs {
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
                                if let decodedData = Data(base64Encoded: item.data) {                                
                                    content = .data(decodedData)
                                }
                            } else {
                                content = .string(item.data)
                            }
                        }
                        let message = IMMessage.instance(
                            isTransient: false,
                            conversationID: self.ID,
                            localClientID: client.ID,
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
                    client.eventQueue.async {
                        completion(.success(value: messages))
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

// MARK: - Members

extension IMConversation {
    
    public enum MemberResult: LCResultType {
        case allSucceeded
        case failure(error: LCError)
        case segment(success: [String]?, failure: [(IDs: [String], error: LCError)])
        
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
    
    private func update(members: Set<String>, op: IMOpType, completion: @escaping (MemberResult) -> Void) throws {
        guard !members.isEmpty else {
            throw LCError(code: .inconsistency, reason: "parameter `members` should not be empty.")
        }
        for memberID in members {
            guard IMClient.lengthRangeOfClientID.contains(memberID.count) else {
                throw LCError.clientIDInvalid
            }
        }
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = op
            var convCommand = IMConvCommand()
            convCommand.cid = self.ID
            convCommand.m = Array<String>(members)
            outCommand.convMessage = convCommand
            return outCommand
        }, completion: { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                if let convCommand = (inCommand.hasConvMessage ? inCommand.convMessage : nil) {
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
                        memberResult = .segment(success: successIDs, failure: failures)
                    }
                    switch inCommand.op {
                    case .added:
                        self.safeChangingRawData(operation: .append(members: Set(allowedPids)), client: client)
                    case .removed:
                        self.safeChangingRawData(operation: .remove(members: Set(allowedPids)), client: client)
                    default:
                        break
                    }
                    client.eventQueue.async {
                        completion(memberResult)
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

// MARK: - Mute

extension IMConversation {
    
    private func sendMuteOrUnmute(op: IMOpType, completion: @escaping (LCBooleanResult) -> Void) {
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
                if inCommand.cmd == .conv, inCommand.op == .updated {
                    let operation: RawDataChangeOperation = ((op == .mute) ? .muted : .unmuted)
                    self.safeChangingRawData(operation: operation, client: client)
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

// MARK: - Internal

internal extension IMConversation {
    
    enum RawDataChangeOperation {
        case rawDataMerging(data: RawData)
        case rawDataReplaced(by: RawData)
        case append(members: Set<String>)
        case remove(members: Set<String>)
        case updated(attr: [String: Any], attrModified: [String: Any], udate: String)
        case muted
        case unmuted
    }
    
    private class KeyAndDictionary {
        let key: String
        var dictionary: [String: Any]
        init(key: String, dictionary: [String: Any]) {
            self.key = key
            self.dictionary = dictionary
        }
    }
    
    func safeChangingRawData(operation: RawDataChangeOperation, client: IMClient) {
        assert(client.specificAssertion)
        switch operation {
        case .rawDataMerging(data: let data):
            sync(self.rawData = self.rawData.merging(data) { (_, new) in new })
        case .rawDataReplaced(by: let data):
            sync(self.rawData = data)
            if let message = self.decodingLastMessage(from: data) {
                self.safeUpdatingLastMessage(newMessage: message, client: client)
            }
        case .append(members: let joinedMembers):
            guard
                self.notTransientConversation,
                self.notServiceConversation,
                !joinedMembers.isEmpty
                else
            { break }
            let newMembers: [String]
            if let originMembers: [String] = self.members {
                let newMemberSet: Set<String> = Set(originMembers).union(joinedMembers)
                newMembers = Array(newMemberSet)
            } else {
                newMembers = Array(joinedMembers)
            }
            self.safeUpdatingRawData(key: .members, value: newMembers)
        case .remove(members: let leftMembers):
            guard
                self.notTransientConversation,
                self.notServiceConversation,
                !leftMembers.isEmpty
                else
            { break }
            if leftMembers.contains(self.clientID) {
                self.isOutdated = true
            }
            if let originMembers: [String] = self.members {
                let newMembers: [String] = Array(Set(originMembers).subtracting(leftMembers))
                self.safeUpdatingRawData(key: .members, value: newMembers)
            }
        case .muted, .unmuted:
            guard self.notTransientConversation else {
                return
            }
            let key = Key.mutedMembers
            var newMutedMembers: [String]
            if let originMutedMembers: [String] = self.safeDecodingRawData(with: key) {
                var set = Set(originMutedMembers)
                if case .muted = operation {
                    set.insert(self.clientID)
                } else {
                    set.remove(self.clientID)
                }
                newMutedMembers = Array(set)
            } else {
                if case .muted = operation {
                    newMutedMembers = [self.clientID]
                } else {
                    newMutedMembers = []
                }
            }
            self.safeUpdatingRawData(key: key, value: newMutedMembers)
        case .updated(attr: let attr, attrModified: let attrModified, let udate):
            if let updateAt = self.updatedAt {
                guard
                    let updateDate: Date = LCDate(isoString: udate)?.value,
                    updateDate > updateAt
                    else
                { return }
            }
            var rawDataCopy: RawData! = nil
            sync(rawDataCopy = self.rawData)
            for key in attr.keys {
                var stack: [KeyAndDictionary] = []
                var modifiedValue: Any? = nil
                for subkey in key.components(separatedBy: ".") {
                    if stack.isEmpty {
                        let nestStruct = KeyAndDictionary(
                            key: subkey,
                            dictionary: rawDataCopy
                        )
                        stack.insert(nestStruct, at: 0)
                        modifiedValue = attrModified[subkey]
                    } else {
                        let newNestStruct = KeyAndDictionary(
                            key: subkey,
                            dictionary: (stack[0].dictionary[stack[0].key] as? [String: Any]) ?? [:]
                        )
                        stack.insert(newNestStruct, at: 0)
                        if let modifiedDic: [String: Any] = modifiedValue as? [String: Any] {
                            modifiedValue = modifiedDic[subkey]
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
                        let preItem = stack[index - 1]
                        item.dictionary[item.key] = preItem.dictionary
                    }
                }
                if let newRawData = stack.last?.dictionary {
                    rawDataCopy = newRawData
                }
            }
            rawDataCopy[Key.updatedAt.rawValue] = udate
            sync(self.rawData = rawDataCopy)
        }
    }
    
    @discardableResult
    func safeUpdatingLastMessage(newMessage: IMMessage, client: IMClient) -> Bool {
        assert(client.specificAssertion)
        var isUnreadMessageIncreased: Bool = false
        guard
            newMessage.notTransientMessage,
            newMessage.notWillMessage,
            self.notTransientConversation
            else
        { return isUnreadMessageIncreased }
        var messageEvent: IMConversationEvent?
        let updatingLastMessageClosure: (Bool) -> Void = { oldMessageReplacedByAnother in
            self.lastMessage = newMessage
            messageEvent = .lastMessageUpdated
            if oldMessageReplacedByAnother && newMessage.ioType == .in {
                isUnreadMessageIncreased = true
            }
        }
        if let oldMessage = self.lastMessage,
            let newTimestamp: Int64 = newMessage.sentTimestamp,
            let oldTimestamp: Int64 = oldMessage.sentTimestamp,
            let newMessageID: String = newMessage.ID,
            let oldMessageID: String = oldMessage.ID {
            if newTimestamp > oldTimestamp {
                updatingLastMessageClosure(true)
            } else if newTimestamp == oldTimestamp {
                let messageIDCompareResult: ComparisonResult = newMessageID.compare(oldMessageID)
                if messageIDCompareResult == .orderedDescending {
                    updatingLastMessageClosure(true)
                } else if messageIDCompareResult == .orderedSame {
                    let newPatchTimestamp: Int64? = newMessage.patchedTimestamp
                    let oldPatchTimestamp: Int64? = oldMessage.patchedTimestamp
                    if let newValue: Int64 = newPatchTimestamp,
                        let oldValue: Int64 = oldPatchTimestamp,
                        newValue > oldValue {
                        updatingLastMessageClosure(false)
                    } else if let _ = newPatchTimestamp, oldPatchTimestamp == nil {
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
    
}

// MARK: - Private

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
        return self.decoding(string: string, from: self.rawData)
    }
    
    func decoding<T>(key: Key, from data: RawData) -> T? {
        return self.decoding(string: key.rawValue, from: data)
    }
    
    func decoding<T>(string: String, from data: RawData) -> T? {
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
    
    func decodingLastMessage(from data: RawData) -> IMMessage? {
        guard
            self.notTransientConversation,
            let timestamp: Int64 = self.decoding(key: .lastMessageTimestamp, from: data),
            let messageID: String = self.decoding(key: .lastMessageId, from: data)
            else
        {
            return nil
        }
        var content: IMMessage.Content? = nil
        /*
         For Compatibility,
         Should check `lastMessageBinary` at first.
         Then check `lastMessageString`.
         */
        if let data: Data = self.decoding(key: .lastMessageBinary, from: data) {
            content = .data(data)
        } else if let string: String = self.decoding(key: .lastMessageString, from: data) {
            content = .string(string)
        }
        let message = IMMessage.instance(
            isTransient: false,
            conversationID: self.ID,
            localClientID: self.clientID,
            fromClientID: self.decoding(key: .lastMessageFrom, from: data),
            timestamp: timestamp,
            patchedTimestamp: self.decoding(key: .lastMessagePatchTimestamp, from: data),
            messageID: messageID,
            content: content,
            isAllMembersMentioned: self.decoding(key: .lastMessageMentionAll, from: data),
            mentionedMembers: self.decoding(key: .lastMessageMentionPids, from: data)
        )
        return message
    }
    
}

/// IM Chat Room
public class IMChatRoom: IMConversation {
    
    public enum MessagePriority: Int {
        case high = 1
        case normal = 2
        case low = 3
    }
    
    @available(*, unavailable)
    public override func mute(completion: @escaping (LCBooleanResult) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }
    
    @available(*, unavailable)
    public override func unmute(completion: @escaping (LCBooleanResult) -> Void) {
        completion(.failure(error: LCError.conversationNotSupport(convType: type(of: self))))
    }
    
    public func getOnlineMemberCount(completion: @escaping (LCCountResult) -> Void) {
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
    
}

/// IM Service Conversation
public class IMServiceConversation: IMConversation {
    
    @available(*, unavailable)
    public override func update(with data: [String : Any], completion: @escaping (LCBooleanResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }
    
    public func subscribe(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self.join(completion: completion)
    }
    
    public func unsubscribe(completion: @escaping (LCBooleanResult) -> Void) throws {
        try self.leave(completion: completion)
    }
    
}

/// IM Temporary Conversation
/// Temporary Conversation is unique in it's Life Cycle.
public class IMTemporaryConversation: IMConversation {
    
    static let prefixOfID: String = "_tmp:"
    
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
    public override func update(with data: [String : Any], completion: @escaping (LCBooleanResult) -> Void) throws {
        throw LCError.conversationNotSupport(convType: type(of: self))
    }
    
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
