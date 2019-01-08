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
    
    public final private(set) weak var client: LCClient?

    public final let ID: String
    
    public final let clientID: String
    
    public final let type: LCType
    
    public final let isUnique: Bool
    
    public final let uniqueID: String?

    public final var name: String? {
        return safeDecodingRawData(with: .name)
    }
    
    public final var creator: String? {
        return safeDecodingRawData(with: .creator)
    }

    public final var createdAt: Date? {
        if let str: String = safeDecodingRawData(with: .createdAt) {
            return LCDate(isoString: str)?.value
        } else {
            return nil
        }
    }
    
    public final var updatedAt: Date? {
        if let str: String = safeDecodingRawData(with: .updatedAt) {
            return LCDate(isoString: str)?.value
        } else {
            return nil
        }
    }
    
    public final var attributes: [String: Any]? {
        return safeDecodingRawData(with: .attributes)
    }
    
    public final var members: [String]? {
        return safeDecodingRawData(with: .members)
    }
    
    public final var isMuted: Bool {
        if let mutedMembers: [String] = safeDecodingRawData(with: .mutedMembers),
            mutedMembers.contains(clientID) {
            return true
        } else {
            return false
        }
    }
    
    public final internal(set) var lastMessage: LCMessage? {
        get {
            var message: LCMessage? = nil
            self.mutex.lock()
            message = _lastMessage
            self.mutex.unlock()
            return message
        }
        set {
            self.mutex.lock()
            _lastMessage = newValue
            self.mutex.unlock()
        }
    }
    private var _lastMessage: LCMessage? = nil
    
    public final subscript(key: String) -> Any? {
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
        self.lastMessageDecoding()
    }
    
    private let eventQueue: DispatchQueue
    
    private var rawData: RawData
    
    private let mutex = NSLock()
    
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
        completion: @escaping (LCBooleanResult) -> Void)
    {
        var pushDataString: String? = nil
        if let pushData = pushData {
            do {
                let data: Data = try JSONSerialization.data(withJSONObject: pushData, options: [])
                pushDataString = String(data: data, encoding: .utf8)
            } catch {
                self.eventQueue.async {
                    completion(.failure(error: LCError(error: error)))
                }
                return
            }
        }
        var outCommand = IMGenericCommand()
        self.client?.sendCommand(constructor: { () -> IMGenericCommand in
            outCommand.cmd = .direct
            if let priority = priority {
                outCommand.priority = Int32(priority.rawValue)
            }
            var directCommand = IMDirectCommand()
            directCommand.cid = self.ID
            switch message.content {
            case .data(let data):
                directCommand.binaryMsg = data
            case .string(let string):
                directCommand.msg = string
            }
            if let value: Bool = message.isAllMembersMentioned {
                directCommand.mentionAll = value
            }
            if let value: [String] = message.mentionedMembers {
                directCommand.mentionPids = value
            }
            if options.contains(.isTransient) {
                directCommand.transient = true
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
            outCommand.directMessage = directCommand
            return outCommand
        }, completion: { (result) in
            switch result {
            case .inCommand(_):
                assert(self.specificAssertion)
            case .error(let error):
                self.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        })
    }

}

extension LCConversation {

    @discardableResult
    func safeUpdatingRawData(merging json: [String: Any]?) -> RawData? {
        guard let json: [String: Any] = json, !json.isEmpty else {
            return nil
        }
        let rawData: [String: Any]
        self.mutex.lock()
        self.rawData = self.rawData.merging(json) { (_, new) in new }
        rawData = self.rawData
        self.mutex.unlock()
        return rawData
    }
    
}

private extension LCConversation {
    
    func safeDecodingRawData<T>(with key: Key) -> T? {
        return self.safeDecodingRawData(with: key.rawValue)
    }
    
    func safeDecodingRawData<T>(with string: String) -> T? {
        var value: T? = nil
        self.mutex.lock()
        value = self.rawData[string] as? T
        self.mutex.unlock()
        return value
    }
    
    func lastMessageDecoding() {
        
    }
    
}

/// IM Chat Room
public final class LCChatRoom: LCConversation {
    
    public enum MessagePriority: Int {
        case high = 1
        case normal = 2
        case low = 3
    }
    
}

/// IM Service Conversation
public final class LCServiceConversation: LCConversation {}

/// IM Temporary Conversation
public final class LCTemporaryConversation: LCConversation {
    
    public final var timeToLive: Int? {
        return safeDecodingRawData(with: .temporaryTTL)
    }
    
}
