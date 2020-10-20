//
//  IMClient.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/11/13.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/// IM Client
public class IMClient {
    
    // MARK: Debug
    
    #if DEBUG
    static let TestReportDeviceTokenNotification = Notification
        .Name("\(IMClient.self).TestReportDeviceTokenNotification")
    static let TestSessionTokenExpiredNotification = Notification
        .Name("\(IMClient.self).TestSessionTokenExpiredNotification")
    static let TestSaveLocalRecordNotification = Notification
        .Name("\(IMClient.self).TestSaveLocalRecordNotification")
    let specificKey = DispatchSpecificKey<Int>()
    let specificValue: Int = Int.random(in: 1...999)
    #endif
    var specificAssertion: Bool {
        #if DEBUG
        return self.specificValue ==
            DispatchQueue.getSpecific(
                key: self.specificKey)
        #else
        return true
        #endif
    }
    
    // MARK: Property
    
    /// Length range of the client ID.
    public static let lengthRangeOfClientID = 1...64
    
    /// Reserved value of the tag.
    public static let reservedValueOfTag: String = "default"
    
    public typealias Identifier = String
    
    /// The client identifier.
    public let ID: IMClient.Identifier
    
    /// The client tag.
    public let tag: String?
    
    /// The user.
    public private(set) var user: LCUser?
    
    /// The client options.
    public let options: Options
    
    /// The application that the client belongs to.
    public let application: LCApplication
    
    let installation: LCInstallation
    
    let connection: RTMConnection
    
    let connectionDelegator: RTMConnection.Delegator
    
    #if canImport(GRDB)
    private(set) var localStorage: IMLocalStorage?
    #endif
    
    /// The client delegate.
    public weak var delegate: IMClientDelegate?
    
    /// The signature delegate.
    public weak var signatureDelegate: IMSignatureDelegate?
    
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
            self.sync(self._sessionState = newValue)
        }
        get {
            self.sync(self._sessionState)
        }
    }
    private(set) var _sessionState: SessionState = .closed
    
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
        public static let `default`: Options = {
            #if canImport(GRDB)
            return [.receiveUnreadMessageCountAfterSessionDidOpen,
                    .usingLocalStorage]
            #else
            return [.receiveUnreadMessageCountAfterSessionDidOpen]
            #endif
        }()
        
        /// Receive unread message count after session did open.
        public static let receiveUnreadMessageCountAfterSessionDidOpen = Options(rawValue: 1 << 0)
        
        #if canImport(GRDB)
        /// Use local storage.
        public static let usingLocalStorage = Options(rawValue: 1 << 1)
        #endif
        
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
    
    /// ref: https://github.com/leancloud/avoscloud-push/tree/master/doc/protocols
    struct SessionConfigs: OptionSet {
        let rawValue: Int64
        
        static let patchMessage = SessionConfigs(rawValue:                      1 << 0)
        static let temporaryConversationMessage = SessionConfigs(rawValue:      1 << 1)
        static let autoBindDeviceIDAndInstallation = SessionConfigs(rawValue:   1 << 2)
        static let transientMessageACK = SessionConfigs(rawValue:               1 << 3)
        static let keepNotification = SessionConfigs(rawValue:                  1 << 4)
        static let partialFailedMessage = SessionConfigs(rawValue:              1 << 5)
        static let groupChatReceipt = SessionConfigs(rawValue:                  1 << 6)
        static let omitPeerID = SessionConfigs(rawValue:                        1 << 7)
        
        static let support: SessionConfigs = [
            .patchMessage,
            .temporaryConversationMessage,
            .transientMessageACK,
            .keepNotification,
            .partialFailedMessage,
            .omitPeerID,
        ]
    }
    
    // MARK: Init
    
    /// Initialization.
    ///
    /// - Parameters:
    ///   - ID: The client identifier. Length should in range `lengthRangeOfClientID`.
    ///   - tag: The client tag. `reservedValueOfTag` should not be used.
    ///   - options: @see `IMClient.Options`.
    ///   - delegate: @see `IMClientDelegate`.
    ///   - eventQueue: @see property `eventQueue`, default is main.
    ///   - application: The application that the client belongs to.
    /// - Throws: Error.
    public init(
        application: LCApplication = LCApplication.default,
        ID: IMClient.Identifier,
        tag: String? = nil,
        options: Options = .default,
        delegate: IMClientDelegate? = nil,
        signatureDelegate: IMSignatureDelegate? = nil,
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
        self.serialQueue.setSpecific(
            key: self.specificKey,
            value: self.specificValue)
        #endif
        
        self.ID = ID
        self.tag = tag
        self.options = options
        self.delegate = delegate
        self.signatureDelegate = signatureDelegate
        self.eventQueue = eventQueue
        self.application = application
        self.installation = application.currentInstallation
        
        if let localStorageContext = application.localStorageContext {
            let localRecordURL = try localStorageContext.fileURL(
                place: .persistentData,
                module: .IM(clientID: ID),
                file: .clientRecord)
            self.localRecordURL = localRecordURL
            if let localRecord: IMClient.LocalRecord = try localStorageContext
                .table(from: localRecordURL) {
                self.underlyingLocalRecord = localRecord
            }
            
            #if canImport(GRDB)
            if options.contains(.usingLocalStorage) {
                let databaseURL = try localStorageContext.fileURL(
                    place: .persistentData,
                    module: .IM(clientID: ID),
                    file: .database
                )
                self.localStorage = try IMLocalStorage(path: databaseURL.path, clientID: ID)
                Logger.shared.verbose("""
                    \n\(IMClient.self)<ID: \"\(ID)\">
                    local database<URL: \"\(databaseURL)\">
                    initialize success.
                    """)
            }
            #endif
        }
        
        self.connection = try RTMConnectionManager.default.register(
            application: application,
            service: .instantMessaging(
                ID: ID, protocol:
                options.lcimProtocol))
        self.connectionDelegator = RTMConnection.Delegator(
            queue: self.serialQueue)
        
        self.currentDeviceToken = self.installation.deviceToken?.value
        self.deviceTokenObservation = self.installation.observe(
            \.deviceToken,
            options: [.old, .new, .initial]
        ) { [weak self] (_, change) in
            let oldToken = change.oldValue??.value
            let newToken = change.newValue??.value
            guard let token = newToken,
                newToken != oldToken else {
                    return
            }
            self?.serialQueue.async {
                guard let self = self,
                    self.currentDeviceToken != token else {
                        return
                }
                self.currentDeviceToken = token
                self.reportDeviceToken(token: token)
            }
        }
    }
    
    /// Initialization.
    ///
    /// - Parameters:
    ///   - user: The user which is valid.
    ///   - tag: The client tag. `reservedValueOfTag` should not be used.
    ///   - options: @see `IMClient.Options`.
    ///   - delegate: @see `IMClientDelegate`.
    ///   - eventQueue: @see property `eventQueue`, default is main.
    /// - Throws: Error.
    public convenience init(
        user: LCUser,
        tag: String? = nil,
        options: Options = .default,
        delegate: IMClientDelegate? = nil,
        signatureDelegate: IMSignatureDelegate? = nil,
        eventQueue: DispatchQueue = .main)
        throws
    {
        guard let objectId = user.objectId?.stringValue else {
            throw LCError.clientUserIDNotFound
        }
        try self.init(
            application: user.application,
            ID: objectId,
            tag: tag,
            options: options,
            delegate: delegate,
            signatureDelegate: signatureDelegate,
            eventQueue: eventQueue)
        self.user = user
    }
    
    deinit {
        let service = RTMConnection.Service.instantMessaging(
            ID: self.ID,
            protocol: self.options.lcimProtocol)
        self.connection.removeDelegator(service: service)
        RTMConnectionManager.default.unregister(
            application: self.application,
            service: service)
        Logger.shared.verbose("""
            \n\(IMClient.self)<ID: \"\(self.ID)\">
            deinit.
            """)
    }
    
    // MARK: Internal Property
    
    let serialQueue = DispatchQueue(
        label: "LC.Swift.\(IMClient.self).serialQueue")
    
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
    
    var sessionToken: String?
    var sessionTokenExpiration: Date?
    
    private(set) var openingCompletion: ((LCBooleanResult) -> Void)?
    private(set) var openingOptions: SessionOpenOptions?
    
    private(set) var deviceTokenObservation: NSKeyValueObservation?
    private(set) var currentDeviceToken: String?
    
    var convCollection: [String: IMConversation] = [:]
    private(set) var validInFetchingNotificationsCachedConvMapSnapshot: [String: IMConversation]?
    private(set) var convQueryCallbackCollection: [String: Array<(IMClient, LCGenericResult<IMConversation>) -> Void>] = [:]
    
    /// ref: https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md#sessionopen
    private(set) var lastUnreadNotifTime: Int64?
}

extension IMClient: InternalSynchronizing {
    // MARK: Internal Synchronizing
    
    var mutex: NSLock {
        return self.lock
    }
}

extension IMClient {
    // MARK: Local Record
    
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
        
        mutating func update(lastServerTimestamp newValue: Int64?) {
            guard let newValue = newValue else {
                return
            }
            if let oldValue = self.lastServerTimestamp {
                if newValue >= oldValue {
                    self.lastServerTimestamp = newValue
                }
            } else {
                self.lastServerTimestamp = newValue
            }
        }
    }
    
    func saveLocalRecord() {
        assert(self.specificAssertion)
        guard let url = self.localRecordURL,
            let localStorageContext = self.application.localStorageContext else {
                return
        }
        var userInfo: [String: Any] = [:]
        do {
            try localStorageContext.save(
                table: self.localRecord,
                to: url)
        } catch {
            userInfo["error"] = error
            Logger.shared.error(error)
        }
        #if DEBUG
        NotificationCenter.default.post(
            name: IMClient.TestSaveLocalRecordNotification,
            object: self,
            userInfo: userInfo)
        #endif
    }
}

extension IMClient {
    // MARK: Open & Close
    
    /// Options that can modify behaviors of session open operation.
    public struct SessionOpenOptions: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Default is `[.forced]`.
        public static let `default`: SessionOpenOptions = [.forced]
        
        /// For two sessions of the same client (have valid tag and application-id, client-id, client-tag are same), the later one will force to make the previous one offline. After later one opened success, the previous one will get session-closed-error(code: 4111).
        public static let forced = SessionOpenOptions(rawValue: 1 << 0)
        
        /// Session open with this option means this opening is reconnect. if the session has been offline by other client, then open result is session-closed-error(code: 4111).
        public static let reconnect = SessionOpenOptions(rawValue: 1 << 1)
        
        /// ref: `https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md#sessionopen`
        var r: Bool {
            return self.contains(.reconnect)
                || (self == [])
        }
    }
    
    /// Open session.
    /// - Parameters:
    ///   - options: @see `IMClient.SessionOpenOptions`, default is `.default`, empty options equal to `[.reconnect]`.
    ///   - completion: Result callback.
    public func open(
        options: SessionOpenOptions = .default,
        completion: @escaping (LCBooleanResult) -> Void)
    {
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
            
            self.connectionDelegator.delegate = self
            self.connection.connect(
                service: .instantMessaging(ID: self.ID, protocol: self.options.lcimProtocol),
                delegator: self.connectionDelegator
            )
        }
    }
    
    /// Close session.
    /// - Parameter completion: Result callback.
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
            self.connection.send(
                command: outCommand,
                service: .instantMessaging,
                peerID: self.ID,
                callingQueue: self.serialQueue)
            { [weak self] (result) in
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

extension IMClient {
    // MARK: Create Conversation
    
    /// Create a Normal Conversation. Default is a Normal Unique Conversation.
    ///
    /// - Parameters:
    ///   - clientIDs: The set of client ID. it's the members of the conversation which will be created. the initialized members always contains current client's ID. if the created conversation is unique, and server has one unique conversation with the same members, that unique conversation will be returned.
    ///   - name: The name of the conversation.
    ///   - attributes: The attributes of the conversation.
    ///   - isUnique: True means create or get a unique conversation, default is true.
    ///   - completion: Result callback.
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
            completion: completion)
    }
    
    /// Create a Chat Room.
    ///
    /// - Parameters:
    ///   - name: The name of the chat room.
    ///   - attributes: The attributes of the chat room.
    ///   - completion: Result callback.
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
            completion: completion)
    }
    
    /// Create a Temporary Conversation. Temporary Conversation is unique in it's Life Cycle.
    ///
    /// - Parameters:
    ///   - clientIDs: The set of client ID. it's the members of the conversation which will be created. the initialized members always contains this client's ID.
    ///   - timeToLive: The time interval for the life of the temporary conversation.
    ///   - completion: Result callback.
    public func createTemporaryConversation(
        clientIDs: Set<String>,
        timeToLive: Int32,
        completion: @escaping (LCGenericResult<IMTemporaryConversation>) -> Void)
        throws
    {
        try self.createConversation(
            clientIDs: clientIDs,
            option: .temporary(ttl: timeToLive),
            completion: completion)
    }
    
    enum ConversationCreationOption {
        case normal
        case normalAndUnique
        case transient
        case temporary(ttl: Int32)
        
        var isUnique: Bool {
            switch self {
            case .normalAndUnique:
                return true
            default:
                return false
            }
        }
        
        var isTransient: Bool {
            switch self {
            case .transient:
                return true
            default:
                return false
            }
        }
        
        var isTemporary: Bool {
            switch self {
            case .temporary:
                return true
            default:
                return false
            }
        }
        
        var convType: IMConversation.ConvType {
            switch self {
            case .normal, .normalAndUnique:
                return .normal
            case .transient:
                return .transient
            case .temporary:
                return .temporary
            }
        }
    }
    
    typealias ConversationCreationTuple = (members: [String], attrString: String?, option: ConversationCreationOption)
    
    func preprocessConversationCreation(
        clientIDs: Set<String>,
        name: String?,
        attributes: [String: Any]?,
        option: ConversationCreationOption)
        throws -> ConversationCreationTuple
    {
        var members: [String]
        if option.isTransient {
            members = []
        } else {
            for item in clientIDs {
                guard IMClient.lengthRangeOfClientID.contains(item.count) else {
                    throw LCError.clientIDInvalid
                }
            }
            members = Array<String>(clientIDs)
            if !clientIDs.contains(self.ID) {
                members.append(self.ID)
            }
        }
        var attr: [String: Any] = [:]
        if let name = name {
            attr[IMConversation.Key.name.rawValue] = name
        }
        if let attributes = attributes {
            attr[IMConversation.Key.attributes.rawValue] = attributes
        }
        var attrString: String?
        if !attr.isEmpty {
            let data = try JSONSerialization.data(withJSONObject: attr)
            attrString = String(data: data, encoding: .utf8)
        }
        return (members, attrString, option)
    }
    
    func newConvStartCommand(
        tuple: ConversationCreationTuple,
        signature: IMSignature? = nil)
        -> IMGenericCommand
    {
        var outCommand = IMGenericCommand()
        outCommand.cmd = .conv
        outCommand.op = .start
        var convMessage = IMConvCommand()
        switch tuple.option {
        case .normal:
            break
        case .normalAndUnique:
            convMessage.unique = true
        case .transient:
            convMessage.transient = true
        case .temporary(ttl: let ttl):
            convMessage.tempConv = true
            if ttl > 0 {
                convMessage.tempConvTtl = ttl
            }
        }
        if !tuple.option.isTransient {
            convMessage.m = tuple.members
        }
        if let attrString = tuple.attrString {
            var attrMessage = IMJsonObjectMessage()
            attrMessage.data = attrString
            convMessage.attr = attrMessage
        }
        if let signature = signature {
            convMessage.s = signature.signature
            convMessage.t = signature.timestamp
            convMessage.n = signature.nonce
        }
        outCommand.convMessage = convMessage
        return outCommand
    }
    
    func getConvStartCommand(
        tuple: ConversationCreationTuple,
        completion: @escaping (IMClient, IMGenericCommand) -> Void)
    {
        if let signatureDelegate = self.signatureDelegate {
            let action: IMSignature.Action = .createConversation(
                memberIDs: Set(tuple.members))
            self.eventQueue.async {
                signatureDelegate.client(
                    self, action: action)
                { (client, signature) in
                    client.serialQueue.async {
                        completion(client, client.newConvStartCommand(
                            tuple: tuple,
                            signature: signature))
                    }
                }
            }
        } else {
            completion(self, self.newConvStartCommand(
                tuple: tuple))
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
            option: option)
        let sendingClosure: (IMClient, IMGenericCommand) -> Void = { (client, outCommand) in
            client.sendCommand(constructor: { outCommand }) { (client, result) in
                switch result {
                case .inCommand(let inCommand):
                    assert(client.specificAssertion)
                    do {
                        let conversation: T = try client.conversationInstance(
                            inCommand: inCommand,
                            tuple: tuple)
                        client.eventQueue.async {
                            completion(.success(value: conversation))
                        }
                    } catch {
                        client.eventQueue.async {
                            completion(.failure(
                                error: LCError(error: error)))
                        }
                    }
                case .error(let error):
                    client.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            }
        }
        if option.isTemporary {
            sendingClosure(self, self.newConvStartCommand(
                tuple: tuple))
        } else {
            self.getConvStartCommand(
                tuple: tuple,
                completion: sendingClosure)
        }
    }
    
    func conversationInstance<T: IMConversation>(
        inCommand: IMGenericCommand,
        tuple: ConversationCreationTuple)
        throws -> T
    {
        assert(self.specificAssertion)
        guard let convMessage = (inCommand.hasConvMessage ? inCommand.convMessage : nil),
            let conversationID = (convMessage.hasCid ? convMessage.cid : nil) else {
                throw LCError(
                    code: .commandInvalid,
                    userInfo: ["command": "\(inCommand)"])
        }
        var attributes: [String: Any] = [:]
        if let attrObject: [String: Any] = try tuple.attrString?.jsonObject() {
            attributes = attrObject
        }
        let conversation: IMConversation
        if let existConversation = self.convCollection[conversationID] {
            existConversation.safeExecuting(
                operation: .rawDataMerging(
                    data: attributes),
                client: self)
            #if canImport(GRDB)
            if existConversation.isUnique {
                existConversation.tryUpdateLocalStorageData(
                    client: self,
                    rawData: existConversation.rawData)
            }
            #endif
            conversation = existConversation
        } else {
            let key = IMConversation.Key.self
            attributes[key.objectId.rawValue] = conversationID
            attributes[key.convType.rawValue] = tuple.option.convType.rawValue
            attributes[key.creator.rawValue] = self.ID
            if tuple.option.isTransient {
                attributes[key.transient.rawValue] = true
            } else {
                attributes[key.members.rawValue] = tuple.members
            }
            if tuple.option.isUnique {
                attributes[key.unique.rawValue] = true
            }
            if convMessage.hasCdate {
                attributes[key.createdAt.rawValue] = convMessage.cdate
            }
            if convMessage.hasUniqueID {
                attributes[key.uniqueId.rawValue] = convMessage.uniqueID
            }
            if tuple.option.isTemporary {
                attributes[key.temporary.rawValue] = true
            }
            if convMessage.hasTempConvTtl {
                attributes[key.temporaryTTL.rawValue] = convMessage.tempConvTtl
            }
            if let rawData: IMConversation.RawData = try attributes.jsonObject() {
                conversation = IMConversation.instance(
                    ID: conversationID,
                    rawData: rawData,
                    client: self,
                    caching: true)
            } else {
                throw LCError(
                    code: .malformedData,
                    userInfo: ["data": attributes])
            }
        }
        if let conversation = conversation as? T {
            self.convCollection[conversationID] = conversation
            return conversation
        } else {
            throw LCError(
                code: .invalidType,
                reason: "conversation type casting failed.",
                userInfo: [
                    "sourceType": "\(type(of: conversation))",
                    "targetType": "\(T.self)"])
        }
    }
}

extension IMClient {
    // MARK: Conversation Query
    
    /// Create a new conversation query.
    public var conversationQuery: IMConversationQuery {
        return IMConversationQuery(client: self, eventQueue: self.eventQueue)
    }
}

extension IMClient {
    // MARK: Conversation Memory Cache
    
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

extension IMClient {
    // MARK: Session Query
    
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

#if canImport(GRDB)
extension IMClient {
    // MARK: Local Storage
    
    /// Open database of the local storage.
    ///
    /// - Parameter completion: Result of callback
    /// - Throws: If client not init with `usingLocalStorage`, then throws error.
    public func prepareLocalStorage(completion: @escaping (LCBooleanResult) -> Void) throws {
        guard let localStorage = self.localStorage else {
            throw LCError.clientLocalStorageNotFound
        }
        self.serialQueue.async {
            do {
                try localStorage.createTablesIfNotExists()
                self.eventQueue.async {
                    completion(.success)
                }
            } catch {
                self.eventQueue.async {
                    completion(.failure(error: LCError(error: error)))
                }
            }
        }
    }
    
    /// Query Order Option for stored conversations.
    ///
    /// - updatedTimestamp: By updated timestamp.
    /// - createdTimestamp: By created timestamp.
    /// - lastMessageSentTimestamp: By last message sent timestamp.
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
    
    /// Get stored conversations and load them to memory container.
    ///
    /// - Parameters:
    ///   - order: @see `IMClient.StoredConversationOrder`.
    ///   - completion: Result of callback.
    /// - Throws: If client not init with `usingLocalStorage`, then throws error.
    public func getAndLoadStoredConversations(
        order: IMClient.StoredConversationOrder = .lastMessageSentTimestamp(descending: true),
        completion: @escaping (LCGenericResult<[IMConversation]>) -> Void)
        throws
    {
        guard let localStorage = self.localStorage else {
            throw LCError.clientLocalStorageNotFound
        }
        self.serialQueue.async {
            do {
                let result = try localStorage.selectConversations(order: order, client: self)
                self.convCollection.merge(result.conversationMap) { (current, _) in current }
                self.eventQueue.async {
                    completion(.success(value: result.conversations))
                }
            } catch {
                self.eventQueue.async {
                    completion(.failure(error: LCError(error: error)))
                }
            }
        }
    }
    
    /// Delete the stored conversations and the messages belong to them.
    ///
    /// - Parameters:
    ///   - IDs: The ID set of the conversations that will be deleted.
    ///   - completion: Result of callback.
    /// - Throws: If client not init with `usingLocalStorage`, then throws error.
    public func deleteStoredConversationAndMessages(
        IDs: Set<String>,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
    {
        guard let localStorage = self.localStorage else {
            throw LCError.clientLocalStorageNotFound
        }
        self.serialQueue.async {
            do {
                try localStorage.deleteConversationAndMessages(IDs: IDs)
                self.eventQueue.async {
                    completion(.success)
                }
            } catch {
                self.eventQueue.async {
                    completion(.failure(error: LCError(error: error)))
                }
            }
        }
    }
    
}
#endif

extension IMClient {
    
    static func date(fromMillisecond timestamp: Int64?) -> Date? {
        guard let timestamp = timestamp else {
            return nil
        }
        let second = TimeInterval(timestamp) / 1000.0
        return Date(timeIntervalSince1970: second)
    }
    
    // MARK: Send Command
    
    func sendCommand(
        constructor: () -> IMGenericCommand,
        completion: ((IMClient, RTMConnection.CommandCallback.Result) -> Void)? = nil)
    {
        let outCommand: IMGenericCommand = constructor()
        guard self.isSessionOpened else {
            let error = LCError(code: .clientNotOpen)
            completion?(self, .error(error))
            return
        }
        if let completion = completion {
            self.connection.send(
                command: outCommand,
                service: .instantMessaging,
                peerID: self.ID,
                callingQueue: self.serialQueue)
            { [weak self] (result) in
                guard let client: IMClient = self else {
                    return
                }
                completion(client, result)
            }
        } else {
            self.connection.send(
                command: outCommand,
                service: .instantMessaging,
                peerID: self.ID)
        }
    }
    
    // MARK: Offline Notification
    
    func getOfflineEvents(serverTimestamp: Int64?, currentConvCollection: [String: IMConversation]) {
        assert(self.specificAssertion)
        guard let serverTimestamp: Int64 = serverTimestamp else {
            return
        }
        self.validInFetchingNotificationsCachedConvMapSnapshot = currentConvCollection
        self.getSessionToken { (client, result) in
            assert(client.specificAssertion)
            switch result {
            case .failure(error: let error):
                client.validInFetchingNotificationsCachedConvMapSnapshot = nil
                Logger.shared.error(error)
            case .success(value: let token):
                let parameters: [String: Any] = [
                    "client_id": client.ID,
                    "start_ts": serverTimestamp,
                ]
                let headers: [String: String] = [
                    "X-LC-IM-Session-Token": token,
                ]
                let _ = client.application.httpClient.request(
                    .get, "/rtm/notifications",
                    parameters: parameters,
                    headers: headers,
                    completionQueue: client.serialQueue)
                { [weak client] (response) in
                    guard let client = client else {
                        return
                    }
                    assert(client.specificAssertion)
                    client.validInFetchingNotificationsCachedConvMapSnapshot = nil
                    if let error = LCError(response: response) {
                        Logger.shared.error(error)
                    } else if let responseValue = response.value as? [String: Any] {
                        client.handleOfflineEvents(
                            response: responseValue,
                            convsSnapshot: Array(currentConvCollection.values))
                    } else {
                        Logger.shared.error(
                            "unknown response value: \(String(describing: response.value))")
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
                    #if canImport(GRDB)
                    conv.tryUpdateLocalStorageData(client: self, outdated: true)
                    #endif
                }
            } else if let notifications = droppable["notifications"] as? [[String: Any]] {
                mapReduce(notifications)
            }
        }
        
        return (sortedNotificationTuplesMap, existIDs, queryIDs, queryTempIDs)
    }
    
    // MARK: Session
    
    func newSessionCommand(
        op: IMOpType = .open,
        token: String? = nil,
        signature: IMSignature? = nil,
        isReopen: Bool? = nil)
        -> IMGenericCommand
    {
        assert(self.specificAssertion)
        var outCommand = IMGenericCommand()
        outCommand.cmd = .session
        outCommand.op = op
        var sessionCommand = IMSessionCommand()
        switch op {
        case .open:
            outCommand.appID = self.application.id
            outCommand.peerID = self.ID
            sessionCommand.configBitmap = SessionConfigs.support.rawValue
            sessionCommand.deviceToken = self.currentDeviceToken
                ?? Utility.UDID
            sessionCommand.ua = self.application
                .httpClient.configuration.userAgent
            if let tag = self.tag {
                sessionCommand.tag = tag
            }
            if let r = isReopen {
                sessionCommand.r = r
            }
            if let lastUnreadNotifTime = self.lastUnreadNotifTime {
                sessionCommand.lastUnreadNotifTime = lastUnreadNotifTime
            }
            if let lastPatchTime = self.localRecord.lastPatchTimestamp {
                sessionCommand.lastPatchTime = lastPatchTime
            }
            if let token = token {
                sessionCommand.st = token
            }
            if let signature = signature {
                sessionCommand.s = signature.signature
                sessionCommand.t = signature.timestamp
                sessionCommand.n = signature.nonce
            }
        case .refresh:
            assert(token != nil)
            sessionCommand.st = token!
        default:
            fatalError()
        }
        outCommand.sessionMessage = sessionCommand
        return outCommand
    }
    
    func getOpenSignature(
        userSessionToken token: String,
        completion: @escaping (IMClient, LCGenericResult<IMSignature>) -> Void)
    {
        _ = self.application.httpClient.request(
            .post, "/rtm/sign",
            parameters: ["session_token": token],
            completionQueue: self.serialQueue)
        { [weak self] (response) in
            guard let self = self else {
                return
            }
            assert(self.specificAssertion)
            if let error = LCError(response: response) {
                completion(self, .failure(error: error))
            } else {
                guard let value = response.value as? [String: Any],
                    let signature = value["signature"] as? String,
                    let timestamp = value["timestamp"] as? Int64,
                    let nonce = value["nonce"] as? String else {
                        let error = LCError(
                            code: .malformedData,
                            reason: "response data malformed",
                            userInfo: ["data": response.value ?? "nil"])
                        completion(self, .failure(error: error))
                        return
                }
                let sign = IMSignature(
                    signature: signature,
                    timestamp: timestamp,
                    nonce: nonce)
                completion(self, .success(value: sign))
            }
        }
    }
    
    func getSessionOpenCommand(
        token: String? = nil,
        isReopen: Bool,
        completion: @escaping (IMClient, IMGenericCommand) -> Void)
    {
        if let token = token {
            completion(self, self.newSessionCommand(
                token: token,
                isReopen: isReopen))
        } else if let userSessionToken = self.user?.sessionToken?.value {
            self.getOpenSignature(
                userSessionToken: userSessionToken)
            { (client, result) in
                assert(client.specificAssertion)
                switch result {
                case .success(value: let signature):
                    completion(client, client.newSessionCommand(
                        signature: signature,
                        isReopen: isReopen))
                case .failure(error: let error):
                    if error.code == LCError.InternalErrorCode
                        .underlyingError.rawValue {
                        Logger.shared.error(error)
                    } else {
                        client.sessionClosed(
                            with: .failure(error: error),
                            completion: client.openingCompletion)
                    }
                }
            }
        } else if let signatureDelegate = self.signatureDelegate {
            self.eventQueue.async {
                signatureDelegate.client(
                    self, action: .open)
                { (client, signature) in
                    client.serialQueue.async {
                        completion(client, client.newSessionCommand(
                            signature: signature,
                            isReopen: isReopen))
                    }
                }
            }
        } else {
            completion(self, self.newSessionCommand(
                isReopen: isReopen))
        }
    }
    
    func sendSessionReopenCommand(command: IMGenericCommand) {
        assert(self.specificAssertion)
        self.connection.send(
            command: command,
            service: .instantMessaging,
            peerID: self.ID,
            callingQueue: self.serialQueue)
        { [weak self] (result) in
            guard let client = self else {
                return
            }
            assert(client.specificAssertion)
            switch result {
            case .inCommand(let command):
                client.handleSessionOpenCallback(command: command)
            case .error(let error):
                switch error.code {
                case LCError.InternalErrorCode.commandTimeout.rawValue:
                    client.sendSessionReopenCommand(command: command)
                case LCError.InternalErrorCode.connectionLost.rawValue:
                    Logger.shared.debug(error)
                case LCError.ServerErrorCode.sessionTokenExpired.rawValue:
                    client.getSessionOpenCommand(
                        isReopen: true)
                    { (client, openCommand) in
                        client.sendSessionReopenCommand(command: openCommand)
                        #if DEBUG
                        NotificationCenter.default.post(
                            name: IMClient.TestSessionTokenExpiredNotification,
                            object: client,
                            userInfo: ["error": error])
                        #endif
                    }
                default:
                    client.sessionClosed(
                        with: .failure(error: error))
                }
            }
        }
    }
    
    func reportDeviceToken(
        token: String?,
        openCommand: IMGenericCommand? = nil)
    {
        assert(self.specificAssertion)
        guard let token = token else {
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
            NotificationCenter.default.post(
                name: IMClient.TestReportDeviceTokenNotification,
                object: client,
                userInfo: ["result": result])
            #endif
        }
    }
    
    func handleSessionOpenCallback(
        command: IMGenericCommand,
        openCommand: IMGenericCommand? = nil,
        completion: ((LCBooleanResult) -> Void)? = nil)
    {
        assert(self.specificAssertion)
        switch (command.cmd, command.op) {
        case (.session, .opened):
            self.openingCompletion = nil
            self.openingOptions = nil
            let sessionMessage = command.sessionMessage
            if sessionMessage.hasSt && sessionMessage.hasStTtl {
                self.sessionToken = sessionMessage.st
                self.sessionTokenExpiration = Date(
                    timeIntervalSinceNow: TimeInterval(sessionMessage.stTtl))
            }
            self.sessionState = .opened
            if let lastServerTimestamp = self.localRecord.lastServerTimestamp {
                self.getOfflineEvents(
                    serverTimestamp: lastServerTimestamp,
                    currentConvCollection: self.convCollection)
            }
            if self.localRecord.lastPatchTimestamp == nil {
                self.localRecord.update(
                    lastPatchTimestamp: (command.hasServerTs
                        ? command.serverTs
                        : nil))
            }
            if let openCommand = openCommand {
                self.reportDeviceToken(
                    token: self.currentDeviceToken,
                    openCommand: openCommand)
            }
            self.eventQueue.async {
                if let completion = completion {
                    completion(.success)
                } else {
                    self.delegate?.client(self, event: .sessionDidOpen)
                }
            }
        case (.session, .closed):
            self.sessionClosed(
                with: .failure(error: command.sessionMessage.lcError
                    ?? LCError(code: .commandInvalid)),
                completion: completion)
        default:
            self.sessionClosed(
                with: .failure(error: LCError(code: .commandInvalid)),
                completion: completion)
        }
    }
    
    func sessionClosed(
        with result: LCBooleanResult,
        completion: ((LCBooleanResult) -> Void)? = nil)
    {
        assert(self.specificAssertion)
        self.connectionDelegator.delegate = nil
        self.connection.removeDelegator(
            service: .instantMessaging(
                ID: self.ID,
                protocol: self.options.lcimProtocol))
        self.sessionToken = nil
        self.sessionTokenExpiration = nil
        self.openingCompletion = nil
        self.openingOptions = nil
        self.sessionState = .closed
        self.eventQueue.async {
            if let completion = completion {
                completion(result)
            } else if let error = result.error {
                self.delegate?.client(
                    self, event: .sessionDidClose(
                        error: error))
            }
        }
    }
    
    func refreshSessionToken(
        oldToken: String,
        completion: @escaping (IMClient, LCGenericResult<String>) -> Void)
    {
        assert(self.specificAssertion)
        self.sendCommand(constructor: {
            self.newSessionCommand(
                op: .refresh,
                token: oldToken)
        }) { (client, result) in
            switch result {
            case .inCommand(let command):
                assert(client.specificAssertion)
                guard let sessionMessage = (command.hasSessionMessage ? command.sessionMessage : nil),
                    let token = (sessionMessage.hasSt ? sessionMessage.st : nil),
                    let ttl = (sessionMessage.hasStTtl ? sessionMessage.stTtl : nil) else {
                        completion(client, .failure(
                            error: LCError(code: .commandInvalid)))
                        return
                }
                client.sessionToken = token
                client.sessionTokenExpiration = Date(
                    timeIntervalSinceNow: TimeInterval(ttl))
                completion(client, .success(value: token))
            case .error(let error):
                completion(client, .failure(error: error))
            }
        }
    }
    
    func getSessionToken(completion: @escaping (IMClient, LCGenericResult<String>) -> Void) {
        assert(self.specificAssertion)
        if let token = self.sessionToken {
            if let expiration = self.sessionTokenExpiration,
                expiration > Date() {
                completion(self, .success(value: token))
            } else {
                self.refreshSessionToken(
                    oldToken: token,
                    completion: completion)
            }
        } else {
            completion(self, .failure(
                error: LCError(code: .clientNotOpen)))
        }
    }
    
    // MARK: Query Conversation
    
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
                try query.getTemporaryConversation(by: ID) { [weak self] (result) in
                    guard let client = self else { return }
                    assert(client.specificAssertion)
                    switch result {
                    case .success(value: let conversation):
                        callback(client, .success(value: conversation))
                    case .failure(error: let error):
                        callback(client, .failure(error: error))
                    }
                }
            } else {
                try query.getConversation(by: ID) { [weak self] (result) in
                    guard let client = self else { return }
                    assert(client.specificAssertion)
                    callback(client, result)
                }
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
                try query.getTemporaryConversations(by: IDs) { [weak self] (result) in
                    guard let client = self else { return }
                    assert(client.specificAssertion)
                    switch result {
                    case .success(value: let conversations):
                        completion(client, .success(value: conversations))
                    case .failure(error: let error):
                        completion(client, .failure(error: error))
                    }
                }
            } catch {
                assert(self.specificAssertion)
                completion(self, .failure(error: LCError(error: error)))
            }
        }
    }
    
    // MARK: Process In-Command
    
    typealias ConvEventTuple = (operation: IMConversation.Operation?, event: IMConversationEvent?, shouldCheckOutdated: Bool)
    
    private func memberChangedEventTuple(
        command: IMConvCommand,
        op: IMOpType)
        -> ConvEventTuple
    {
        let operation: IMConversation.Operation
        let event: IMConversationEvent
        
        let byClientID: String? = (command.hasInitBy ? command.initBy : nil)
        let udate: String? = (command.hasUdate ? command.udate : nil)
        let atDate: Date? = (command.hasUdate ? LCDate.dateFromString(command.udate) : nil)
        
        switch op {
        case .joined:
            operation = .append(members: [self.ID], udate: udate)
            event = .joined(byClientID: byClientID, at: atDate)
        case .left:
            operation = .remove(members: [self.ID], udate: udate)
            event = .left(byClientID: byClientID, at: atDate)
        case .membersJoined:
            operation = .append(members: command.m, udate: udate)
            event = .membersJoined(members: command.m, byClientID: byClientID, at: atDate)
        case .membersLeft:
            operation = .remove(members: command.m, udate: udate)
            event = .membersLeft(members: command.m, byClientID: byClientID, at: atDate)
        default:
            fatalError()
        }
        
        return (operation, event, true)
    }
    
    private func conversationDataUpdatedEventTuple(command: IMConvCommand) throws -> ConvEventTuple {
        let operation: IMConversation.Operation
        let event: IMConversationEvent
        
        if command.hasAttr, command.attr.hasData,
            let attr: [String: Any] = try command.attr.data.jsonObject(),
            command.hasAttrModified, command.attrModified.hasData,
            let attrModified: [String: Any] = try command.attrModified.data.jsonObject() {
            operation = .updated(
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
            throw LCError(code: .commandInvalid)
        }
        
        return (operation, event, true)
    }
    
    private func memberInfoChangedEventTuple(
        command: IMConvCommand,
        conversation: IMConversation,
        serverTimestamp: Int64?)
        throws
        -> ConvEventTuple
    {
        let operation: IMConversation.Operation
        let event: IMConversationEvent
        
        if let info = (command.hasInfo ? command.info : nil),
            let memberID = (info.hasPid ? info.pid : nil),
            let roleRawValue = (info.hasRole ? info.role : nil),
            let role = IMConversation.MemberRole(rawValue: roleRawValue) {
            let memberInfo = IMConversation.MemberInfo(
                ID: memberID,
                role: role,
                conversationID: conversation.ID,
                creator: conversation.creator
            )
            let byClientID = (command.hasInitBy ? command.initBy : nil)
            let atDate = IMClient.date(fromMillisecond: serverTimestamp)
            operation = .memberInfoChanged(info: memberInfo)
            event = IMConversationEvent.memberInfoChanged(info: memberInfo, byClientID: byClientID, at: atDate)
        } else {
            throw LCError(code: .commandInvalid)
        }
        
        return (operation, event, false)
    }
    
    private func blockedOrMutedMembersChanged(
        command: IMConvCommand,
        op: IMOpType,
        serverTimestamp: Int64?)
        -> ConvEventTuple
    {
        let event: IMConversationEvent
        
        let members: [String] = command.m
        let byClientID: String? = (command.hasInitBy ? command.initBy : nil)
        let atDate: Date? = IMClient.date(fromMillisecond: serverTimestamp)
        
        switch op {
        case .blocked:
            event = .blocked(byClientID: byClientID, at: atDate)
        case .unblocked:
            event = .unblocked(byClientID: byClientID, at: atDate)
        case .membersBlocked:
            event = .membersBlocked(members: members, byClientID: byClientID, at: atDate)
        case .membersUnblocked:
            event = .membersUnblocked(members: members, byClientID: byClientID, at: atDate)
        case .shutuped:
            event = .muted(byClientID: byClientID, at: atDate)
        case .unshutuped:
            event = .unmuted(byClientID: byClientID, at: atDate)
        case .membersShutuped:
            event = .membersMuted(members: members, byClientID: byClientID, at: atDate)
        case .membersUnshutuped:
            event = .membersUnmuted(members: members, byClientID: byClientID, at: atDate)
        default:
            fatalError()
        }
        
        return (nil, event, false)
    }
    
    func process(convCommand command: IMConvCommand, op: IMOpType, serverTimestamp: Int64?) {
        assert(self.specificAssertion)
        guard let conversationID: String = (command.hasCid ? command.cid : nil) else {
            return
        }
        self.getConversation(by: conversationID) { (client, result) in
            assert(client.specificAssertion)
            switch result {
            case .success(value: let conversation):
                let tuple: ConvEventTuple
                switch op {
                case .joined, .left, .membersJoined, .membersLeft:
                    tuple = client.memberChangedEventTuple(command: command, op: op)
                case .updated:
                    do {
                        tuple = try client.conversationDataUpdatedEventTuple(command: command)
                    } catch {
                        Logger.shared.error(error)
                        return
                    }
                case .memberInfoChanged:
                    do {
                        tuple = try client.memberInfoChangedEventTuple(
                            command: command,
                            conversation: conversation,
                            serverTimestamp: serverTimestamp
                        )
                    } catch {
                        Logger.shared.error(error)
                        return
                    }
                case .blocked, .unblocked,
                     .membersBlocked, .membersUnblocked,
                     .shutuped, .unshutuped,
                     .membersShutuped, .membersUnshutuped:
                    tuple = client.blockedOrMutedMembersChanged(
                        command: command,
                        op: op,
                        serverTimestamp: serverTimestamp
                    )
                default:
                    return
                }
                if let operation: IMConversation.Operation = tuple.operation {
                    conversation.safeExecuting(operation: operation, client: client)
                }
                client.localRecord.update(lastServerTimestamp: serverTimestamp)
                if
                    tuple.shouldCheckOutdated,
                    let _ = self.validInFetchingNotificationsCachedConvMapSnapshot?[conversationID]
                {
                    conversation.isOutdated = true
                    #if canImport(GRDB)
                    conversation.tryUpdateLocalStorageData(client: client, outdated: true)
                    #endif
                }
                if let event: IMConversationEvent = tuple.event {
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
            !message.isTransient,
            conversation.convType != .transient,
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
                guard let timestamp: Int64 = (command.hasTimestamp ? command.timestamp : nil),
                    let messageID: String = (command.hasID ? command.id : nil) else {
                        return
                }
                let message = IMMessage.instance(
                    application: client.application,
                    conversationID: conversationID,
                    currentClientID: client.ID,
                    fromClientID: (command.hasFromPeerID ? command.fromPeerID : nil),
                    timestamp: timestamp,
                    patchedTimestamp: (command.hasPatchTimestamp ? command.patchTimestamp : nil),
                    messageID: messageID,
                    content: command.lcMessageContent,
                    isAllMembersMentioned: (command.hasMentionAll ? command.mentionAll : nil),
                    mentionedMembers: (command.mentionPids.isEmpty ? nil : command.mentionPids),
                    isTransient: (command.hasTransient ? command.transient : false))
                let isUnreadMessageIncreased = conversation.safeUpdatingLastMessage(
                    newMessage: message,
                    client: client)
                var unreadEvent: IMConversationEvent?
                if client.options.isProtobuf3,
                    isUnreadMessageIncreased {
                    conversation.unreadMessageCount += 1
                    unreadEvent = .unreadMessageCountUpdated
                }
                client.acknowledging(
                    message: message,
                    conversation: conversation)
                client.eventQueue.async {
                    if let unreadUpdatedEvent = unreadEvent {
                        client.delegate?.client(
                            client, conversation: conversation,
                            event: unreadUpdatedEvent)
                    }
                    client.delegate?.client(
                        client, conversation: conversation,
                        event: .message(
                            event: .received(message: message)))
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
        guard let conversationID = (rcpCommand.hasCid ? rcpCommand.cid : nil) else {
            return
        }
        self.getConversation(by: conversationID) { (client, result) in
            assert(client.specificAssertion)
            switch result {
            case .success(value: let conversation):
                guard let messageID = (rcpCommand.hasID ? rcpCommand.id : nil),
                    let timestamp = (rcpCommand.hasT ? rcpCommand.t : nil) else {
                        return
                }
                let fromID = (rcpCommand.hasFrom ? rcpCommand.from : nil)
                let isRead = (rcpCommand.hasRead ? rcpCommand.read : false)
                let messageEvent: IMMessageEvent
                if isRead {
                    messageEvent = .read(
                        byClientID: fromID,
                        messageID: messageID,
                        readTimestamp: timestamp)
                } else {
                    messageEvent = .delivered(
                        toClientID: fromID,
                        messageID: messageID,
                        deliveredTimestamp: timestamp)
                }
                client.localRecord.update(
                    lastServerTimestamp: serverTimestamp)
                client.eventQueue.async {
                    client.delegate?.client(
                        client, conversation: conversation,
                        event: .message(
                            event: messageEvent))
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
        case info = "info"
        // rcp
        case id = "id"
        case t = "t"
        case read = "read"
        case from = "from"
        // conv member info
        case pid = "pid"
        case role = "role"
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
        case memberInfoChanged = "member-info-changed"
        case blocked = "blocked"
        case unblocked = "unblocked"
        case membersBlocked = "members-blocked"
        case membersUnblocked = "members-unblocked"
        case shutuped = "shutuped"
        case membersShutuped = "members-shutuped"
        case unshutuped = "unshutuped"
        case membersUnshutuped = "members-unshutuped"
        
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
            case .memberInfoChanged:
                return .memberInfoChanged
            case .blocked:
                return .blocked
            case .unblocked:
                return .unblocked
            case .membersBlocked:
                return .membersBlocked
            case .membersUnblocked:
                return .membersUnblocked
            case .shutuped:
                return .shutuped
            case .unshutuped:
                return .unshutuped
            case .membersShutuped:
                return .membersShutuped
            case .membersUnshutuped:
                return .membersUnshutuped
            }
        }
    }
    
    func process(notification: [String: Any], conversationID: String, serverTimestamp: Int64) {
        assert(self.specificAssertion)
        let key = NotificationKey.self
        guard
            let cmdValue = notification[key.cmd.rawValue] as? String,
            let cmd = NotificationCommand(rawValue: cmdValue) else
        {
            return
        }
        switch cmd {
        case .conv:
            guard
                let opValue = notification[key.op.rawValue] as? String,
                let op = NotificationOperation(rawValue: opValue) else
            {
                return
            }
            var convCommand = IMConvCommand()
            convCommand.cid = conversationID
            if let udate = notification[key.udate.rawValue] as? String {
                convCommand.udate = udate
            }
            if let initBy = notification[key.initBy.rawValue] as? String {
                convCommand.initBy = initBy
            }
            switch op {
            case .joined, .left, .blocked, .unblocked, .shutuped, .unshutuped:
                break
            case .membersJoined, .membersLeft, .membersBlocked, .membersUnblocked, .membersShutuped, .membersUnshutuped:
                if let m = notification[key.m.rawValue] as? [String] {
                    convCommand.m = m
                }
            case .updated:
                let setAttribution: (NotificationKey) -> Void = { key in
                    do {
                        if let attr = notification[key.rawValue] as? [String: Any], let data = try attr.jsonString() {
                            var jsonObject = IMJsonObjectMessage()
                            jsonObject.data = data
                            switch key {
                            case .attr:
                                convCommand.attr = jsonObject
                            case .attrModified:
                                convCommand.attrModified = jsonObject
                            default:
                                fatalError()
                            }
                        }
                    } catch {
                        Logger.shared.error(error)
                    }
                }
                setAttribution(.attr)
                setAttribution(.attrModified)
            case .memberInfoChanged:
                if
                    let info = notification[key.info.rawValue] as? [String: Any],
                    let pid = info[key.pid.rawValue] as? String,
                    let role = info[key.role.rawValue] as? String
                {
                    var memberInfo = IMConvMemberInfo()
                    memberInfo.pid = pid
                    memberInfo.role = role
                    convCommand.info = memberInfo
                }
            }
            self.process(convCommand: convCommand, op: op.opType, serverTimestamp: serverTimestamp)
        case .rcp:
            var rcpCommand = IMRcpCommand()
            rcpCommand.cid = conversationID
            if let mid = notification[key.id.rawValue] as? String {
                rcpCommand.id = mid
            }
            if let timestamp = notification[key.t.rawValue] as? Int64 {
                rcpCommand.t = timestamp
            }
            if let isRead = notification[key.read.rawValue] as? Bool {
                rcpCommand.read = isRead
            }
            if let fromPeerID = notification[key.from.rawValue] as? String {
                rcpCommand.from = fromPeerID
            }
            self.process(rcpCommand: rcpCommand, serverTimestamp: serverTimestamp)
        }
    }
}

extension IMClient: RTMConnectionDelegate {
    // MARK: Connection Delegate
    
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
        if let openingCompletion = self.openingCompletion,
            let openingOptions = self.openingOptions {
            self.getSessionOpenCommand(
                isReopen: openingOptions.r)
            { (client, openCommand) in
                weak var wClient = client
                client.connection.send(
                    command: openCommand,
                    service: .instantMessaging,
                    peerID: client.ID,
                    callingQueue: client.serialQueue)
                { (result) in
                    guard let sClient = wClient else {
                        return
                    }
                    assert(sClient.specificAssertion)
                    switch result {
                    case .inCommand(let command):
                        sClient.handleSessionOpenCallback(
                            command: command,
                            openCommand: openCommand,
                            completion: openingCompletion)
                    case .error(let error):
                        sClient.sessionClosed(
                            with: .failure(error: error),
                            completion: openingCompletion)
                    }
                }
            }
        } else if let sessionToken = self.sessionToken {
            var isExpired = false
            if let expiration = self.sessionTokenExpiration,
                expiration < Date() {
                isExpired = true
            }
            self.getSessionOpenCommand(
                token: isExpired ? nil : sessionToken,
                isReopen: true)
            { (client, openCommand) in
                client.sendSessionReopenCommand(command: openCommand)
            }
        }
    }
    
    func connection(_ connection: RTMConnection, didDisconnect error: LCError) {
        assert(self.specificAssertion)
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
        guard inCommand.service == RTMService.instantMessaging.rawValue else {
            return
        }
        let serverTimestamp: Int64? = (inCommand.hasServerTs ? inCommand.serverTs : nil)
        switch inCommand.cmd {
        case .session:
            switch inCommand.op {
            case .closed:
                self.sessionClosed(with: .failure(
                    error: inCommand.sessionMessage.lcError
                        ?? LCError(code: .commandInvalid)))
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
public enum IMClientEvent {
    /// Session opened event.
    case sessionDidOpen
    /// Session in resuming event.
    case sessionDidResume
    /// Session paused event.
    case sessionDidPause(error: LCError)
    /// Session closed event.
    case sessionDidClose(error: LCError)
}

/// The events about conversation that belong to the client.
public enum IMConversationEvent {
    /// This client joined this conversation.
    case joined(byClientID: String?, at: Date?)
    /// This client left this conversation.
    case left(byClientID: String?, at: Date?)
    /// The members joined this conversation.
    case membersJoined(members: [String], byClientID: String?, at: Date?)
    /// The members left this conversation.
    case membersLeft(members: [String], byClientID: String?, at: Date?)
    /// The info of the member in this conversaiton has been changed.
    case memberInfoChanged(info: IMConversation.MemberInfo, byClientID: String?, at: Date?)
    /// The client in this conversation has been blocked.
    case blocked(byClientID: String?, at: Date?)
    /// The client int this conversation has been unblocked.
    case unblocked(byClientID: String?, at: Date?)
    /// The members in this conversation have been blocked.
    case membersBlocked(members: [String], byClientID: String?, at: Date?)
    /// The members in this conversation have been unblocked.
    case membersUnblocked(members: [String], byClientID: String?, at: Date?)
    /// The client in this conversation has been muted.
    case muted(byClientID: String?, at: Date?)
    /// The client in this conversation has been unmuted.
    case unmuted(byClientID: String?, at: Date?)
    /// The members in this conversation have been muted.
    case membersMuted(members: [String], byClientID: String?, at: Date?)
    /// The members in this conversation have been unmuted.
    case membersUnmuted(members: [String], byClientID: String?, at: Date?)
    /// The data of this conversation has been updated.
    case dataUpdated(updatingData: [String: Any]?, updatedData: [String: Any]?, byClientID: String?, at: Date?)
    /// The last message of this conversation has been updated, if *newMessage* is *false*, means the message has been modified.
    case lastMessageUpdated(newMessage: Bool)
    /// The last delivered time of message to other in this conversation has been updated.
    case lastDeliveredAtUpdated
    /// The last read time of message by other in this conversation has been updated.
    case lastReadAtUpdated
    /// The unread message count for this client in this conversation has been updated.
    case unreadMessageCountUpdated
    /// The events about message that belong to this conversation, @see `IMMessageEvent`.
    case message(event: IMMessageEvent)
}

/// The events about message that belong to the conversation.
public enum IMMessageEvent {
    /// The new message received from this conversation.
    case received(message: IMMessage)
    /// The message in this conversation has been updated.
    case updated(updatedMessage: IMMessage, reason: IMMessage.PatchedReason?)
    /// The message has been delivered to other.
    case delivered(toClientID: String?, messageID: String, deliveredTimestamp: Int64)
    /// The message sent to other has been read.
    case read(byClientID: String?, messageID: String, readTimestamp: Int64)
}

/// IM Client Delegate
public protocol IMClientDelegate: class {
    
    /// Delegate function of the event about the client.
    /// - Parameters:
    ///   - client: Which the *event* belong to.
    ///   - event: Belong to the *client*, @see `IMClientEvent`.
    func client(_ client: IMClient, event: IMClientEvent)
    
    /// Delegate function of the event about the conversation.
    /// - Parameters:
    ///   - client: Which the *conversation* belong to.
    ///   - conversation: Which the *event* belong to.
    ///   - event: Belong to the *conversation*, @see `IMConversationEvent`.
    func client(_ client: IMClient, conversation: IMConversation, event: IMConversationEvent)
}

// MARK: - Signature

/// IM Signature Delegate
public protocol IMSignatureDelegate: class {
    
    /// Delegate function of the signature action
    ///
    /// - Parameters:
    ///   - client: The signature action belong to.
    ///   - action: @see `IMSignature.Action`.
    ///   - signatureHandler: The handler for the signature.
    func client(_ client: IMClient, action: IMSignature.Action, signatureHandler: @escaping (IMClient, IMSignature?) -> Void)
}

public struct IMSignature {
    
    /// Actions need signature.
    ///
    /// - open: Open client.
    /// - createConversation: Create conversation.
    /// - add: Add members to conversation.
    /// - remove: Remove members from conversation.
    /// - conversationBlocking: Conversation blocking client.
    /// - conversationUnblocking: Conversation unblocking client.
    public enum Action {
        case open
        case createConversation(memberIDs: Set<String>)
        case add(memberIDs: Set<String>, toConversation: IMConversation)
        case remove(memberIDs: Set<String>, fromConversation: IMConversation)
        case conversationBlocking(_: IMConversation, blockedMemberIDs: Set<String>)
        case conversationUnblocking(_: IMConversation, unblockedMemberIDs: Set<String>)
    }
    
    /// signature
    public let signature: String
    
    /// timestamp
    public let timestamp: Int64
    
    /// nonce
    public let nonce: String
    
    /// Initialization.
    ///
    /// - Parameters:
    ///   - signature: signature.
    ///   - timestamp: timestamp.
    ///   - nonce: nonce.
    public init(signature: String, timestamp: Int64, nonce: String) {
        self.signature = signature
        self.timestamp = timestamp
        self.nonce = nonce
    }
}

// MARK: - Error

extension LCError {
    
    static var clientIDInvalid: LCError {
        return LCError(
            code: .inconsistency,
            reason: "Length of client ID should in \(IMClient.lengthRangeOfClientID)")
    }
    
    static var clientUserIDNotFound: LCError {
        return LCError(
            code: .inconsistency,
            reason: "The ID of the user not found")
    }
    
    static var clientTagInvalid: LCError {
        return LCError(
            code: .inconsistency,
            reason: "\"\(IMClient.reservedValueOfTag)\" should not be used on tag")
    }
    
    static var clientLocalStorageNotFound: LCError {
        return LCError(
            code: .inconsistency,
            reason: "Local Storage not found")
    }
}
