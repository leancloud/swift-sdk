//
//  Application.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/8/28.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/// LeanCloud Application.
///
/// an `LCApplication` object is an abstraction of LeanCloud application,
/// it is the context of application-specific settings and objects.
public class LCApplication {
    
    // MARK: Registry
    
    static var registry: [String: LCApplication] = [:]
    
    // MARK: Log
    
    public enum LogLevel: Int, Comparable {
        case off
        case error
        case debug
        case verbose
        case all

        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Console log level, default is `LogLevel.off`.
    public static var logLevel: LogLevel = .off
    
    // MARK: Basic
    
    /// Default application.
    public static let `default` = LCApplication()
    
    public typealias Identifier = String

    /// Application ID.
    public private(set) var id: LCApplication.Identifier!

    /// Application key.
    public private(set) var key: String!
    
    /// Application server URL string.
    public private(set) var serverURL: String?
    
    // MARK: Configuration
    
    /// Module of customizable server.
    public enum ServerCustomizableModule {
        case api(_ url: String)
        case push(_ url: String)
        case engine(_ url: String)
        case rtm(_ url: String)
        
        var values: (AppRouter.Module, String) {
            switch self {
            case let .api(url):
                return (.api, url)
            case let .engine(url):
                return (.engine, url)
            case let .push(url):
                return (.push, url)
            case let .rtm(url):
                return (.rtm, url)
            }
        }
    }
    
    /// Environment of the application.
    public struct Environment: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Development environment of Cloud Engine Service.
        public static let cloudEngineDevelopment = Environment(rawValue: 1 << 0)
        
        /// Development environment of Push Service.
        public static let pushDevelopment = Environment(rawValue: 1 << 1)
        
        /// Default is production environment.
        public static let `default`: Environment = []
    }
    
    var cloudEngineMode: String {
        return self.configuration.environment
            .contains(.cloudEngineDevelopment)
            ? "0" : "1"
    }
    
    var pushMode: String {
        return self.configuration.environment
            .contains(.pushDevelopment)
            ? "dev" : "prod"
    }
    
    /// Configuration of the application.
    public struct Configuration: CustomDebugStringConvertible {
        public static let `default` = Configuration()
        
        /// Customized Servers, default is `[]`.
        public var customizedServers: [ServerCustomizableModule]
        
        /// Environment, default is `Environment.default`.
        public var environment: Environment
        
        /// HTTP Request Timeout Interval, default is `60.0` second.
        public var HTTPRequestTimeoutInterval: TimeInterval
        
        /// URL Cache for HTTP Response, default is `nil`.
        public var HTTPURLCache: URLCache?
        
        /// RTM Connecting Timeout Interval, default is `60.0` second.
        public var RTMConnectingTimeoutInterval: TimeInterval
        
        /// RTM Command Timeout Interval, default is `30.0` second.
        public var RTMCommandTimeoutInterval: TimeInterval
        
        /// RTM Custom Server URL, default is `nil`.
        public var RTMCustomServerURL: URL?
        
        public init(
            customizedServers: [ServerCustomizableModule] = [],
            environment: Environment = .default,
            HTTPRequestTimeoutInterval: TimeInterval = 60.0,
            HTTPURLCache: URLCache? = nil,
            RTMConnectingTimeoutInterval: TimeInterval = 60.0,
            RTMCommandTimeoutInterval: TimeInterval = 30.0,
            RTMCustomServerURL: URL? = nil)
        {
            self.customizedServers = customizedServers
            self.environment = environment
            self.HTTPRequestTimeoutInterval = HTTPRequestTimeoutInterval
            self.HTTPURLCache = HTTPURLCache
            self.RTMConnectingTimeoutInterval = RTMConnectingTimeoutInterval
            self.RTMCommandTimeoutInterval = RTMCommandTimeoutInterval
            self.RTMCustomServerURL = RTMCustomServerURL
        }
        
        public var debugDescription: String {
            var customizedServersDebugDescription: String
            if self.customizedServers.isEmpty {
                customizedServersDebugDescription = "[]"
            } else {
                customizedServersDebugDescription = "\n"
                for (index, item) in self.customizedServers.enumerated() {
                    if index == self.customizedServers.count - 1 {
                        customizedServersDebugDescription += "\t\t\(item)"
                    } else {
                        customizedServersDebugDescription += "\t\t\(item)\n"
                    }
                }
            }
            return """
            \tcustomizedServers: \(customizedServersDebugDescription)
            \tenvironment: \(self.environment)
            \tHTTPRequestTimeoutInterval: \(self.HTTPRequestTimeoutInterval) seconds
            \tHTTPURLCache: \(self.HTTPURLCache?.debugDescription ?? "nil")
            \tRTMConnectingTimeoutInterval: \(self.RTMConnectingTimeoutInterval) seconds
            \tRTMCommandTimeoutInterval: \(self.RTMCommandTimeoutInterval) seconds
            \tRTMCustomServerURL: \(self.RTMCustomServerURL?.absoluteString ?? "nil")
            """
        }
    }
    
    /// Application configuration.
    public private(set) var configuration: Configuration = .default
    
    // MARK: Region
    
    enum Region {
        case cn
        case ce
        case us

        enum Suffix: String {
            case cn = "-gzGzoHsz"
            case ce = "-9Nh9j0Va"
            case us = "-MdYXbMMI"
        }

        init(id: String) {
            if id.hasSuffix(Suffix.cn.rawValue) {
                self = .cn
            } else if id.hasSuffix(Suffix.ce.rawValue) {
                self = .ce
            } else if id.hasSuffix(Suffix.us.rawValue) {
                self = .us
            } else {
                /* Old application of cn region may have no suffix. */
                self = .cn
            }
        }

        var domain: String {
            switch self {
            case .cn:
                return "lncld.net"
            case .ce:
                return "lncldapi.com"
            case .us:
                return "lncldglobal.com"
            }
        }
    }
    
    private(set) var region: Region = .cn
    
    // MARK: Current Installation
    
    /// Current installation.
    public var currentInstallation: LCInstallation {
        if let installation = self._currentInstallation {
            return installation
        } else {
            let installation = LCInstallation.currentInstallation(application: self)
                ?? LCInstallation(application: self)
            self._currentInstallation = installation
            return installation
        }
    }
    var _currentInstallation: LCInstallation?
    
    var currentInstallationFileURL: URL? {
        do {
            return try self.localStorageContext?.fileURL(
                place: .systemCaches,
                module: .push,
                file: .installation)
        } catch {
            Logger.shared.error(error)
            return nil
        }
    }
    
    // MARK: Current User
    
    /// Current user.
    public var currentUser: LCUser? {
        set {
            self._currentUser = newValue
            LCUser.saveCurrentUser(application: self, user: newValue)
        }
        get {
            if self._currentUser == nil {
                self._currentUser = LCUser.currentUser(application: self)
            }
            return self._currentUser
        }
    }
    var _currentUser: LCUser?
    
    var currentUserFileURL: URL? {
        do {
            return try self.localStorageContext?.fileURL(
                place: .persistentData,
                module: .storage,
                file: .user)
        } catch {
            Logger.shared.error(error)
            return nil
        }
    }
    
    // MARK: Internal Context
    
    private(set) var localStorageContext: LocalStorageContext?
    private(set) var httpClient: HTTPClient!
    private(set) var appRouter: AppRouter!
    
    // MARK: Init

    init() {}
    
    /// Create an application.
    /// - Parameters:
    ///   - id: see property `id`.
    ///   - key: see property `key`.
    ///   - serverURL: see property `serverURL`, default is `nil`, MUST provide if the application is in China.
    ///   - configuration: see property `configuration`, default is `Configuration.default`
    /// - Throws: If `serverURL` not provide in some region.
    public init(
        id: String,
        key: String,
        serverURL: String? = nil,
        configuration: Configuration = .default)
        throws
    {
        try self.doInitializing(
            id: id,
            key: key,
            serverURL: serverURL,
            configuration: configuration)
        LCApplication.registry[id] = self
    }
    
    /// Set up an application.
    /// - Parameters:
    ///   - id: see property `id`.
    ///   - key: see property `key`.
    ///   - serverURL: see property `serverURL`, default is `nil`, MUST provide if the application is in China.
    ///   - configuration: see property `configuration`, default is `Configuration.default`
    /// - Throws: If `serverURL` not provide in some region.
    public func set(
        id: String,
        key: String,
        serverURL: String? = nil,
        configuration: Configuration = .default)
        throws
    {
        if let _ = self.id {
            // clean previous context
            self.unregister()
        }
        try self.doInitializing(
            id: id,
            key: key,
            serverURL: serverURL,
            configuration: configuration)
        LCApplication.registry[id] = self
    }
    
    func doInitializing(
        id: String,
        key: String,
        serverURL: String?,
        configuration: Configuration)
        throws
    {
        self.id = id
        self.key = key
        self.serverURL = serverURL
        self.configuration = configuration
        self.region = Region(id: id)
        
        if [.cn, .ce].contains(self.region) {
            guard let _ = self.serverURL else {
                throw LCError(
                    code: .inconsistency,
                    reason: "Server URL not set.")
            }
        }
        
        // register LeanCloud Object Classes if needed.
        _ = ObjectProfiler.shared
        
        self.localStorageContext = LocalStorageContext(application: self)
        self.httpClient = HTTPClient(application: self)
        self.appRouter = AppRouter(application: self)
        
        self.logInitializationInfo()
    }
    
    func logInitializationInfo() {
        Logger.shared.debug("""
            \n------ LCApplication Initialization Infomation
            Version: \(Version.versionString)
            ID: \(self.id!)
            Server URL: \(self.serverURL ?? "nil")
            Configuration: \n\(self.configuration.debugDescription)
            Region: \(self.region)
            ------ END
            """)
    }
    
    // MARK: Deinit
    
    /// Before release the instance of the application, should unregister it to break circular reference.
    public func unregister() {
        LCApplication.registry.removeValue(forKey: self.id)
        self._currentInstallation = nil
        self._currentUser = nil
        self.localStorageContext = nil
        self.httpClient = nil
        self.appRouter = nil
    }
}
