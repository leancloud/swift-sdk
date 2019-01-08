//
//  Client.swift
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
public final class LCClient {
    
    #if DEBUG
    /// for unit test
    internal static let TestReportDeviceTokenNotification = Notification.Name.init("TestReportDeviceTokenNotification")
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
    public weak var delegate: LCClientDelegate?
    
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
        var lcimProtocol: Connection.LCIMProtocol {
            if contains(.receiveUnreadMessageCountAfterSessionDidOpen) {
                return .protobuf3
            } else {
                return .protobuf1
            }
        }
        
    }
    
    /// Initialize client with identifier and tag.
    ///
    /// - Parameters:
    ///   - ID: The client identifier. Length should in [1...64].
    ///   - tag: The client tag. "default" string should not be used.
    ///   - options: @see `LCClient.Options`.
    ///   - delegate: @see `LCClientDelegate`.
    ///   - eventQueue: @see property `eventQueue`, default is main.
    ///   - timeoutInterval: timeout interval of command.
    ///   - customServer: The custom server URL for private deployment.
    ///   - application: The application that the client belongs to.
    /// - Throws: if `ID` or `tag` invalid, then throw error.
    public init(
        ID: String,
        tag: String? = nil,
        options: Options = .default,
        delegate: LCClientDelegate? = nil,
        eventQueue: DispatchQueue = .main,
        timeoutInterval: TimeInterval = 30.0,
        customServer: URL? = nil,
        application: LCApplication = .default)
        throws
    {
        guard LCClient.lengthRangeOfClientID.contains(ID.count) else {
            throw LCError.invalidClientIDError
        }
        guard tag != LCClient.reservedValueOfTag else {
            throw LCError.invalidClientTagError
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
        self.connection = Connection(
            application: application,
            lcimProtocol: options.lcimProtocol,
            delegateQueue: self.serialQueue,
            commandTTL: timeoutInterval,
            customRTMServerURL: customServer
        )
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
    private let serialQueue = DispatchQueue(label: "LeanCloud.LCClient.serialQueue", qos: .userInitiated)
    
    /// The session connection.
    private let connection: Connection
    
    /// Internal mutex
    private let mutex = NSLock()
    
    /// Session Token & Opening Config
    private var sessionToken: String?
    private var sessionTokenExpiration: Date?
    private var openingCompletion: ((LCBooleanResult) -> Void)?
    private var openingOptions: SessionOpenOptions?
    
    /// Device Token and fallback-UDID
    private var deviceTokenObservation: NSKeyValueObservation?
    private var currentDeviceToken: String?
    private lazy var fallbackUDID: String = {
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
    private var convCollection: [String: LCConversation] = [:]
    
}

// MARK: - Open & Close

extension LCClient {
    
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
        
        var r: Bool { return !contains(.forced) }
    }
    
    /**
     Open a session to IM system.
     
     - parameter options: @see `LCClient.SessionOpenOptions`.
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
                var error: LCError
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
                guard let self = self else {
                    return
                }
                switch result {
                case .inCommand(let inCommand):
                    if inCommand.check(type: .session, op: .closed) {
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

extension LCClient {
    
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
        completion: @escaping (LCGenericResult<LCConversation>) -> Void)
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
        completion: @escaping (LCGenericResult<LCChatRoom>) -> Void)
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
    ///
    /// - Parameters:
    ///   - clientIDs: An array of client ID. it's the members of the conversation which will be created. the initialized members always contains this client's ID.
    ///   - timeToLive: After time to live, the temporary conversation will be deleted by backend automatically.
    ///   - completion: callback
    /// - Throws: if `clientIDs` invalid, then throw error.
    public func createTemporaryConversation(
        clientIDs: Set<String>,
        timeToLive: Int32,
        completion: @escaping (LCGenericResult<LCTemporaryConversation>) -> Void)
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
    }
    
    private func createConversation<T: LCConversation>(
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
            attributes: attributes
        )
        let members: [String] = tuple.members
        let attrJSON: [String: Any] = tuple.attrJSON
        let attrString: String? = tuple.attrString
        
        var type: LCConversation.LCType = .normal
        
        self.sendCommand(constructor: { () -> IMGenericCommand in
            var outCommand = IMGenericCommand()
            outCommand.cmd = .conv
            outCommand.op = .start
            var convMessage = IMConvCommand()
            convMessage.m = members
            switch option {
            case .normal: break
            case .normalAndUnique: convMessage.unique = true
            case .transient:
                convMessage.transient = true
                type = .transient
            case .temporary(ttl: let ttl):
                convMessage.tempConv = true
                if ttl > 0 {
                    convMessage.tempConvTtl = ttl
                }
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
                guard inCommand.cmd == .conv,
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
                        type: type
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
        attributes: [String: Any]?)
        throws -> (members: [String], attrJSON: [String: Any], attrString: String?)
    {
        for item in clientIDs {
            guard LCClient.lengthRangeOfClientID.contains(item.count) else {
                throw LCError.invalidClientIDError
            }
        }
        
        var members: [String] = Array<String>(clientIDs)
        if !clientIDs.contains(self.ID) {
            members.append(self.ID)
        }
        
        var attrJSON: [String: Any] = [:]
        if let name: String = name {
            attrJSON[LCConversation.Key.name.rawValue] = name
        }
        if let attributes: [String: Any] = attributes {
            attrJSON[LCConversation.Key.attributes.rawValue] = attributes
        }
        var attrString: String? = nil
        if !attrJSON.isEmpty {
            let data = try JSONSerialization.data(withJSONObject: attrJSON, options: [])
            attrString = String(data: data, encoding: .utf8)
        }
        
        return (members, attrJSON, attrString)
    }
    
    private func conversationInstance<T: LCConversation>(
        convMessage: IMConvCommand,
        members: [String],
        attrJSON: [String: Any],
        attrString: String?,
        option: ConversationCreationOption,
        type: LCConversation.LCType)
        throws -> T
    {
        /*
         @Note: Why use JSONSerialization encoding and decoding `[String: Any]` ?
         
         because a `[String: Any]` is Strict-Type-Checking,
         e.g.
         let dic: [String: Any] = ["foo": Int32(1)]
         (dic["foo"] as? Int) == nil
         (dic["foo"] as? Int32) == 1
         so use JSONSerialization to convert `dic` to JSON Object: `json`,
         then (json["foo"] as? Int) == 1 && (json["foo"] as? Int32) == 1
         
         This will make data better for SDK to handle it.
         */
        
        assert(self.specificAssertion)
        let id: String = convMessage.cid
        let conversation: LCConversation
        if let conv: LCConversation = self.convCollection[id] {
            if let attr: String = attrString {
                let json: [String: Any]? = try attr.json()
                conv.safeUpdatingRawData(merging: json)
            }
            conversation = conv
        } else {
            var json: [String: Any] = attrJSON
            json[LCConversation.Key.convType.rawValue] = type.rawValue
            json[LCConversation.Key.members.rawValue] = members
            json[LCConversation.Key.creator.rawValue] = self.ID
            if option.isUnique {
                json[LCConversation.Key.unique.rawValue] = true
            }
            if convMessage.hasCdate {
                json[LCConversation.Key.createdAt.rawValue] = convMessage.cdate
            }
            if convMessage.hasUniqueID {
                json[LCConversation.Key.uniqueId.rawValue] = convMessage.uniqueID
            }
            if convMessage.hasTempConvTtl {
                json[LCConversation.Key.temporaryTTL.rawValue] = convMessage.tempConvTtl
            }
            let data: Data = try JSONSerialization.data(withJSONObject: json)
            if let rawData = try JSONSerialization.jsonObject(with: data) as? LCConversation.RawData {
                conversation = LCConversation.instance(ID: id, rawData: rawData, client: self)
            } else {
                throw LCError(code: .malformedData)
            }
        }
        if let conversation = conversation as? T {
            return conversation
        } else {
            throw LCError(
                code: .inconsistency,
                reason: "Conversation Type invalid."
            )
        }
    }
    
}

// MARK: - Internal

extension LCClient {
    
    func sendCommand(
        constructor: () -> IMGenericCommand,
        completion: ((Connection.CommandCallback.Result) -> Void)? = nil)
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

private extension LCClient {
    
    private func newOpenCommand() -> IMGenericCommand {
        assert(self.specificAssertion)
        var outCommand = IMGenericCommand()
        outCommand.cmd = .session
        outCommand.op = .open
        outCommand.appID = self.application.id
        outCommand.peerID = self.ID
        var sessionCommand = IMSessionCommand()
        sessionCommand.deviceToken = self.currentDeviceToken ?? self.fallbackUDID
        sessionCommand.ua = HTTPClient.default.configuration.userAgent
        if let tag: String = self.tag {
            sessionCommand.tag = tag
        }
        outCommand.sessionMessage = sessionCommand
        return outCommand
    }
    
    private func send(reopenCommand command: IMGenericCommand) {
        assert(self.specificAssertion)
        self.connection.send(command: command) { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .inCommand(let inCommand):
                self.handle(openCommandCallback: inCommand)
            case .error(let error):
                if error.code == LCError.InternalErrorCode.commandTimeout.rawValue {
                    self.send(reopenCommand: command)
                } else if error.code == LCError.ServerErrorCode.sessionTokenExpired.rawValue {
                    var openCommand = self.newOpenCommand()
                    openCommand.sessionMessage.r = true
                    self.send(reopenCommand: openCommand)
                } else {
                    Logger.shared.debug(error)
                }
            }
        }
    }
    
    private func report(deviceToken token: String?, openCommand: IMGenericCommand? = nil) {
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
                name: LCClient.TestReportDeviceTokenNotification,
                object: self,
                userInfo: ["result" : result]
            )
            #endif
        }
    }
    
    private func handle(openCommandCallback command: IMGenericCommand, completion: ((LCBooleanResult) -> Void)? = nil) {
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
                    self.delegate?.client(didOpenSession: self)
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
    
    private func sessionClosed(with result: LCBooleanResult, completion: ((LCBooleanResult) -> Void)? = nil) {
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
                self.delegate?.client(self, didCloseSession: error)
            }
        }
    }
    
    private func process(sessionClosedCommand sessionCommand: IMSessionCommand, completion: ((LCBooleanResult) -> Void)? = nil) {
        assert(self.specificAssertion)
        let code: Int = Int(sessionCommand.code)
        let reason: String? = (sessionCommand.hasReason ? sessionCommand.reason : nil)
        let userInfo: LCError.UserInfo? = (sessionCommand.hasDetail ? ["detail" : sessionCommand.detail] : nil)
        let error = LCError(code: code, reason: reason, userInfo: userInfo)
        self.sessionClosed(with: .failure(error: error), completion: completion)
    }
    
}

// MARK: - Connection Delegate

extension LCClient: ConnectionDelegate {
    
    func connection(inConnecting connection: Connection) {
        assert(self.specificAssertion)
        guard let _ = self.sessionToken, self.sessionState != .resuming else {
            return
        }
        self.sessionState = .resuming
        self.eventQueue.async {
            self.delegate?.client(didBecomeResumeSession: self)
        }
    }
    
    func connection(didConnect connection: Connection) {
        assert(self.specificAssertion)
        var openCommand = self.newOpenCommand()
        if let openingCompletion = self.openingCompletion,
            let openingOptions = self.openingOptions
        {
            openCommand.sessionMessage.r = openingOptions.r
            self.connection.send(command: openCommand) { [weak self] (result) in
                guard let self = self else { return }
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
    
    func connection(_ connection: Connection, didDisconnect error: LCError) {
        assert(self.specificAssertion)
        let routerError = LCError.malformedRTMRouterResponse
        if error.code == routerError.code, error.reason == routerError.reason {
            self.sessionClosed(with: .failure(error: error), completion: self.openingCompletion)
        } else if let openingCompletion = self.openingCompletion {
            self.sessionClosed(with: .failure(error: error), completion: openingCompletion)
        } else if let _ = self.sessionToken, self.sessionState != .paused {
            self.sessionState = .paused
            self.eventQueue.async {
                self.delegate?.client(self, didPauseSession: error)
            }
        }
    }
    
    func connection(_ connection: Connection, didReceiveCommand inCommand: IMGenericCommand) {
        assert(self.specificAssertion)
        switch inCommand.cmd {
        case .session:
            switch inCommand.op {
            case .closed:
                self.process(sessionClosedCommand: inCommand.sessionMessage)
            default:
                break
            }
        default:
            break
        }
    }
    
}

public protocol LCClientDelegate: class {
    
    /**
     Notify that client did open session.
     
     - parameter client: The client who did open session.
     */
    func client(didOpenSession client: LCClient)
    
    /**
     Notify that client did become resume session.
     
     - parameter client: The client who did become resume session.
     */
    func client(didBecomeResumeSession client: LCClient)
    
    /**
     Notify that client did pause session.
     
     - parameter client: The client who did close session.
     - parameter error: Reason of pause.
     */
    func client(_ client: LCClient, didPauseSession error: LCError)
    
    /**
     Notify that client did close session.
     
     - parameter client: The client who did close session.
     - parameter error: Reason of close.
     */
    func client(_ client: LCClient, didCloseSession error: LCError)
    
}

extension LCClientDelegate {
    
    func client(didOpenSession client: LCClient) {
        /* Nop */
    }
    
    func client(didBecomeResumeSession client: LCClient) {
        /* Nop */
    }
    
    func client(_ client: LCClient, didPauseSession error: LCError) {
        /* Nop */
    }
    
    func client(_ client: LCClient, didCloseSession error: LCError) {
        /* Nop */
    }
    
}

extension LCError {
    
    static let invalidClientIDError: LCError = LCError(
        code: .inconsistency,
        reason: "Length of client ID should in \(LCClient.lengthRangeOfClientID)"
    )
    
    static let invalidClientTagError: LCError = LCError(
        code: .inconsistency,
        reason: "\"\(LCClient.reservedValueOfTag)\" string should not be used on tag"
    )
    
}
