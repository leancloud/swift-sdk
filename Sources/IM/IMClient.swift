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

/// IM Client
public final class IMClient {
    
    #if DEBUG
    /// Notification for unit test case
    internal static let TestReportDeviceTokenNotification = Notification.Name.init("TestReportDeviceTokenNotification")
    internal static let TestSessionTokenExpiredNotification = Notification.Name.init("TestSessionTokenExpiredNotification")
    internal let specificKey = DispatchSpecificKey<Int>()
    // whatever random Int is OK.
    internal let specificValue: Int = Int.random(in: 1...999)
    private var specificAssertion: Bool {
        return self.specificValue == DispatchQueue.getSpecific(key: self.specificKey)
    }
    #else
    private var specificAssertion: Bool {
        return true
    }
    #endif
    
    /// length range of client ID.
    public static let lengthRangeOfClientID = 1...64
    
    /// reserved value of tag
    public static let reservedValueOfTag: String = "default"
    
    /// The client identifier.
    public let ID: String
    
    /// The client tag, which represents what kind of session that current client will open.
    /// @related `SessionOpenOptions`
    public let tag: String?
    
    /// The client options.
    public let options: Options
    
    /// The application that the client belongs to.
    public let application: LCApplication
    
    /// Application's current installation
    internal let installation: LCInstallation
    
    /// The delegate object.
    public weak var delegate: IMClientDelegate?
    
    /// The dispatch queue on which the event about IM are called. Default is main.
    public let eventQueue: DispatchQueue
    
    /// The custom server URL.
    public let customServer: URL?
    
    /**
     Client session state.
     */
    public enum SessionState {
        
        /// Session is opened
        case opened
        
        /// Session is resuming
        case resuming
        
        /// Session is paused
        case paused
        
        /// Session is closing
        case closing
        
        /// Session is closed
        case closed
        
    }
    
    /// The client session state.
    public private(set) var sessionState: SessionState {
        set {
            self.mutex.lock()
            self.underlyingSessionState = newValue
            self.mutex.unlock()
        }
        get {
            let value: SessionState
            self.mutex.lock()
            value = self.underlyingSessionState
            self.mutex.unlock()
            return value
        }
    }
    private var underlyingSessionState: SessionState = .closed
    private var isSessionOpened: Bool {
        return self.sessionState == .opened
    }
    
    /**
     Options that can modify behaviors of client.
     */
    public struct Options: OptionSet {
        
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Default options.
        public static let `default`: Options = []
        
        /// Receive unread message count after session did open.
        public static let receiveUnreadMessageCountAfterSessionDidOpen = Options(rawValue: 1 << 0)
        
        /// Get IM protocol for current options.
        var lcimProtocol: RTMConnection.LCIMProtocol {
            if contains(.receiveUnreadMessageCountAfterSessionDidOpen) {
                return .protobuf3
            } else {
                return .protobuf1
            }
        }
        
    }
    
    /// ref: https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md#sdk-登录功能标志位-session-config-bitmap
    private struct SessionConfigs: OptionSet {
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
            .transientMessageACK
        ]
    }
    
    /// Initialize client with identifier and tag.
    ///
    /// - Parameters:
    ///   - ID: The client identifier. Length should in [1...64].
    ///   - tag: The client tag. "default" string should not be used.
    ///   - options: @see `IMClient.Options`.
    ///   - delegate: @see `IMClientDelegate`.
    ///   - eventQueue: @see property `eventQueue`, default is main.
    ///   - timeoutInterval: timeout interval of command.
    ///   - customServer: The custom server URL for private deployment.
    ///   - application: The application that the client belongs to.
    /// - Throws: if `ID` or `tag` invalid, then throw error.
    public init(
        ID: String,
        tag: String? = nil,
        options: Options = .default,
        delegate: IMClientDelegate? = nil,
        eventQueue: DispatchQueue = .main,
        timeoutInterval: TimeInterval = 30.0,
        customServer: URL? = nil,
        application: LCApplication = .default)
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
        self.customServer = customServer
        self.application = application
        self.installation = application.currentInstallation
        // directly init `connection` is better, lazy init is not a good choice.
        // because connection should get App State in main thread.
        self.connection = RTMConnection(
            application: application,
            lcimProtocol: options.lcimProtocol,
            delegateQueue: self.serialQueue,
            commandTTL: timeoutInterval,
            customRTMServerURL: customServer
        )
        self.connection.peerID = ID
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
    }
    
    /// The client serial dispatch queue.
    private let serialQueue = DispatchQueue(label: "LeanCloud.IMClient.serialQueue", qos: .userInitiated)
    
    /// The session connection.
    internal let connection: RTMConnection
    
    /// Internal mutex
    private let mutex = NSLock()
    
    /// Session Token & Opening Config
    internal var sessionToken: String?
    private(set) var sessionTokenExpiration: Date?
    private(set) var openingCompletion: ((LCBooleanResult) -> Void)?
    private(set) var openingOptions: SessionOpenOptions?
    
    /// Device Token and fallback-UDID
    private(set) var deviceTokenObservation: NSKeyValueObservation?
    private(set) var currentDeviceToken: String?
    private(set) lazy var fallbackUDID: String = {
        var udid: String = UUID().uuidString
        #if os(iOS) || os(tvOS)
        if let identifierForVendor: String = UIDevice.current.identifierForVendor?.uuidString {
            udid = identifierForVendor
        }
        #elseif os(macOS)
        let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice") )
        if let serialNumber: String = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String {
            udid = serialNumber
        }
        IOObjectRelease(platformExpert)
        #endif
        return udid
    }()
    
    /// Conversation Container
    /// use it to manage all instance of IMConversation belong to this client
    internal var convCollection: [String: IMConversation] = [:]
    
    /// Single-Conversation Query Callback Container
    /// use it to merge concurrent Single-Conversation Query
    internal var convQueryCallbackCollection: [String: Array<(LCGenericResult<IMConversation>) -> Void>] = [:]
    
    /// ref: https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md#sessionopen
    /// parameter: `lastUnreadNotifTime`, `lastPatchTime`
    private(set) var lastUnreadNotifTime: Int64? = nil
    private(set) var lastPatchTime: Int64? = nil
    
}

// MARK: - Open & Close

extension IMClient {
    
    /**
     Options that can modify behaviors of session open operation.
     */
    public struct SessionOpenOptions: OptionSet {
        
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Default options is forced.
        public static let `default`: SessionOpenOptions = [.forced]
        
        /// For two sessions of one client with same tag, the later one will force to make previous one offline.
        public static let forced = SessionOpenOptions(rawValue: 1 << 0)
        
        /// ref: https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md#sessionopen
        /// parameter: `r` 
        var r: Bool { return !contains(.forced) }
    }
    
    /**
     Open a session to IM system.
     
     - parameter options: @see `IMClient.SessionOpenOptions`.
     - parameter completion: The completion handler.
     */
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
            
            /* Enable auto-reconnection for opening WebSocket connection to send session command. */
            self.connection.delegate = self
            self.connection.connect()
        }
    }
    
    /**
     Close with completion handler.
     
     - parameter completion: The completion handler.
     */
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
            self.connection.send(command: outCommand) { [weak self] (result) in
                guard let self = self else { return }
                assert(self.specificAssertion)
                switch result {
                case .inCommand(let inCommand):
                    if inCommand.cmd == .session, inCommand.op == .closed {
                        self.sessionClosed(with: .success, completion: completion)
                    } else {
                        self.eventQueue.async {
                            let error = LCError(code: .commandInvalid)
                            completion(.failure(error: error))
                        }
                    }
                case .error(let error):
                    self.eventQueue.async {
                        completion(.failure(error: error))
                    }
                }
            }
        }
    }
    
}

// MARK: - Create Conversation

extension IMClient {
    
    /// Create a normal conversation.
    ///
    /// - Parameters:
    ///   - clientIDs: An array of client ID. it's the members of the conversation which will be created. the initialized members always contains this client's ID.
    ///   - name: The name of the conversation
    ///   - attributes: The custom attributes of the conversation
    ///   - isUnique: if true, the created conversation will has a unique ID which is related to members's ID. you can use this parameter to create a new unique conversation or get an exists unique conversation.
    ///     e.g.
    ///     at first, create conversation with members ["a", "b"] and `isUnique` is true
    ///     then, backend will have a new unique conversation which `ID` is 'qweasdzxc'
    ///     after that, create conversation with members ["a", "b"] and `isUnique` is true (same with the firstly)
    ///     finally, you will get the exists unique conversation which `ID` is 'qweasdzxc' and backend will not create new one.
    ///   - completion: callback
    /// - Throws: if `clientIDs`, `name` or `attributes` invalid, then throw error.
    public func createConversation(
        clientIDs: Set<String>,
        name: String? = nil,
        attributes: [String: Any]? = nil,
        isUnique: Bool = false,
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
    
    /// Create a chat room.
    ///
    /// - Parameters:
    ///   - name: The name of the chat room
    ///   - attributes: The custom attributes of the chat room
    ///   - completion: callback
    /// - Throws: if `name` or `attributes` invalid, then throw error.
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
    
    /// Create a temporary conversation.
    /// Temporary conversation is unique in it's Life Cycle.
    ///
    /// - Parameters:
    ///   - clientIDs: An array of client ID. it's the members of the conversation which will be created. the initialized members always contains this client's ID.
    ///   - timeToLive: After time to live, the temporary conversation will be deleted by backend automatically.
    ///   - completion: callback
    /// - Throws: if `clientIDs` invalid, then throw error.
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
    
    private enum ConversationCreationOption {
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
    
    private func createConversation<T: IMConversation>(
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
        }) { (result) in
            switch result {
            case .inCommand(let inCommand):
                guard
                    inCommand.cmd == .conv,
                    inCommand.op == .started,
                    inCommand.hasConvMessage,
                    inCommand.convMessage.hasCid
                    else
                {
                    self.eventQueue.async {
                        let error = LCError(code: .commandInvalid)
                        completion(.failure(error: error))
                    }
                    return
                }
                do {
                    let conversation: T = try self.conversationInstance(
                        convMessage: inCommand.convMessage,
                        members: members,
                        attrJSON: attrJSON,
                        attrString: attrString,
                        option: option,
                        convType: type
                    )
                    self.eventQueue.async {
                        completion(.success(value: conversation))
                    }
                } catch {
                    self.eventQueue.async {
                        let err = LCError(error: error)
                        completion(.failure(error: err))
                    }
                }
            case .error(let error):
                self.eventQueue.async {
                    completion(.failure(error: error))
                }
            }
        }
    }
    
    private func preprocessConversationCreation(
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
    
    private func conversationInstance<T: IMConversation>(
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
                conv.safeChangingRawData(operation: .rawDataMerging(data: json))
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
            }
            if convMessage.hasUniqueID {
                json[IMConversation.Key.uniqueId.rawValue] = convMessage.uniqueID
            }
            if convMessage.hasTempConvTtl {
                json[IMConversation.Key.temporaryTTL.rawValue] = convMessage.tempConvTtl
            }
            if let rawData: IMConversation.RawData = try json.jsonObject() {
                conversation = IMConversation.instance(ID: id, rawData: rawData, client: self)
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

// MARK: - Create Conversation Query

extension IMClient {
    
    /// Create a new conversation query
    public var conversationQuery: IMConversationQuery {
        return IMConversationQuery(client: self, eventQueue: self.eventQueue)
    }
    
}

// MARK: - Internal

extension IMClient {
    
    func sendCommand(
        constructor: () -> IMGenericCommand,
        completion: ((RTMConnection.CommandCallback.Result) -> Void)? = nil)
    {
        let outCommand: IMGenericCommand = constructor()
        guard self.isSessionOpened else {
            let error = LCError(code: .clientNotOpen)
            completion?(.error(error))
            return
        }
        self.connection.send(command: outCommand, callback: completion)
    }
    
}

// MARK: - Private

private extension IMClient {
    
    func newOpenCommand() -> IMGenericCommand {
        assert(self.specificAssertion)
        var outCommand = IMGenericCommand()
        outCommand.cmd = .session
        outCommand.op = .open
        outCommand.appID = self.application.id
        outCommand.peerID = self.ID
        var sessionCommand = IMSessionCommand()
        sessionCommand.configBitmap = SessionConfigs.support.rawValue
        sessionCommand.deviceToken = self.currentDeviceToken ?? self.fallbackUDID
        sessionCommand.ua = HTTPClient.default.configuration.userAgent
        if let tag: String = self.tag {
            sessionCommand.tag = tag
        }
        if let lastUnreadNotifTime: Int64 = self.lastUnreadNotifTime {
            sessionCommand.lastUnreadNotifTime = lastUnreadNotifTime
        }
        if let lastPatchTime: Int64 = self.lastPatchTime {
            sessionCommand.lastPatchTime = lastPatchTime
        }
        outCommand.sessionMessage = sessionCommand
        return outCommand
    }
    
    func send(reopenCommand command: IMGenericCommand) {
        assert(self.specificAssertion)
        self.connection.send(command: command) { [weak self] (result) in
            guard let self = self else { return }
            assert(self.specificAssertion)
            switch result {
            case .inCommand(let inCommand):
                self.handle(openCommandCallback: inCommand)
            case .error(let error):
                if error.code == LCError.InternalErrorCode.commandTimeout.rawValue {
                    self.send(reopenCommand: command)
                } else if error.code == LCError.ServerErrorCode.sessionTokenExpired.rawValue {
                    #if DEBUG
                    NotificationCenter.default.post(
                        name: IMClient.TestSessionTokenExpiredNotification,
                        object: self,
                        userInfo: ["error": error]
                    )
                    #endif
                    var openCommand = self.newOpenCommand()
                    openCommand.sessionMessage.r = true
                    self.send(reopenCommand: openCommand)
                } else {
                    Logger.shared.debug(error)
                }
            }
        }
    }
    
    func report(deviceToken token: String?, openCommand: IMGenericCommand? = nil) {
        assert(self.specificAssertion)
        guard let token: String = token, self.isSessionOpened else {
            return
        }
        if let openCommand = openCommand {
            // if Device-Token changed in Opening-Period, reporting after open success.
            guard openCommand.sessionMessage.deviceToken != token else {
                return
            }
        }
        var outCommand = IMGenericCommand()
        outCommand.cmd = .report
        outCommand.op = .upload
        var reportCommand = IMReportCommand()
        reportCommand.initiative = true
        reportCommand.type = "token"
        reportCommand.data = token
        outCommand.reportMessage = reportCommand
        self.connection.send(command: outCommand) { result in
            #if DEBUG
            /// for unit test
            NotificationCenter.default.post(
                name: IMClient.TestReportDeviceTokenNotification,
                object: self,
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
            if let _ = completion {
                self.connection.setAutoReconnectionEnabled(true)
            }
            self.sessionState = .opened
            self.eventQueue.async {
                if let completion = completion {
                    completion(.success)
                } else {
                    self.delegate?.client(self, event: .sessionDidOpen)
                }
            }
        case (.session, .closed):
            let sessionMessage = command.sessionMessage
            self.process(sessionClosedCommand: sessionMessage, completion: completion)
        default:
            let error = LCError(code: .commandInvalid)
            self.sessionClosed(with: .failure(error: error), completion: completion)
        }
    }
    
    func sessionClosed(with result: LCBooleanResult, completion: ((LCBooleanResult) -> Void)? = nil) {
        assert(self.specificAssertion)
        self.connection.delegate = nil
        self.connection.setAutoReconnectionEnabled(false)
        self.connection.disconnect()
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
    
    func process(sessionClosedCommand sessionCommand: IMSessionCommand, completion: ((LCBooleanResult) -> Void)? = nil) {
        assert(self.specificAssertion)
        let code: Int = Int(sessionCommand.code)
        let reason: String? = (sessionCommand.hasReason ? sessionCommand.reason : nil)
        var userInfo: LCError.UserInfo? = [:]
        if sessionCommand.hasDetail { userInfo?["detail"] = sessionCommand.detail }
        do {
            userInfo = try userInfo?.jsonObject()
        } catch {
            Logger.shared.error(error)
        }
        let error = LCError(code: code, reason: reason, userInfo: userInfo)
        self.sessionClosed(with: .failure(error: error), completion: completion)
    }
    
    func getConversation(by ID: String, completion: @escaping (LCGenericResult<IMConversation>) -> Void) {
        assert(self.specificAssertion)
        if let existConversation: IMConversation = self.convCollection[ID] {
            completion(.success(value: existConversation))
            return
        }
        if var callbacks: Array<(LCGenericResult<IMConversation>) -> Void> = self.convQueryCallbackCollection[ID] {
            callbacks.append(completion)
            self.convQueryCallbackCollection[ID] = callbacks
            return
        } else {
            self.convQueryCallbackCollection[ID] = [completion]
        }
        let callback: (LCGenericResult<IMConversation>) -> Void = { result in
            guard let callbacks = self.convQueryCallbackCollection.removeValue(forKey: ID) else {
                return
            }
            for closure in callbacks {
                closure(result)
            }
        }
        /// for internal, no need to set event queue.
        let query = IMConversationQuery(client: self)
        do {
            if ID.hasPrefix(IMTemporaryConversation.prefixOfID) {
                try query.getTemporaryConversations(by: [ID], completion: { (result) in
                    assert(self.specificAssertion)
                    switch result {
                    case .success(value: let conversations):
                        if let first: IMConversation = conversations.first {
                            callback(.success(value: first))
                        } else {
                            callback(.failure(error: LCError(code: .conversationNotFound)))
                        }
                    case .failure(error: let error):
                        callback(.failure(error: error))
                    }
                })
            } else {
                try query.getConversation(by: ID, completion: { (result) in
                    assert(self.specificAssertion)
                    callback(result)
                })
            }
        } catch {
            assert(self.specificAssertion)
            callback(.failure(error: LCError(error: error)))
        }
    }
    
    func getConversations(by IDs: Set<String>, completion: @escaping (LCGenericResult<[IMConversation]>) -> Void) {
        assert(self.specificAssertion)
        if IDs.count == 1, let ID: String = IDs.first {
            self.getConversation(by: ID) { (result) in
                assert(self.specificAssertion)
                switch result {
                case .success(value: let conversation):
                    completion(.success(value: [conversation]))
                case .failure(error: let error):
                    completion(.failure(error: error))
                }
            }
        } else {
            /// for internal, no need to set event queue.
            let query = IMConversationQuery(client: self)
            do {
                try query.getConversations(by: IDs, completion: { (result) in
                    assert(self.specificAssertion)
                    completion(result)
                })
            } catch {
                assert(self.specificAssertion)
                completion(.failure(error: LCError(error: error)))
            }
        }
    }
    
    func getTemporaryConversations(by IDs: Set<String>, completion: @escaping (LCGenericResult<[IMConversation]>) -> Void) {
        assert(self.specificAssertion)
        if IDs.count == 1, let ID: String = IDs.first {
            self.getConversation(by: ID) { (result) in
                assert(self.specificAssertion)
                switch result {
                case .success(value: let conversation):
                    completion(.success(value: [conversation]))
                case .failure(error: let error):
                    completion(.failure(error: error))
                }
            }
        } else {
            /// for internal, no need to set event queue.
            let query = IMConversationQuery(client: self)
            do {
                try query.getTemporaryConversations(by: IDs, completion: { (result) in
                    assert(self.specificAssertion)
                    switch result {
                    case .success(value: let conversations):
                        completion(.success(value: conversations))
                    case .failure(error: let error):
                        completion(.failure(error: error))
                    }
                })
            } catch {
                assert(self.specificAssertion)
                completion(.failure(error: LCError(error: error)))
            }
        }
    }
    
    func process(convCommand command: IMConvCommand, op: IMOpType) {
        assert(self.specificAssertion)
        guard let conversationID: String = (command.hasCid ? command.cid : nil) else {
            return
        }
        self.getConversation(by: conversationID) { (result) in
            assert(self.specificAssertion)
            switch result {
            case .success(value: let conversation):
                let byClientID: String? = (command.hasInitBy ? command.initBy : nil)
                let members: Set<String> = Set<String>(command.m)
                let event: IMConversationEvent
                let rawDataOperation: IMConversation.RawDataChangeOperation
                switch op {
                case .joined:
                    event = .joined(byClientID: byClientID)
                    rawDataOperation = .append(members: [self.ID])
                case .left:
                    event = .left(byClientID: byClientID)
                    rawDataOperation = .remove(members: [self.ID])
                case .membersJoined:
                    event = .membersJoined(tuple: (members, byClientID))
                    rawDataOperation = .append(members: members)
                case .membersLeft:
                    event = .membersLeft(tuple: (members, byClientID))
                    rawDataOperation = .remove(members: members)
                default:
                    return
                }
                conversation.safeChangingRawData(operation: rawDataOperation)
                self.eventQueue.async {
                    self.delegate?.client(self, conversation: conversation, event: event)
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
             of course there is a very little probability that multiple messageID is same in the unread-message-queue,
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
        self.getConversation(by: conversationID) { (result) in
            assert(self.specificAssertion)
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
                    isTransient: (command.hasTransient ? command.transient : false),
                    conversationID: conversationID,
                    localClientID: self.ID,
                    fromClientID: (command.hasFromPeerID ? command.fromPeerID : nil),
                    timestamp: timestamp,
                    patchedTimestamp: (command.hasPatchTimestamp ? command.patchTimestamp : nil),
                    messageID: messageID,
                    content: content,
                    isAllMembersMentioned: (command.hasMentionAll ? command.mentionAll : nil),
                    mentionedMembers: (command.mentionPids.isEmpty ? nil : command.mentionPids),
                    status: .sent
                )
                var unreadEvent: IMConversationEvent?
                let isUnreadMessageIncreased: Bool = conversation.safeUpdatingLastMessage(newMessage: message)
                if self.options.contains(.receiveUnreadMessageCountAfterSessionDidOpen),
                    isUnreadMessageIncreased {
                    conversation.unreadMessageCount += 1
                    unreadEvent = .unreadMessageUpdated
                }
                self.eventQueue.async {
                    if let unreadUpdatedEvent = unreadEvent {
                        self.delegate?.client(self, conversation: conversation, event: unreadUpdatedEvent)
                    }
                    self.delegate?.client(self, conversation: conversation, event: .message(event: .received(message: message)))
                    self.serialQueue.async {
                        self.acknowledging(message: message, conversation: conversation)
                    }
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
                existingConversation.process(unreadTuple: unreadTuple)
            } else {
                if conversationID.hasPrefix(IMTemporaryConversation.prefixOfID) {
                    temporaryConversationIDMap[conversationID] = unreadTuple
                } else {
                    conversationIDMap[conversationID] = unreadTuple
                }
            }
        }
        let updateLastUnreadNotifTime: () -> Void = {
            if self.options.contains(.receiveUnreadMessageCountAfterSessionDidOpen),
                unreadCommand.hasNotifTime {
                if let oldTime: Int64 = self.lastUnreadNotifTime {
                    if unreadCommand.notifTime > oldTime {
                        self.lastUnreadNotifTime = unreadCommand.notifTime
                    }
                } else {
                    self.lastUnreadNotifTime = unreadCommand.notifTime
                }
            }
        }
        if conversationIDMap.isEmpty, temporaryConversationIDMap.isEmpty {
            updateLastUnreadNotifTime()
        } else {
            let group = DispatchGroup()
            var groupFlags: [Bool] = []
            let handleResult: (LCGenericResult<[IMConversation]>, [String: IMUnreadTuple]) -> Void = { (result, map) in
                switch result {
                case .success(value: let conversations):
                    groupFlags.append(true)
                    for conversation in conversations {
                        if let unreadTuple: IMUnreadTuple = map[conversation.ID] {
                            conversation.process(unreadTuple: unreadTuple)
                        }
                    }
                case .failure(error: let error):
                    groupFlags.append(false)
                    Logger.shared.error(error)
                }
            }
            if !conversationIDMap.isEmpty {
                group.enter()
                let IDs = Set<String>(conversationIDMap.keys)
                self.getConversations(by: IDs) { (result) in
                    assert(self.specificAssertion)
                    handleResult(result, conversationIDMap)
                    group.leave()
                }
            }
            if !temporaryConversationIDMap.isEmpty {
                group.enter()
                let IDs = Set<String>(temporaryConversationIDMap.keys)
                self.getTemporaryConversations(by: IDs) { (result) in
                    assert(self.specificAssertion)
                    handleResult(result, temporaryConversationIDMap)
                    group.leave()
                }
            }
            group.notify(queue: self.serialQueue) {
                guard !groupFlags.contains(false) else {
                    return
                }
                updateLastUnreadNotifTime()
            }
        }
    }
    
    func process(patchCommand: IMPatchCommand) {
        assert(self.specificAssertion)
        var lastPatchTimestamp: Int64 = -1
        var conversationIDMap: [String: IMPatchItem] = [:]
        var temporaryConversationIDMap: [String: IMPatchItem] = [:]
        for item in patchCommand.patches {
            guard let conversationID: String = (item.hasCid ? item.cid : nil) else {
                continue
            }
            if item.hasPatchTimestamp,
                item.patchTimestamp > lastPatchTimestamp {
                lastPatchTimestamp = item.patchTimestamp
            }
            if let existingConversation = self.convCollection[conversationID] {
                existingConversation.process(patchItem: item)
            } else {
                if conversationID.hasPrefix(IMTemporaryConversation.prefixOfID) {
                    temporaryConversationIDMap[conversationID] = item
                } else {
                    conversationIDMap[conversationID] = item
                }
            }
        }
        let updateLastPatchTime: () -> Void = {
            if self.options.contains(.receiveUnreadMessageCountAfterSessionDidOpen),
                lastPatchTimestamp > 0 {
                if let oldTime = self.lastPatchTime {
                    if lastPatchTimestamp > oldTime {
                        self.lastPatchTime = lastPatchTimestamp
                    }
                } else {
                    self.lastPatchTime = lastPatchTimestamp
                }
            }
        }
        if conversationIDMap.isEmpty, temporaryConversationIDMap.isEmpty {
            updateLastPatchTime()
        } else {
            let group = DispatchGroup()
            var groupFlags: [Bool] = []
            let handleResult: (LCGenericResult<[IMConversation]>, [String: IMPatchItem]) -> Void = { (result, map) in
                switch result {
                case .success(value: let conversations):
                    groupFlags.append(true)
                    for conversation in conversations {
                        if let patchItem: IMPatchItem = map[conversation.ID] {
                            conversation.process(patchItem: patchItem)
                        }
                    }
                case .failure(error: let error):
                    groupFlags.append(false)
                    Logger.shared.error(error)
                }
            }
            if !conversationIDMap.isEmpty {
                group.enter()
                let IDs = Set<String>(conversationIDMap.keys)
                self.getConversations(by: IDs) { (result) in
                    assert(self.specificAssertion)
                    handleResult(result, conversationIDMap)
                    group.leave()
                }
            }
            if !temporaryConversationIDMap.isEmpty {
                group.enter()
                let IDs = Set<String>(temporaryConversationIDMap.keys)
                self.getTemporaryConversations(by: IDs) { (result) in
                    assert(self.specificAssertion)
                    handleResult(result, temporaryConversationIDMap)
                    group.leave()
                }
            }
            group.notify(queue: self.serialQueue) {
                guard !groupFlags.contains(false) else {
                    return
                }
                updateLastPatchTime()
            }
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
        var openCommand = self.newOpenCommand()
        if let openingCompletion = self.openingCompletion,
            let openingOptions = self.openingOptions
        {
            openCommand.sessionMessage.r = openingOptions.r
            self.connection.send(command: openCommand) { [weak self] (result) in
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
        }
        else if let sessionToken = self.sessionToken
        {
            openCommand.sessionMessage.r = true
            openCommand.sessionMessage.st = sessionToken
            self.send(reopenCommand: openCommand)
        }
    }
    
    func connection(_ connection: RTMConnection, didDisconnect error: LCError) {
        assert(self.specificAssertion)
        let routerError = LCError.malformedRTMRouterResponse
        if error.code == routerError.code, error.reason == routerError.reason {
            self.sessionClosed(with: .failure(error: error), completion: self.openingCompletion)
        } else if let openingCompletion = self.openingCompletion {
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
        switch inCommand.cmd {
        case .session:
            switch inCommand.op {
            case .closed:
                self.process(sessionClosedCommand: inCommand.sessionMessage)
            default:
                break
            }
        case .direct:
            self.process(directCommand: inCommand.directMessage)
        case .unread:
            self.process(unreadCommand: inCommand.unreadMessage)
        case .conv:
            self.process(convCommand: inCommand.convMessage, op: inCommand.op)
        case .patch:
            switch inCommand.op {
            case .modify:
                self.process(patchCommand: inCommand.patchMessage)
            default:
                break
            }
        default:
            break
        }
    }
    
}

public enum IMClientEvent {
    
    case sessionDidOpen
    
    case sessionDidResume
    
    case sessionDidPause(error: LCError)
    
    case sessionDidClose(error: LCError)
    
}

public enum IMConversationEvent {
    
    case joined(byClientID: String?)
    
    case left(byClientID: String?)
    
    case membersJoined(tuple: (members: Set<String>, byClientID: String?))
    
    case membersLeft(tuple: (members: Set<String>, byClientID: String?))
    
    case dataUpdated
    
    case lastMessageUpdated
    
    case unreadMessageUpdated
    
    case message(event: IMMessageEvent)
    
}

public enum IMMessageEvent {
    
    case received(message: IMMessage)
    
    case updated(updatedMessage: IMMessage)
    
}

public protocol IMClientDelegate: class {
    
    /// Notification of the event about the client.
    ///
    /// - Parameters:
    ///   - client: Which the event belong to.
    ///   - event: @see `IMClientEvent`
    func client(_ client: IMClient, event: IMClientEvent)
    
    /// Notification of the event about the conversation.
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
    
}
