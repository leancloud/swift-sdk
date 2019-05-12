//
//  IMClient.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/11/13.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import IOKit
#endif
import FMDB

/// IM Client
public class IMClient {
    
    #if DEBUG
    static let TestReportDeviceTokenNotification = Notification.Name("\(IMClient.self).TestReportDeviceTokenNotification")
    static let TestSessionTokenExpiredNotification = Notification.Name("\(IMClient.self).TestSessionTokenExpiredNotification")
    static let TestSaveLocalRecordNotification = Notification.Name("\(IMClient.self).TestSaveLocalRecordNotification")
    let specificKey = DispatchSpecificKey<Int>()
    let specificValue: Int = Int.random(in: 1...999)
    var specificAssertion: Bool {
        return self.specificValue == DispatchQueue.getSpecific(key: self.specificKey)
    }
    #else
    var specificAssertion: Bool {
        return true
    }
    #endif
    
    /// Length range of the client ID.
    public static let lengthRangeOfClientID = 1...64
    
    /// Reserved value of the tag.
    public static let reservedValueOfTag: String = "default"
    
    /// The client identifier.
    public let ID: String
    
    /// The client tag.
    public let tag: String?
    
    /// The client options.
    public let options: Options
    
    /// The application that the client belongs to.
    public let application: LCApplication
    
    let installation: LCInstallation
    
    let connection: RTMConnection
    
    let rtmDelegator: RTMConnection.Delegator
    
    private(set) var localStorage: IMLocalStorage?
    
    /// The client delegate.
    public weak var delegate: IMClientDelegate?
    
    /// The dispatch queue where the event about IM are called. Default is main.
    public let eventQueue: DispatchQueue
    
    /// The session state of the client.
    ///
    /// - opened: opened.
    /// - resuming: resuming.
    /// - paused: paused.
    /// - closing: closing.
    /// - closed: closed.
    public enum SessionState {
        case opened
        case resuming
        case paused
        case closing
        case closed
    }
    
    /// The current session state of the client.
    public private(set) var sessionState: SessionState {
        set {
            sync(self.underlyingSessionState = newValue)
        }
        get {
            var value: SessionState = .closed
            sync(value = self.underlyingSessionState)
            return value
        }
    }
    private(set) var underlyingSessionState: SessionState = .closed
    var isSessionOpened: Bool {
        return self.sessionState == .opened
    }
    
    /// Options that can modify behaviors of client.
    public struct Options: OptionSet {
        
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Default option is `receiveUnreadMessageCountAfterSessionDidOpen`.
        public static let `default`: Options = [
            .receiveUnreadMessageCountAfterSessionDidOpen,
            .usingLocalStorage
        ]
        
        /// Receive unread message count after session did open.
        public static let receiveUnreadMessageCountAfterSessionDidOpen = Options(rawValue: 1 << 0)
        
        /// Use local storage.
        public static let usingLocalStorage = Options(rawValue: 1 << 1)
        
        var lcimProtocol: RTMConnection.LCIMProtocol {
            if contains(.receiveUnreadMessageCountAfterSessionDidOpen) {
                return .protobuf3
            } else {
                return .protobuf1
            }
        }
        
        var isProtobuf3: Bool {
            return self.lcimProtocol == .protobuf3
        }
    }
    
    /// ref: `https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md`
    struct SessionConfigs: OptionSet {
        let rawValue: Int64
        
        static let patchMessage = SessionConfigs(rawValue: 1 << 0)
        static let temporaryConversationMessage = SessionConfigs(rawValue: 1 << 1)
        static let autoBindDeviceidAndInstallation = SessionConfigs(rawValue: 1 << 2)
        static let transientMessageACK = SessionConfigs(rawValue: 1 << 3)
        static let notification = SessionConfigs(rawValue: 1 << 4)
        static let partialFailedMessage = SessionConfigs(rawValue: 1 << 5)
        static let groupChatRCP = SessionConfigs(rawValue: 1 << 6)
        
        static let support: SessionConfigs = [
            .patchMessage,
            .temporaryConversationMessage,
            .transientMessageACK,
            .notification,
            .partialFailedMessage
        ]
    }
    
    /// Initialization.
    ///
    /// - Parameters:
    ///   - ID: The client identifier. Length should in range `lengthRangeOfClientID`.
    ///   - tag: The client tag. `reservedValueOfTag` should not be used.
    ///   - options: @see `IMClient.Options`.
    ///   - delegate: @see `IMClientDelegate`.
    ///   - eventQueue: @see property `eventQueue`, default is main.
    ///   - application: The application that the client belongs to.
    public init(
        application: LCApplication = LCApplication.default,
        ID: String,
        tag: String? = nil,
        options: Options = .default,
        delegate: IMClientDelegate? = nil,
        eventQueue: DispatchQueue = .main)
        throws
    {
        guard IMClient.lengthRangeOfClientID.contains(ID.count) else {
            throw LCError.clientIDInvalid
        }
        guard tag != IMClient.reservedValueOfTag else {
            throw LCError.clientTagInvalid
        }
        
        #if DEBUG
        self.serialQueue.setSpecific(key: self.specificKey, value: self.specificValue)
        #endif
        
        self.ID = ID
        self.tag = tag
        self.options = options
        self.delegate = delegate
        self.eventQueue = eventQueue
        self.application = application
        self.installation = application.currentInstallation
        
        if let localStorageContext = application.localStorageContext {
            let localRecordURL = try localStorageContext.fileURL(
                place: .persistentData,
                module: .IM(clientID: ID),
                file: .clientRecord
            )
            self.localRecordURL = localRecordURL
            if let localRecord: IMClient.LocalRecord = try application.localStorageContext?.table(from: localRecordURL) {
                self.underlyingLocalRecord = localRecord
            }
            
            if options.contains(.usingLocalStorage) {
                let databaseURL = try localStorageContext.fileURL(
                    place: .persistentData,
                    module: .IM(clientID: ID),
                    file: .database
                )
                self.localStorage = IMLocalStorage(url: databaseURL)
                Logger.shared.verbose("\(IMClient.self)<ID: \"\(ID)\"> initialize database<URL: \"\(databaseURL)\"> success.")
            }
        }
        
        // directly init `connection` is better, lazy init is not a good choice.
        // because connection should get App State in main thread.
        self.connection = try RTMConnectionRegistering(
            application: application,
            peerID: ID,
            lcimProtocol: options.lcimProtocol
        )
        self.rtmDelegator = RTMConnection.Delegator(queue: self.serialQueue)
        
        self.deviceTokenObservation = self.installation.observe(
            \.deviceToken,
            options: [.old, .new, .initial]
        ) { [weak self] (_, change) in
            let oldToken: String? = change.oldValue??.value
            let newToken: String? = change.newValue??.value
            guard let token: String = newToken, oldToken != newToken else {
                return
            }
            self?.serialQueue.async {
                guard let self = self, self.currentDeviceToken != token else {
                    return
                }
                self.currentDeviceToken = token
                self.report(deviceToken: token)
            }
        }
        
        self.localStorage?.client = self
    }
    
    deinit {
        Logger.shared.verbose("\(IMClient.self) with Peer ID <\"\(self.ID)\"> deinit.")
        self.connection.removeDelegator(peerID: self.ID)
        RTMConnectionReleasing(
            application: self.application,
            peerID: self.ID,
            lcimProtocol: self.options.lcimProtocol
        )
    }
    
    let serialQueue = DispatchQueue(label: "LeanCloud.IMClient.serialQueue")
    
    let lock = NSLock()
    
    private(set) var localRecordURL: URL?
    private(set) var localRecord: IMClient.LocalRecord {
        set {
            self.underlyingLocalRecord = newValue
            self.saveLocalRecord()
        }
        get {
            return self.underlyingLocalRecord
        }
    }
    private(set) var underlyingLocalRecord = IMClient.LocalRecord(
        lastPatchTimestamp: nil,
        lastServerTimestamp: nil
    )
    
    private(set) var sessionToken: String?
    private(set) var sessionTokenExpiration: Date?
    private(set) var openingCompletion: ((LCBooleanResult) -> Void)?
    private(set) var openingOptions: SessionOpenOptions?
    
    #if DEBUG
    func test_change(sessionToken token: String?, sessionTokenExpiration date: Date?) {
        self.sessionToken = token
        self.sessionTokenExpiration = date
    }
    func test_change(serverTimestamp timestamp: Int64?) {
        self.serialQueue.async {
            self.localRecord.lastServerTimestamp = timestamp
        }
    }
    #endif
    
    private(set) var deviceTokenObservation: NSKeyValueObservation?
    private(set) var currentDeviceToken: String?
    private(set) lazy var fallbackUDID: String = {
        var udid: String = UUID().uuidString
        #if os(iOS) || os(tvOS)
        if let identifierForVendor: String = UIDevice.current.identifierForVendor?.uuidString {
            udid = identifierForVendor
        }
        #elseif os(macOS)
        let platformExpert: io_service_t = IOServiceGetMatchingService(
            kIOMasterPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        if let serialNumber: String = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformSerialNumberKey as CFString,
            kCFAllocatorDefault,
            0).takeUnretainedValue() as? String
        {
            udid = serialNumber
        }
        IOObjectRelease(platformExpert)
        #endif
        return udid
    }()
    
    var convCollection: [String: IMConversation] = [:]
    private(set) var cachedConvMapSnapshot: [String: IMConversation]?
    private(set) var convQueryCallbackCollection: [String: Array<(IMClient, LCGenericResult<IMConversation>) -> Void>] = [:]
    
    /// ref: `https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md#sessionopen`
    private(set) var lastUnreadNotifTime: Int64?
}

extension IMClient: InternalSynchronizing {
    
    var mutex: NSLock {
        return self.lock
    }
    
}

extension IMClient {
    
    struct LocalRecord: Codable {
        var lastPatchTimestamp: Int64?
        var lastServerTimestamp: Int64?
        
        enum CodingKeys: String, CodingKey {
            case lastPatchTimestamp = "last_patch_timestamp"
            case lastServerTimestamp = "last_server_timestamp"
        }
        
        mutating func update(lastPatchTimestamp newValue: Int64?) {
            guard let newValue = newValue else {
                return
            }
            if let oldValue = self.lastPatchTimestamp {
                if newValue >= oldValue {
                    self.lastPatchTimestamp = newValue
                }
            } else {
                self.lastPatchTimestamp = newValue
            }
        }
        
        @discardableResult
        mutating func update(lastServerTimestamp newValue: Int64?) -> Bool {
            guard let newValue = newValue else {
                return false
            }
            if let oldValue = self.lastServerTimestamp {
                if newValue >= oldValue {
                    self.lastServerTimestamp = newValue
                    return true
                } else {
                    return false
                }
            } else {
                self.lastServerTimestamp = newValue
                return true
            }
        }
    }
    
    func saveLocalRecord() {
        assert(self.specificAssertion)
        guard
            let url = self.localRecordURL,
            let localStorageContext = self.application.localStorageContext
            else
        {
            return
        }
        var userInfo: [String: Any] = [:]
        do {
            try localStorageContext.save(table: self.localRecord, to: url)
        } catch {
            userInfo["error"] = error
            Logger.shared.error(error)
        }
        #if DEBUG
        NotificationCenter.default.post(
            name: IMClient.TestSaveLocalRecordNotification,
            object: self,
            userInfo: userInfo
        )
        #else
        _ = userInfo
        #endif
    }
    
}

// MARK: Open & Close

extension IMClient {
    
    /// Options that can modify behaviors of session open operation.
    public struct SessionOpenOptions: OptionSet {
        
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Default options is `forced`.
        public static let `default`: SessionOpenOptions = [.forced]
        
        /// For two sessions of the same client (Application, ID and Tag are same), the later one will force to make the previous one offline. After later one opened success, the previous one will get session closed error (code: 4111).
        public static let forced = SessionOpenOptions(rawValue: 1 << 0)
        
        /// ref: `https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md#sessionopen`
        var r: Bool { return !contains(.forced) }
    }
    
    /// Open IM session.
    ///
    /// - Parameters:
    ///   - options: @see `IMClient.SessionOpenOptions`.
    ///   - completion: callback.
    public func open(options: SessionOpenOptions = .default, completion: @escaping (LCBooleanResult) -> Void) {
        self.serialQueue.async {
            guard self.openingCompletion == nil && self.sessionToken == nil else {
                var reason: String = "cannot do repetitive operation."
                if let _ = self.openingCompletion {
                    reason = "In opening, \(reason)"
                } else {
                    reason = "Session did opened, \(reason)"
                }
                self.eventQueue.async {
                    let error = LCError(code: .inconsistency, reason: reason)
                    completion(.failure(error: error))
                }
                return
            }
            
            self.openingCompletion = completion
            self.openingOptions = options
            
            self.rtmDelegator.delegate = self
            self.connection.connect(peerID: self.ID, delegator: self.rtmDelegator)
        }
    }
    
    /// Close IM session.
    ///
    /// - Parameter completion: callback.
    public func close(completion: @escaping (LCBooleanResult) -> Void) {
        self.serialQueue.async {
            guard self.isSessionOpened else {
                let error: LCError
                if self.sessionState == .closing {
                    error = LCError(
                        code: .inconsistency,
                        reason: "In closing, cannot do repetitive operation."
                    )
                } else {
                    error = LCError(code: .clientNotOpen)
                }
                self.eventQueue.async {
                    completion(.failure(error: error))
                }
                return
            }
            self.sessionState = .closing
            var outCommand = IMGenericCommand()
            outCommand.cmd = .session
            outCommand.op = .close
            outCommand.sessionMessage = IMSessionCommand()
            self.connection.send(command: outCommand, callingQueue: self.serialQueue) { [weak self] (result) in
                guard let client: IMClient = self else { return }
                assert(client.specificAssertion)
                switch result {
                case .inCommand(let inCommand):
                    if inCommand.cmd == .session, inCommand.op == .closed {
                        client.sessionClosed(with: .success, completion: completion)
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
            }
        }
    }
    
}

// MARK: Create Conversation

extension IMClient {
    
    /// Create a Normal Conversation. Default is a Unique Conversation.
    ///
    /// - Parameters:
    ///   - clientIDs: The set of client ID. it's the members of the conversation which will be created. the initialized members always contains current client's ID. if the created conversation is unique, and server has one unique conversation with the same members, that unique conversation will be returned.
    ///   - name: The name of the conversation.
    ///   - attributes: The attributes of the conversation.
    ///   - isUnique: True means create or get a unique conversation, default is true.
    ///   - completion: callback.
    public func createConversation(
        clientIDs: Set<String>,
        name: String? = nil,
        attributes: [String: Any]? = nil,
        isUnique: Bool = true,
        completion: @escaping (LCGenericResult<IMConversation>) -> Void)
        throws
    {
        try self.createConversation(
            clientIDs: clientIDs,
            name: name,
            attributes: attributes,
            option: (isUnique ? .normalAndUnique : .normal),
            completion: completion
        )
    }
    
    /// Create a Chat Room.
    ///
    /// - Parameters:
    ///   - name: The name of the chat room.
    ///   - attributes: The attributes of the chat room.
    ///   - completion: callback.
    public func createChatRoom(
        name: String? = nil,
        attributes: [String: Any]? = nil,
        completion: @escaping (LCGenericResult<IMChatRoom>) -> Void)
        throws
    {
        try self.createConversation(
            clientIDs: [],
            name: name,
            attributes: attributes,
            option: .transient,
            completion: completion
        )
    }
    
    /// Create a Temporary Conversation. Temporary Conversation is unique in it's Life Cycle.
    ///
    /// - Parameters:
    ///   - clientIDs: The set of client ID. it's the members of the conversation which will be created. the initialized members always contains this client's ID.
    ///   - timeToLive: The time interval for the life of the temporary conversation.
    ///   - completion: callback.
    public func createTemporaryConversation(
        clientIDs: Set<String>,
        timeToLive: Int32,
        completion: @escaping (LCGenericResult<IMTemporaryConversation>) -> Void)
        throws
    {
        try self.createConversation(
            clientIDs: clientIDs,
            option: .temporary(ttl: timeToLive),
            completion: completion
        )
    }
    
    enum ConversationCreationOption {
        case normal
        case normalAndUnique
        case transient
        case temporary(ttl: Int32)
        
        var isUnique: Bool {
            switch self {
            case .normalAndUnique: return true
            default: return false
            }
        }
        
        var isTransient: Bool {
            switch self {
            case .transient: return true
            default: return false
            }
        }
    }
    
    func createConversation<T: IMConversation>(
        clientIDs: Set<String>,
        name: String? = nil,
        attributes: [String: Any]? = nil,
        option: ConversationCreationOption,
        completion: @escaping (LCGenericResult<T>) -> Void)
        throws
    {
        let tuple = try self.preprocessConversationCreation(
            clientIDs: clientIDs,
            name: name,
            attributes: attributes,
            option: option
        )
        let members: [String] = tuple.members
        let attrJSON: [String: Any] = tuple.attrJSON
        let attrString: String? = tuple.attrString
        
        var type: IMConversation.ConvType = .normal
        
        self.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .start
            var convMessage = IMConvCommand()
            if !option.isTransient {
                convMessage.m = members
            }
            switch option {
            case .normal:
                break
            case .normalAndUnique:
                convMessage.unique = true
            case .transient:
                convMessage.transient = true
                type = .transient
            case .temporary(ttl: let ttl):
                convMessage.tempConv = true
                if ttl > 0 { convMessage.tempConvTtl = ttl }
                type = .temporary
            }
            if let dataString: String = attrString {
                var attrMessage = IMJsonObjectMessage()
                attrMessage.data = dataString
                convMessage.attr = attrMessage
            }
            outCommand.convMessage = convMessage
            return outCommand
        }) { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                guard
                    inCommand.cmd == .conv,
                    inCommand.op == .started,
                    inCommand.hasConvMessage,
                    inCommand.convMessage.hasCid
                    else
                {
                    client.eventQueue.async {
                        let error = LCError(code: .commandInvalid)
                        completion(.failure(error: error))
                    }
                    return
                }
                do {
                    let conversation: T = try client.conversationInstance(
                        convMessage: inCommand.convMessage,
                        members: members,
                        attrJSON: attrJSON,
                        attrString: attrString,
                        option: option,
                        convType: type
                    )
                    client.eventQueue.async {
                        completion(.success(value: conversation))
                    }
                } catch {
                    client.eventQueue.async {
                        let err = LCError(error: error)
                        completion(.failure(error: err))
                    }
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        }
    }
    
    func preprocessConversationCreation(
        clientIDs: Set<String>,
        name: String?,
        attributes: [String: Any]?,
        option: ConversationCreationOption)
        throws -> (members: [String], attrJSON: [String: Any], attrString: String?)
    {
        var members: [String]
        if option.isTransient {
            members = []
        } else {
            members = Array<String>(clientIDs)
            for item in clientIDs {
                guard IMClient.lengthRangeOfClientID.contains(item.count) else {
                    throw LCError.clientIDInvalid
                }
            }
            if !clientIDs.contains(self.ID) {
                members.append(self.ID)
            }
        }
        
        var attrJSON: [String: Any] = [:]
        if let name: String = name {
            attrJSON[IMConversation.Key.name.rawValue] = name
        }
        if let attributes: [String: Any] = attributes {
            attrJSON[IMConversation.Key.attributes.rawValue] = attributes
        }
        var attrString: String? = nil
        if !attrJSON.isEmpty {
            let data = try JSONSerialization.data(withJSONObject: attrJSON, options: [])
            attrString = String(data: data, encoding: .utf8)
        }
        
        return (members, attrJSON, attrString)
    }
    
    func conversationInstance<T: IMConversation>(
        convMessage: IMConvCommand,
        members: [String],
        attrJSON: [String: Any],
        attrString: String?,
        option: ConversationCreationOption,
        convType: IMConversation.ConvType)
        throws -> T
    {
        assert(self.specificAssertion)
        let id: String = convMessage.cid
        let conversation: IMConversation
        if let conv: IMConversation = self.convCollection[id] {
            if let json: [String: Any] = try attrString?.jsonObject() {
                conv.safeChangingRawData(operation: .rawDataMerging(data: json), client: self)
            }
            conversation = conv
        } else {
            var json: [String: Any] = attrJSON
            json[IMConversation.Key.convType.rawValue] = convType.rawValue
            json[IMConversation.Key.creator.rawValue] = self.ID
            if !option.isTransient {
                json[IMConversation.Key.members.rawValue] = members
            }
            if option.isUnique {
                json[IMConversation.Key.unique.rawValue] = true
            }
            if convMessage.hasCdate {
                json[IMConversation.Key.createdAt.rawValue] = convMessage.cdate
                if !option.isUnique {
                    json[IMConversation.Key.updatedAt.rawValue] = convMessage.cdate
                }
            }
            if convMessage.hasUniqueID {
                json[IMConversation.Key.uniqueId.rawValue] = convMessage.uniqueID
            }
            if convMessage.hasTempConvTtl {
                json[IMConversation.Key.temporaryTTL.rawValue] = convMessage.tempConvTtl
            }
            if let rawData: IMConversation.RawData = try json.jsonObject() {
                conversation = IMConversation.instance(ID: id, rawData: rawData, client: self, caching: true)
                self.convCollection[id] = conversation
            } else {
                throw LCError(code: .malformedData)
            }
        }
        if let conversation = conversation as? T {
            return conversation
        } else {
            throw LCError(
                code: .invalidType,
                reason: "conversation<T: \(type(of: conversation))> can't cast to type: \(T.self)."
            )
        }
    }
    
}

// MARK: Conversation Query

extension IMClient {
    
    /// Create a new conversation query.
    public var conversationQuery: IMConversationQuery {
        return IMConversationQuery(client: self, eventQueue: self.eventQueue)
    }
    
}

// MARK: Conversation Memory Cache

extension IMClient {
    
    /// Get conversation instance from memory cache.
    ///
    /// - Parameters:
    ///   - ID: The ID of the conversation.
    ///   - completion: callback.
    public func getCachedConversation(ID: String, completion: @escaping (LCGenericResult<IMConversation>) -> Void) {
        self.serialQueue.async {
            if let conv = self.convCollection[ID] {
                self.eventQueue.async {
                    completion(.success(value: conv))
                }
            } else {
                let error = LCError(code: .conversationNotFound)
                self.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        }
    }
    
    /// Remove conversation instance from memory cache.
    ///
    /// - Parameters:
    ///   - IDs: The set of the conversation ID.
    ///   - all: If this parameter set to `true`, then will remove all conversation instance from memory cache.
    ///   - completion: callback.
    public func removeCachedConversation(
        IDs: Set<String>? = nil,
        all: Bool? = nil,
        completion: @escaping (LCBooleanResult) -> Void)
    {
        self.serialQueue.async {
            if let all = all, all {
                self.convCollection.removeAll()
            } else if let IDs = IDs {
                for key in IDs {
                    self.convCollection.removeValue(forKey: key)
                }
            }
            self.eventQueue.async {
                completion(.success)
            }
        }
    }
    
}

// MARK: Session Query

extension IMClient {
    
    /// Query online state of clients, the ID in the result set means online.
    ///
    /// - Parameters:
    ///   - clientIDs: The set of ID to be queried, count of IDs should in range 1...20.
    ///   - completion: callback.
    public func queryOnlineClients(clientIDs: Set<String>, completion: @escaping (LCGenericResult<Set<String>>) -> Void) throws {
        guard !clientIDs.isEmpty, clientIDs.count <= 20 else {
            throw LCError(code: .inconsistency, reason: "parameter `clientIDs`'s count should in range 1...20")
        }
        self.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .session
            outCommand.op = .query
            var sessionCommand = IMSessionCommand()
            sessionCommand.sessionPeerIds = Array(clientIDs)
            outCommand.sessionMessage = sessionCommand
            return outCommand
        }) { (client, result) in
            switch result {
            case .inCommand(let inCommand):
                assert(client.specificAssertion)
                client.eventQueue.async {
                    if inCommand.hasSessionMessage {
                        let value = Set(inCommand.sessionMessage.onlineSessionPeerIds)
                        completion(.success(value: value))
                    } else {
                        completion(.failure(error: LCError(code: .commandInvalid)))
                    }
                }
            case .error(let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        }
    }
    
}

// MARK: Local Storage

extension IMClient {
    
    public func prepareLocalStorage(completion: @escaping (LCBooleanResult) -> Void) throws {
        guard let localStorage = self.localStorage else {
            throw LCError.clientLocalStorageNotFound
        }
        localStorage.open { [weak self] (result) in
            self?.eventQueue.async {
                completion(result)
            }
        }
    }
    
    public enum StoredConversationOrder {
        case updatedTimestamp(descending: Bool)
        case createdTimestamp(descending: Bool)
        case lastMessageSentTimestamp(descending: Bool)
        
        var key: String {
            switch self {
            case .updatedTimestamp:
                return IMLocalStorage.Table.Conversation.CodingKeys.updated_timestamp.rawValue
            case .createdTimestamp:
                return IMLocalStorage.Table.Conversation.CodingKeys.created_timestamp.rawValue
            case .lastMessageSentTimestamp:
                return IMLocalStorage.Table.LastMessage.CodingKeys.sent_timestamp.rawValue
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
    
    public func getAndLoadStoredConversations(
        order: IMClient.StoredConversationOrder = .lastMessageSentTimestamp(descending: true),
        completion: @escaping (LCGenericResult<[IMConversation]>) -> Void)
        throws
    {
        guard let localStorage = self.localStorage else {
            throw LCError.clientLocalStorageNotFound
        }
        localStorage.selectConversations(order: order) { (client, result) in
            assert(client.specificAssertion)
            switch result {
            case .success(value: let tuple):
                client.convCollection.merge(tuple.conversationMap) { (old, new) in old }
                client.eventQueue.async {
                    completion(.success(value: tuple.conversations))
                }
            case .failure(error: let error):
                client.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        }
    }
    
    public func deleteStoredConversationAndMessages(IDs: Set<String>, completion: @escaping (LCBooleanResult) -> Void) throws {
        guard let localStorage = self.localStorage else {
            throw LCError.clientLocalStorageNotFound
        }
        localStorage.deleteConversationAndMessages(IDs: IDs) { [weak self] (result) in
            self?.eventQueue.async {
                completion(result)
            }
        }
    }
    
}

// MARK: Internal

extension IMClient {
    
    static func date(fromMillisecond timestamp: Int64?) -> Date? {
        guard let timestamp = timestamp else {
            return nil
        }
        let second = TimeInterval(timestamp) / 1000.0
        return Date(timeIntervalSince1970: second)
    }
    
    // MARK: Command Sending
    
    func sendCommand(
        constructor: () -> IMGenericCommand,
        completion: ((IMClient, RTMConnection.CommandCallback.Result) -> Void)? = nil)
    {
        var outCommand: IMGenericCommand = constructor()
        outCommand.peerID = self.ID
        guard self.isSessionOpened else {
            let error = LCError(code: .clientNotOpen)
            completion?(self, .error(error))
            return
        }
        if let completion = completion {
            self.connection.send(command: outCommand, callingQueue: self.serialQueue) { [weak self] (result) in
                guard let client: IMClient = self else {
                    return
                }
                completion(client, result)
            }
        } else {
            self.connection.send(command: outCommand)
        }
    }
    
    // MARK: Session Token
    
    func refresh(sessionToken oldToken: String, completion: @escaping (IMClient, LCGenericResult<String>) -> Void) {
        assert(self.specificAssertion)
        self.sendCommand(constructor: { () -> IMGenericCommand in
            return self.newSessionCommand(op: .refresh, token: oldToken)
        }) { (client, result) in
            assert(client.specificAssertion)
            switch result {
            case .inCommand(let inCommand):
                guard
                    let sessionMessage = (inCommand.hasSessionMessage ? inCommand.sessionMessage : nil),
                    let token = (sessionMessage.hasSt ? sessionMessage.st : nil),
                    let ttl = (sessionMessage.hasStTtl ? sessionMessage.stTtl : nil)
                    else
                {
                    let error = LCError(code: .commandInvalid)
                    completion(client, .failure(error: error))
                    return
                }
                client.sessionToken = token
                client.sessionTokenExpiration = Date(timeIntervalSinceNow: TimeInterval(ttl))
                completion(client, .success(value: token))
            case .error(let error):
                completion(client, .failure(error: error))
            }
        }
    }
    
    func getSessionToken(completion: @escaping (IMClient, LCGenericResult<String>) -> Void) {
        assert(self.specificAssertion)
        if let token: String = self.sessionToken {
            if let expiration = self.sessionTokenExpiration,
                expiration > Date() {
                completion(self, .success(value: token))
            } else {
                self.refresh(sessionToken: token, completion: completion)
            }
        } else {
            let error = LCError(code: .clientNotOpen)
            completion(self, .failure(error: error))
        }
    }
    
    // MARK: Offline Notification
    
    func getOfflineEvents(serverTimestamp: Int64?, currentConvCollection: [String: IMConversation]) {
        assert(self.specificAssertion)
        guard let serverTimestamp: Int64 = serverTimestamp else {
            return
        }
        self.cachedConvMapSnapshot = currentConvCollection
        self.getSessionToken { (client, result) in
            assert(client.specificAssertion)
            switch result {
            case .failure(error: let error):
                client.cachedConvMapSnapshot = nil
                Logger.shared.error(error)
            case .success(value: let token):
                let parameters: [String: Any] = [
                    "client_id": client.ID,
                    "start_ts": serverTimestamp
                ]
                let headers: [String: String] = ["X-LC-IM-Session-Token": token]
                let _ = client.application.httpClient.request(
                    .get,
                    "/rtm/notifications",
                    parameters: parameters,
                    headers: headers,
                    completionDispatchQueue: client.serialQueue)
                { [weak client] (response) in
                    guard let sClient: IMClient = client else {
                        return
                    }
                    assert(sClient.specificAssertion)
                    sClient.cachedConvMapSnapshot = nil
                    if let error = response.error {
                        Logger.shared.error(error)
                    } else if let responseValue: [String: Any] = response.value as? [String: Any] {
                        sClient.handleOfflineEvents(
                            response: responseValue,
                            convsSnapshot: Array(currentConvCollection.values)
                        )
                    } else {
                        Logger.shared.error("unknown response value: \(String(describing: response.value))")
                    }
                }
            }
        }
    }
    
    func handleOfflineEvents(response: [String: Any], convsSnapshot: [IMConversation]) {
        assert(self.specificAssertion)
        
        let tuple = self.mapReduceNotifications(response: response, convsSnapshot: convsSnapshot)
        
        let processNotification: (IMClient, String) -> Void = { client, conversationID in
            guard let notificationTuples = tuple.sortedNotificationTuplesMap[conversationID] else {
                return
            }
            for (serverTimestamp, notification) in notificationTuples {
                client.process(
                    notification: notification,
                    conversationID: conversationID,
                    serverTimestamp: serverTimestamp
                )
            }
        }
        
        for conversationID in tuple.existIDs {
            processNotification(self, conversationID)
        }
        
        let queryIDs: Set<String> = tuple.queryIDs
        if !queryIDs.isEmpty {
            self.getConversations(by: queryIDs) { (client, result) in
                switch result {
                case .success:
                    for conversationID in queryIDs {
                        processNotification(client, conversationID)
                    }
                case .failure(error: let error):
                    Logger.shared.error(error)
                }
            }
        }
        
        let queryTempIDs: Set<String> = tuple.queryTempIDs
        if !queryTempIDs.isEmpty {
            self.getTemporaryConversations(by: queryTempIDs) { (client, result) in
                switch result {
                case .success:
                    for conversationID in queryTempIDs {
                        processNotification(client, conversationID)
                    }
                case .failure(error: let error):
                    Logger.shared.error(error)
                }
            }
        }
    }
    
    func mapReduceNotifications(
        response: [String: Any],
        convsSnapshot: [IMConversation])
        ->
        (sortedNotificationTuplesMap: [String: [(Int64, [String: Any])]],
        existIDs: Set<String>,
        queryIDs: Set<String>,
        queryTempIDs: Set<String>)
    {
        assert(self.specificAssertion)
        
        var sortedNotificationTuplesMap: [String: [(Int64, [String: Any])]] = [:]
        var existIDs: Set<String> = []
        var queryIDs: Set<String> = []
        var queryTempIDs: Set<String> = []
        
        let mapReduce: ([[String: Any]]) -> Void = { notifications in
            for notification in notifications {
                guard
                    let cid: String = notification[NotificationKey.cid.rawValue] as? String,
                    let serverTs: Int64 = notification[NotificationKey.serverTs.rawValue] as? Int64
                    else
                {
                    continue
                }
                if let _ = self.convCollection[cid] {
                    existIDs.insert(cid)
                } else {
                    if cid.hasPrefix(IMTemporaryConversation.prefixOfID) {
                        queryTempIDs.insert(cid)
                    } else {
                        queryIDs.insert(cid)
                    }
                }
                if var sortedTuples = sortedNotificationTuplesMap[cid] {
                    if let lastTS = sortedTuples.last?.0, serverTs >= lastTS {
                        sortedTuples.append((serverTs, notification))
                    } else {
                        for (index, item) in sortedTuples.enumerated() {
                            if serverTs <= item.0 {
                                sortedTuples.insert((serverTs, notification), at: index)
                                break
                            }
                        }
                    }
                    sortedNotificationTuplesMap[cid] = sortedTuples
                } else {
                    sortedNotificationTuplesMap[cid] = [(serverTs, notification)]
                }
            }
        }
        
        if
            let permanent = response["permanent"] as? [String: Any],
            let notifications = permanent["notifications"] as? [[String: Any]]
        {
            mapReduce(notifications)
        }
        if let droppable = response["droppable"] as? [String: Any] {
            if let invalidLocalConvCache = droppable["invalidLocalConvCache"] as? Bool, invalidLocalConvCache {
                for conv in convsSnapshot {
                    conv.isOutdated = true
                    conv.tryUpdateLocalStorageData(client: self, outdated: true)
                }
            } else if let notifications = droppable["notifications"] as? [[String: Any]] {
                mapReduce(notifications)
            }
        }
        
        return (sortedNotificationTuplesMap, existIDs, queryIDs, queryTempIDs)
    }
    
    // MARK: Session Command
    
    func newSessionCommand(op: IMOpType, token: String? = nil, isReopen: Bool? = nil) -> IMGenericCommand {
        assert(self.specificAssertion)
        assert(op == .open || op == .refresh)
        var outCommand = IMGenericCommand()
        outCommand.cmd = .session
        outCommand.op = op
        outCommand.appID = self.application.id
        outCommand.peerID = self.ID
        var sessionCommand = IMSessionCommand()
        sessionCommand.configBitmap = SessionConfigs.support.rawValue
        sessionCommand.deviceToken = self.currentDeviceToken ?? self.fallbackUDID
        sessionCommand.ua = self.application.httpClient.configuration.userAgent
        if let tag: String = self.tag {
            sessionCommand.tag = tag
        }
        if let token = token {
            sessionCommand.st = token
        }
        if let r = isReopen {
            sessionCommand.r = r
        }
        if op == .open {
            if let lastUnreadNotifTime: Int64 = self.lastUnreadNotifTime {
                sessionCommand.lastUnreadNotifTime = lastUnreadNotifTime
            }
            if let lastPatchTime: Int64 = self.localRecord.lastPatchTimestamp {
                sessionCommand.lastPatchTime = lastPatchTime
            }
        }
        outCommand.sessionMessage = sessionCommand
        return outCommand
    }
    
    func send(reopenCommand command: IMGenericCommand) {
        assert(self.specificAssertion)
        self.connection.send(command: command, callingQueue: self.serialQueue) { [weak self] (result) in
            guard let client: IMClient = self else { return }
            assert(client.specificAssertion)
            switch result {
            case .inCommand(let inCommand):
                client.handle(openCommandCallback: inCommand)
            case .error(let error):
                if error.code == LCError.InternalErrorCode.commandTimeout.rawValue {
                    client.send(reopenCommand: command)
                } else if error.code == LCError.InternalErrorCode.connectionLost.rawValue {
                    Logger.shared.debug(error)
                } else if error.code == LCError.ServerErrorCode.sessionTokenExpired.rawValue {
                    let openCommand = client.newSessionCommand(op: .open, isReopen: true)
                    client.send(reopenCommand: openCommand)
                    #if DEBUG
                    NotificationCenter.default.post(
                        name: IMClient.TestSessionTokenExpiredNotification,
                        object: client,
                        userInfo: ["error": error]
                    )
                    #endif
                } else {
                    // unknown error, maybe should close session.
                    client.sessionClosed(with: .failure(error: error))
                }
            }
        }
    }
    
    func report(deviceToken token: String?, openCommand: IMGenericCommand? = nil) {
        assert(self.specificAssertion)
        guard let token: String = token else {
            return
        }
        if let openCommand = openCommand {
            // if Device-Token not changed in Opening-Period,
            // then no need to report after open success.
            if openCommand.sessionMessage.deviceToken == token {
                return
            }
        }
        self.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .report
            outCommand.op = .upload
            var reportCommand = IMReportCommand()
            reportCommand.initiative = true
            reportCommand.type = "token"
            reportCommand.data = token
            outCommand.reportMessage = reportCommand
            return outCommand
        }) { (client, result) in
            #if DEBUG
            /// for unit test
            NotificationCenter.default.post(
                name: IMClient.TestReportDeviceTokenNotification,
                object: client,
                userInfo: ["result": result]
            )
            #endif
        }
    }
    
    func handle(openCommandCallback command: IMGenericCommand, completion: ((LCBooleanResult) -> Void)? = nil) {
        assert(self.specificAssertion)
        switch (command.cmd, command.op) {
        case (.session, .opened):
            let sessionMessage = command.sessionMessage
            if sessionMessage.hasSt && sessionMessage.hasStTtl {
                self.sessionToken = sessionMessage.st
                self.sessionTokenExpiration = Date(timeIntervalSinceNow: TimeInterval(sessionMessage.stTtl))
            }
            self.sessionState = .opened
            if let lastServerTimestamp = self.localRecord.lastServerTimestamp {
                self.getOfflineEvents(
                    serverTimestamp: lastServerTimestamp,
                    currentConvCollection: self.convCollection
                )
            }
            if self.localRecord.lastPatchTimestamp == nil {
                self.localRecord.update(
                    lastPatchTimestamp: (command.hasServerTs ? command.serverTs : nil)
                )
            }
            self.eventQueue.async {
                if let completion = completion {
                    completion(.success)
                } else {
                    self.delegate?.client(self, event: .sessionDidOpen)
                }
            }
        case (.session, .closed):
            let sessionMessage = command.sessionMessage
            self.sessionClosed(with: .failure(error: sessionMessage.lcError), completion: completion)
        default:
            let error = LCError(code: .commandInvalid)
            self.sessionClosed(with: .failure(error: error), completion: completion)
        }
    }
    
    func sessionClosed(with result: LCBooleanResult, completion: ((LCBooleanResult) -> Void)? = nil) {
        assert(self.specificAssertion)
        self.rtmDelegator.delegate = nil
        self.connection.removeDelegator(peerID: self.ID)
        self.sessionToken = nil
        self.sessionTokenExpiration = nil
        self.openingCompletion = nil
        self.openingOptions = nil
        self.sessionState = .closed
        self.eventQueue.async {
            if let completion = completion {
                completion(result)
            } else if let error = result.error {
                self.delegate?.client(self, event: .sessionDidClose(error: error))
            }
        }
    }
    
    // MARK: Conversation Query
    
    func getConversation(by ID: String, completion: @escaping (IMClient, LCGenericResult<IMConversation>) -> Void) {
        assert(self.specificAssertion)
        if let existConversation: IMConversation = self.convCollection[ID] {
            completion(self, .success(value: existConversation))
            return
        }
        if var callbacks: Array<(IMClient, LCGenericResult<IMConversation>) -> Void> = self.convQueryCallbackCollection[ID] {
            callbacks.append(completion)
            self.convQueryCallbackCollection[ID] = callbacks
            return
        } else {
            self.convQueryCallbackCollection[ID] = [completion]
        }
        let callback: (IMClient, LCGenericResult<IMConversation>) -> Void = { client, result in
            guard let callbacks = client.convQueryCallbackCollection.removeValue(forKey: ID) else {
                return
            }
            for closure in callbacks {
                closure(client, result)
            }
        }
        let query = IMConversationQuery(client: self)
        do {
            if ID.hasPrefix(IMTemporaryConversation.prefixOfID) {
                try query.getTemporaryConversations(by: [ID], completion: { [weak self] (result) in
                    guard let client: IMClient = self else { return }
                    assert(client.specificAssertion)
                    switch result {
                    case .success(value: let conversations):
                        if let first: IMConversation = conversations.first {
                            callback(client, .success(value: first))
                        } else {
                            callback(client, .failure(error: LCError(code: .conversationNotFound)))
                        }
                    case .failure(error: let error):
                        callback(client, .failure(error: error))
                    }
                })
            } else {
                try query.getConversation(by: ID, completion: { [weak self] (result) in
                    guard let client: IMClient = self else { return }
                    assert(client.specificAssertion)
                    callback(client, result)
                })
            }
        } catch {
            assert(self.specificAssertion)
            callback(self, .failure(error: LCError(error: error)))
        }
    }
    
    func getConversations(by IDs: Set<String>, completion: @escaping (IMClient, LCGenericResult<[IMConversation]>) -> Void) {
        assert(self.specificAssertion)
        if IDs.count == 1, let ID: String = IDs.first {
            self.getConversation(by: ID) { (client, result) in
                assert(client.specificAssertion)
                switch result {
                case .success(value: let conversation):
                    completion(client, .success(value: [conversation]))
                case .failure(error: let error):
                    completion(client, .failure(error: error))
                }
            }
        } else {
            let query = IMConversationQuery(client: self)
            do {
                try query.getConversations(by: IDs, completion: { [weak self] (result) in
                    guard let client: IMClient = self else { return }
                    assert(client.specificAssertion)
                    completion(client, result)
                })
            } catch {
                assert(self.specificAssertion)
                completion(self, .failure(error: LCError(error: error)))
            }
        }
    }
    
    func getTemporaryConversations(by IDs: Set<String>, completion: @escaping (IMClient, LCGenericResult<[IMConversation]>) -> Void) {
        assert(self.specificAssertion)
        if IDs.count == 1, let ID: String = IDs.first {
            self.getConversation(by: ID) { (client, result) in
                assert(client.specificAssertion)
                switch result {
                case .success(value: let conversation):
                    completion(client, .success(value: [conversation]))
                case .failure(error: let error):
                    completion(client, .failure(error: error))
                }
            }
        } else {
            let query = IMConversationQuery(client: self)
            do {
                try query.getTemporaryConversations(by: IDs, completion: { [weak self] (result) in
                    guard let client: IMClient = self else { return }
                    assert(client.specificAssertion)
                    switch result {
                    case .success(value: let conversations):
                        completion(client, .success(value: conversations))
                    case .failure(error: let error):
                        completion(client, .failure(error: error))
                    }
                })
            } catch {
                assert(self.specificAssertion)
                completion(self, .failure(error: LCError(error: error)))
            }
        }
    }
    
    // MARK: Command Processing
    
    func process(convCommand command: IMConvCommand, op: IMOpType, serverTimestamp: Int64?) {
        assert(self.specificAssertion)
        guard let conversationID: String = (command.hasCid ? command.cid : nil) else {
            return
        }
        self.getConversation(by: conversationID) { (client, result) in
            assert(client.specificAssertion)
            switch result {
            case .success(value: let conversation):
                var event: IMConversationEvent? = nil
                var rawDataOperation: IMConversation.RawDataChangeOperation? = nil
                switch op {
                case .joined, .left, .membersJoined, .membersLeft:
                    let byClientID: String? = (command.hasInitBy ? command.initBy : nil)
                    let udate: String? = (command.hasUdate ? command.udate : nil)
                    let atDate: Date? = (command.hasUdate ? LCDate.dateFromString(command.udate) : nil)
                    switch op {
                    case .joined:
                        rawDataOperation = .append(members: [client.ID], udate: udate)
                        event = .joined(byClientID: byClientID, at: atDate)
                    case .left:
                        rawDataOperation = .remove(members: [client.ID], udate: udate)
                        event = .left(byClientID: byClientID, at: atDate)
                    case .membersJoined:
                        rawDataOperation = .append(members: command.m, udate: udate)
                        event = .membersJoined(members: command.m, byClientID: byClientID, at: atDate)
                    case .membersLeft:
                        rawDataOperation = .remove(members: command.m, udate: udate)
                        event = .membersLeft(members: command.m, byClientID: byClientID, at: atDate)
                    default:
                        break
                    }
                case .updated:
                    do {
                        if
                            command.hasAttr,
                            command.attr.hasData,
                            let attr: [String: Any] = try command.attr.data.jsonObject(),
                            command.hasAttrModified,
                            command.attrModified.hasData,
                            let attrModified: [String: Any] = try command.attrModified.data.jsonObject()
                        {
                            rawDataOperation = .updated(
                                attr: attr,
                                attrModified: attrModified,
                                udate: (command.hasUdate ? command.udate : nil)
                            )
                            event = IMConversationEvent.dataUpdated(
                                updatingData: attr,
                                updatedData: attrModified,
                                byClientID: (command.hasInitBy ? command.initBy : nil),
                                at: (command.hasUdate ? LCDate.dateFromString(command.udate) : nil)
                            )
                        } else {
                            Logger.shared.error("invalid command \(command)")
                        }
                    } catch {
                        Logger.shared.error(error)
                    }
                default:
                    break
                }
                if let rawDataOperation = rawDataOperation {
                    conversation.safeChangingRawData(operation: rawDataOperation, client: client)
                    let lastServerTimestampUpdated: Bool = client.localRecord.update(lastServerTimestamp: serverTimestamp)
                    if
                        lastServerTimestampUpdated,
                        let _ = self.cachedConvMapSnapshot?[conversationID]
                    {
                        conversation.isOutdated = true
                        conversation.tryUpdateLocalStorageData(client: client, outdated: true)
                    }
                }
                if let event = event {
                    client.eventQueue.async {
                        client.delegate?.client(client, conversation: conversation, event: event)
                    }
                }
            case .failure(error: let error):
                Logger.shared.error(error)
            }
        }
    }
    
    func acknowledging(message: IMMessage, conversation: IMConversation) {
        assert(self.specificAssertion)
        guard
            message.notTransientMessage,
            conversation.notTransientConversation,
            let conversationID: String = message.conversationID,
            let messageID: String = message.ID
            else
        { return }
        self.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .ack
            var ackMessage = IMAckCommand()
            ackMessage.cid = conversationID
            ackMessage.mid = messageID
            /*
             why not use the `timestamp` ?
             becase server just use ack to handle unread-message-queue(max limit is 100),
             so use `conversationID` and `messageID` can find the message,
             of course there is a very little probability that multiple messages have the same ID in the unread-message-queue,
             but it's nearly ZERO, so just do it, take it easy, it's fine.
             */
            outCommand.ackMessage = ackMessage
            return outCommand
        })
    }
    
    func process(directCommand command: IMDirectCommand) {
        assert(self.specificAssertion)
        guard let conversationID: String = (command.hasCid ? command.cid : nil) else {
            return
        }
        self.getConversation(by: conversationID) { (client, result) in
            assert(client.specificAssertion)
            switch result {
            case .success(value: let conversation):
                guard
                    let timestamp: Int64 = (command.hasTimestamp ? command.timestamp : nil),
                    let messageID: String = (command.hasID ? command.id : nil)
                    else
                { return }
                var content: IMMessage.Content? = nil
                /*
                 For Compatibility,
                 Should check `binaryMsg` at first.
                 Then check `msg`.
                 */
                if command.hasBinaryMsg {
                    content = .data(command.binaryMsg)
                } else if command.hasMsg {
                    content = .string(command.msg)
                }
                let message = IMMessage.instance(
                    application: client.application,
                    isTransient: (command.hasTransient ? command.transient : false),
                    conversationID: conversationID,
                    currentClientID: client.ID,
                    fromClientID: (command.hasFromPeerID ? command.fromPeerID : nil),
                    timestamp: timestamp,
                    patchedTimestamp: (command.hasPatchTimestamp ? command.patchTimestamp : nil),
                    messageID: messageID,
                    content: content,
                    isAllMembersMentioned: (command.hasMentionAll ? command.mentionAll : nil),
                    mentionedMembers: (command.mentionPids.isEmpty ? nil : command.mentionPids)
                )
                var unreadEvent: IMConversationEvent?
                let isUnreadMessageIncreased: Bool = conversation.safeUpdatingLastMessage(newMessage: message, client: client)
                if client.options.isProtobuf3, isUnreadMessageIncreased {
                    conversation.unreadMessageCount += 1
                    unreadEvent = .unreadMessageCountUpdated
                }
                client.acknowledging(message: message, conversation: conversation)
                client.eventQueue.async {
                    if let unreadUpdatedEvent = unreadEvent {
                        client.delegate?.client(client, conversation: conversation, event: unreadUpdatedEvent)
                    }
                    client.delegate?.client(client, conversation: conversation, event: .message(event: .received(message: message)))
                }
            case .failure(error: let error):
                Logger.shared.error(error)
            }
        }
    }
    
    func process(unreadCommand: IMUnreadCommand) {
        assert(self.specificAssertion)
        var conversationIDMap: [String: IMUnreadTuple] = [:]
        var temporaryConversationIDMap: [String: IMUnreadTuple] = [:]
        for unreadTuple in unreadCommand.convs {
            guard let conversationID: String = (unreadTuple.hasCid ? unreadTuple.cid : nil) else {
                continue
            }
            if let existingConversation = self.convCollection[conversationID] {
                existingConversation.process(unreadTuple: unreadTuple, client: self)
            } else {
                if conversationID.hasPrefix(IMTemporaryConversation.prefixOfID) {
                    temporaryConversationIDMap[conversationID] = unreadTuple
                } else {
                    conversationIDMap[conversationID] = unreadTuple
                }
            }
        }
        let updateLastUnreadNotifTime: (IMClient) -> Void = { client in
            if client.options.isProtobuf3, unreadCommand.hasNotifTime {
                if let oldTime: Int64 = client.lastUnreadNotifTime {
                    if unreadCommand.notifTime > oldTime {
                        client.lastUnreadNotifTime = unreadCommand.notifTime
                    }
                } else {
                    client.lastUnreadNotifTime = unreadCommand.notifTime
                }
            }
        }
        if conversationIDMap.isEmpty, temporaryConversationIDMap.isEmpty {
            updateLastUnreadNotifTime(self)
        } else {
            let group = DispatchGroup()
            var groupFlags: [Bool] = []
            let handleResult: (IMClient, LCGenericResult<[IMConversation]>, [String: IMUnreadTuple]) -> Void = { (client, result, map) in
                switch result {
                case .success(value: let conversations):
                    groupFlags.append(true)
                    for conversation in conversations {
                        if let unreadTuple: IMUnreadTuple = map[conversation.ID] {
                            conversation.process(unreadTuple: unreadTuple, client: client)
                        }
                    }
                case .failure(error: let error):
                    if error.code == LCError.InternalErrorCode.conversationNotFound.rawValue {
                        groupFlags.append(true)
                    } else {
                        groupFlags.append(false)
                    }
                    Logger.shared.error(error)
                }
            }
            if !conversationIDMap.isEmpty {
                group.enter()
                self.getConversations(by: Set(conversationIDMap.keys)) { (client, result) in
                    assert(client.specificAssertion)
                    handleResult(client, result, conversationIDMap)
                    group.leave()
                }
            }
            if !temporaryConversationIDMap.isEmpty {
                group.enter()
                self.getTemporaryConversations(by: Set(temporaryConversationIDMap.keys)) { (client, result) in
                    assert(client.specificAssertion)
                    handleResult(client, result, temporaryConversationIDMap)
                    group.leave()
                }
            }
            group.notify(queue: self.serialQueue) { [weak self] in
                guard let client = self, !groupFlags.contains(false) else {
                    return
                }
                updateLastUnreadNotifTime(client)
            }
        }
    }
    
    func process(patchCommand: IMPatchCommand) {
        assert(self.specificAssertion)
        var lastPatchTimestamp: Int64 = -1
        var conversationIDMap: [String: [IMPatchItem]] = [:]
        var temporaryConversationIDMap: [String: [IMPatchItem]] = [:]
        for item in patchCommand.patches {
            guard let conversationID: String = (item.hasCid ? item.cid : nil) else {
                continue
            }
            if item.hasPatchTimestamp,
                item.patchTimestamp > lastPatchTimestamp {
                lastPatchTimestamp = item.patchTimestamp
            }
            if let existingConversation = self.convCollection[conversationID] {
                existingConversation.process(patchItem: item, client: self)
            } else {
                if conversationID.hasPrefix(IMTemporaryConversation.prefixOfID) {
                    if var items = temporaryConversationIDMap[conversationID] {
                        items.append(item)
                        temporaryConversationIDMap[conversationID] = items
                    } else {
                        temporaryConversationIDMap[conversationID] = [item]
                    }
                } else {
                    if var items = conversationIDMap[conversationID] {
                        items.append(item)
                        conversationIDMap[conversationID] = items
                    } else {
                        conversationIDMap[conversationID] = [item]
                    }
                }
            }
        }
        let updateLastPatchTime: (IMClient) -> Void = { client in
            if client.options.isProtobuf3, lastPatchTimestamp > 0 {
                client.localRecord.update(lastPatchTimestamp: lastPatchTimestamp)
            }
        }
        if conversationIDMap.isEmpty, temporaryConversationIDMap.isEmpty {
            updateLastPatchTime(self)
        } else {
            let group = DispatchGroup()
            var groupFlags: [Bool] = []
            let handleResult: (IMClient, LCGenericResult<[IMConversation]>, [String: [IMPatchItem]]) -> Void = { (client, result, map) in
                switch result {
                case .success(value: let conversations):
                    groupFlags.append(true)
                    for conversation in conversations {
                        if let patchItems: [IMPatchItem] = map[conversation.ID] {
                            for patchItem in patchItems {
                                conversation.process(patchItem: patchItem, client: client)
                            }
                        }
                    }
                case .failure(error: let error):
                    if error.code == LCError.InternalErrorCode.conversationNotFound.rawValue {
                        groupFlags.append(true)
                    } else {
                        groupFlags.append(false)
                    }
                    Logger.shared.error(error)
                }
            }
            if !conversationIDMap.isEmpty {
                group.enter()
                self.getConversations(by: Set(conversationIDMap.keys)) { (client, result) in
                    assert(client.specificAssertion)
                    handleResult(client, result, conversationIDMap)
                    group.leave()
                }
            }
            if !temporaryConversationIDMap.isEmpty {
                group.enter()
                self.getTemporaryConversations(by: Set(temporaryConversationIDMap.keys)) { (client, result) in
                    assert(client.specificAssertion)
                    handleResult(client, result, temporaryConversationIDMap)
                    group.leave()
                }
            }
            group.notify(queue: self.serialQueue) { [weak self] in
                guard let client = self, !groupFlags.contains(false) else {
                    return
                }
                updateLastPatchTime(client)
            }
        }
    }
    
    func process(rcpCommand: IMRcpCommand, serverTimestamp: Int64?) {
        assert(self.specificAssertion)
        guard let conversationID: String = (rcpCommand.hasCid ? rcpCommand.cid : nil) else {
            return
        }
        self.getConversation(by: conversationID) { (client, result) in
            assert(client.specificAssertion)
            switch result {
            case .success(value: let conversation):
                guard
                    let messageID: String = (rcpCommand.hasID ? rcpCommand.id : nil),
                    let timestamp: Int64 = (rcpCommand.hasT ? rcpCommand.t : nil)
                    else
                { return }
                let fromID = (rcpCommand.hasFrom ? rcpCommand.from : nil)
                let event: IMMessageEvent
                if rcpCommand.hasRead, rcpCommand.read {
                    event = .read(
                        byClientID: fromID,
                        messageID: messageID,
                        readTimestamp: timestamp
                    )
                } else {
                    event = .delivered(
                        toClientID: fromID,
                        messageID: messageID,
                        deliveredTimestamp: timestamp
                    )
                }
                client.localRecord.update(lastServerTimestamp: serverTimestamp)
                client.eventQueue.async {
                    client.delegate?.client(client, conversation: conversation, event: .message(event: event))
                }
            case .failure(error: let error):
                Logger.shared.error(error)
            }
        }
    }
    
    enum NotificationKey: String {
        // general
        case cmd = "cmd"
        case op = "op"
        case cid = "cid"
        case serverTs = "serverTs"
        // conv
        case initBy = "initBy"
        case m = "m"
        case attr = "attr"
        case attrModified = "attrModified"
        case udate = "udate"
        // rcp
        case id = "id"
        case t = "t"
        case read = "read"
        case from = "from"
    }
    
    enum NotificationCommand: String {
        case conv = "conv"
        case rcp = "rcp"
    }
    
    enum NotificationOperation: String {
        case joined = "joined"
        case left = "left"
        case membersJoined = "members-joined"
        case membersLeft = "members-left"
        case updated = "updated"
        
        var opType: IMOpType {
            switch self {
            case .joined:
                return .joined
            case .left:
                return .left
            case .membersJoined:
                return .membersJoined
            case .membersLeft:
                return .membersLeft
            case .updated:
                return .updated
            }
        }
    }
    
    // for compatibility, should regard some unknown condition or unsupport message as success and callback with timestamp -1.
    func process(notification: [String: Any], conversationID: String, serverTimestamp: Int64) {
        assert(self.specificAssertion)
        guard
            let cmdValue = notification[NotificationKey.cmd.rawValue] as? String,
            let cmd = NotificationCommand(rawValue: cmdValue)
            else
        {
            return
        }
        switch cmd {
        case .conv:
            guard
                let opValue = notification[NotificationKey.op.rawValue] as? String,
                let op = NotificationOperation(rawValue: opValue)
                else
            {
                return
            }
            var convCommand = IMConvCommand()
            convCommand.cid = conversationID
            if let udate = notification[NotificationKey.udate.rawValue] as? String {
                convCommand.udate = udate
            }
            if let initBy = notification[NotificationKey.initBy.rawValue] as? String {
                convCommand.initBy = initBy
            }
            switch op {
            case .joined, .left, .membersJoined, .membersLeft:
                if let m = notification[NotificationKey.m.rawValue] as? [String] {
                    convCommand.m = m
                }
            case .updated:
                do {
                    if
                        let attr = notification[NotificationKey.attr.rawValue] as? [String: Any],
                        let data = try attr.jsonString()
                    {
                        var jsonObject = IMJsonObjectMessage()
                        jsonObject.data = data
                        convCommand.attr = jsonObject
                    }
                } catch {
                    Logger.shared.error(error)
                }
                do {
                    if
                        let attrModified = notification[NotificationKey.attrModified.rawValue] as? [String: Any],
                        let data = try attrModified.jsonString()
                    {
                        var jsonObject = IMJsonObjectMessage()
                        jsonObject.data = data
                        convCommand.attrModified = jsonObject
                    }
                } catch {
                    Logger.shared.error(error)
                }
            }
            self.process(convCommand: convCommand, op: op.opType, serverTimestamp: serverTimestamp)
        case .rcp:
            var rcpCommand = IMRcpCommand()
            rcpCommand.cid = conversationID
            if let mid = notification[NotificationKey.id.rawValue] as? String {
                rcpCommand.id = mid
            }
            if let timestamp = notification[NotificationKey.t.rawValue] as? Int64 {
                rcpCommand.t = timestamp
            }
            if let isRead = notification[NotificationKey.read.rawValue] as? Bool {
                rcpCommand.read = isRead
            }
            if let fromPeerID = notification[NotificationKey.from.rawValue] as? String {
                rcpCommand.from = fromPeerID
            }
            self.process(rcpCommand: rcpCommand, serverTimestamp: serverTimestamp)
        }
    }
    
}

// MARK: - Connection Delegate

extension IMClient: RTMConnectionDelegate {
    
    func connection(inConnecting connection: RTMConnection) {
        assert(self.specificAssertion)
        guard let _ = self.sessionToken, self.sessionState != .resuming else {
            return
        }
        self.sessionState = .resuming
        self.eventQueue.async {
            self.delegate?.client(self, event: IMClientEvent.sessionDidResume)
        }
    }
    
    func connection(didConnect connection: RTMConnection) {
        assert(self.specificAssertion)
        if
            let openingCompletion = self.openingCompletion,
            let openingOptions = self.openingOptions
        {
            let openCommand = self.newSessionCommand(op: .open, isReopen: openingOptions.r)
            self.connection.send(command: openCommand, callingQueue: self.serialQueue) { [weak self] (result) in
                guard let self = self else { return }
                assert(self.specificAssertion)
                self.openingCompletion = nil
                self.openingOptions = nil
                switch result {
                case .inCommand(let inCommand):
                    self.handle(openCommandCallback: inCommand, completion: openingCompletion)
                    self.report(deviceToken: self.currentDeviceToken, openCommand: openCommand)
                case .error(let error):
                    self.eventQueue.async {
                        openingCompletion(.failure(error: error))
                    }
                }
            }
        } else if let sessionToken = self.sessionToken {
            let openCommand: IMGenericCommand
            if let expiration = self.sessionTokenExpiration,
                expiration > Date() {
                openCommand = self.newSessionCommand(op: .open, token: sessionToken, isReopen: true)
            } else {
                openCommand = self.newSessionCommand(op: .open, isReopen: true)
            }
            self.send(reopenCommand: openCommand)
        }
    }
    
    func connection(_ connection: RTMConnection, didDisconnect error: LCError) {
        assert(self.specificAssertion)
        
        let routerError = LCError.RTMRouterResponseDataMalformed
        if
            error.code == routerError.code,
            error.reason == routerError.reason
        {
            self.sessionClosed(with: .failure(error: error), completion: self.openingCompletion)
            return
        }
        
        if let openingCompletion = self.openingCompletion {
            self.sessionClosed(with: .failure(error: error), completion: openingCompletion)
        } else if let _ = self.sessionToken, self.sessionState != .paused {
            self.sessionState = .paused
            self.eventQueue.async {
                self.delegate?.client(self, event: .sessionDidPause(error: error))
            }
        }
    }
    
    func connection(_ connection: RTMConnection, didReceiveCommand inCommand: IMGenericCommand) {
        assert(self.specificAssertion)
        let serverTimestamp: Int64? = (inCommand.hasServerTs ? inCommand.serverTs : nil)
        switch inCommand.cmd {
        case .session:
            switch inCommand.op {
            case .closed:
                self.sessionClosed(with: .failure(error: inCommand.sessionMessage.lcError))
            default:
                break
            }
        case .direct:
            self.process(directCommand: inCommand.directMessage)
        case .unread:
            self.process(unreadCommand: inCommand.unreadMessage)
        case .conv:
            self.process(convCommand: inCommand.convMessage, op: inCommand.op, serverTimestamp: serverTimestamp)
        case .patch:
            switch inCommand.op {
            case .modify:
                self.process(patchCommand: inCommand.patchMessage)
            default:
                break
            }
        case .rcp:
            self.process(rcpCommand: inCommand.rcpMessage, serverTimestamp: serverTimestamp)
        default:
            break
        }
    }
    
}

// MARK: - Event

/// The session event about the client.
///
/// - sessionDidOpen: Session opened event.
/// - sessionDidResume: Session in resuming event.
/// - sessionDidPause: Session paused event.
/// - sessionDidClose: Session closed event.
public enum IMClientEvent {
    
    case sessionDidOpen
    
    case sessionDidResume
    
    case sessionDidPause(error: LCError)
    
    case sessionDidClose(error: LCError)
    
}

/// The event about the conversation that belong to the client.
///
/// - joined: The client joined the conversation.
/// - left: The client left the conversation.
/// - membersJoined: The members joined the conversation.
/// - membersLeft: The members left the conversation.
/// - dataUpdated: The data of the conversation updated.
/// - lastMessageUpdated: The last message of the conversation updated.
/// - unreadMessageCountUpdated: The unread message count of the conversation updated.
/// - message: Events about message in the conversation.
public enum IMConversationEvent {
    
    case joined(byClientID: String?, at: Date?)
    
    case left(byClientID: String?, at: Date?)
    
    case membersJoined(members: [String], byClientID: String?, at: Date?)
    
    case membersLeft(members: [String], byClientID: String?, at: Date?)
    
    case dataUpdated(updatingData: [String: Any]?, updatedData: [String: Any]?, byClientID: String?, at: Date?)
    
    case lastMessageUpdated(newMessage: Bool)
    
    case unreadMessageCountUpdated
    
    case message(event: IMMessageEvent)
    
}

/// The event about the message that belong to the conversation.
///
/// - received: The client received message from the conversation.
/// - updated: The message in the conversation has been updated.
/// - delivered: The message sent to the conversation by the client has delivered to other.
/// - read: The message sent to the conversation by the client has been read by other.
public enum IMMessageEvent {
    
    case received(message: IMMessage)
    
    case updated(updatedMessage: IMMessage, reason: IMMessage.PatchedReason?)
    
    case delivered(toClientID: String?, messageID: String, deliveredTimestamp: Int64)
    
    case read(byClientID: String?, messageID: String, readTimestamp: Int64)
    
}

/// IM Client Delegate
public protocol IMClientDelegate: class {
    
    /// Delegate function of the event about the client.
    ///
    /// - Parameters:
    ///   - client: Which the event belong to.
    ///   - event: @see `IMClientEvent`
    func client(_ client: IMClient, event: IMClientEvent)
    
    /// Delegate function of the event about the conversation.
    ///
    /// - Parameters:
    ///   - client: Which the conversation belong to.
    ///   - conversation: Which the event belong to.
    ///   - event: @see `IMConversationEvent`
    func client(_ client: IMClient, conversation: IMConversation, event: IMConversationEvent)
    
}

extension LCError {
    
    static var clientIDInvalid: LCError {
        return LCError(
            code: .inconsistency,
            reason: "Length of client ID should in \(IMClient.lengthRangeOfClientID)"
        )
    }
    
    static var clientTagInvalid: LCError {
        return LCError(
            code: .inconsistency,
            reason: "\"\(IMClient.reservedValueOfTag)\" string should not be used on tag"
        )
    }
    
    static var clientLocalStorageNotFound: LCError {
        return LCError(
            code: .inconsistency,
            reason: "Local Storage not found."
        )
    }
    
}
