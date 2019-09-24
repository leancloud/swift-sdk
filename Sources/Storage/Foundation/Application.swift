//
//  Application.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/8/28.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud application.

 An `LCApplication` object is an abstract of remote LeanCloud application.

 It is a context of application-specific settings and objects.
 */
public class LCApplication {
    
    // MARK: Registry
    
    static var registry: [String: LCApplication] = [:]
    
    // MARK: Log
    
    /// Application log level.
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
    
    /// Log level.
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
    
    /// Module of Customizable Server.
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
    
    /// Environment of the Application
    public struct Environment: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// development environment of Cloud Engine
        public static let cloudEngineDevelopment = Environment(rawValue: 1 << 0)
        
        /// development environment of Push
        public static let pushDevelopment = Environment(rawValue: 1 << 1)
        
        /// default is production environment
        public static let `default`: Environment = []
    }
    
    var cloudEngineMode: String {
        return self.configuration
            .environment
            .contains(.cloudEngineDevelopment)
            ? "0" : "1"
    }
    
    var pushMode: String {
        return self.configuration
            .environment
            .contains(.pushDevelopment)
            ? "dev" : "prod"
    }
    
    /// Application Configuration.
    public struct Configuration {
        public static let `default` = Configuration()
        
        /// Customized Servers
        public let customizedServers: [ServerCustomizableModule]
        
        /// Environment
        public let environment: Environment
        
        /// HTTP Request Timeout Interval, default is 60.0 second.
        public let HTTPRequestTimeoutInterval: TimeInterval
        
        /// RTM Connecting Timeout Interval, default is 15.0 second.
        public let RTMConnectingTimeoutInterval: TimeInterval
        
        /// RTM Command Timeout Interval, default is 30.0 second.
        public let RTMCommandTimeoutInterval: TimeInterval
        
        /// RTM Custom Server URL.
        public let RTMCustomServerURL: URL?
        
        public init(
            customizedServers: [ServerCustomizableModule] = [],
            environment: Environment = [.default],
            HTTPRequestTimeoutInterval: TimeInterval = 60.0,
            RTMConnectingTimeoutInterval: TimeInterval = 15.0,
            RTMCommandTimeoutInterval: TimeInterval = 30.0,
            RTMCustomServerURL: URL? = nil)
        {
            self.customizedServers = customizedServers
            self.environment = environment
            self.HTTPRequestTimeoutInterval = HTTPRequestTimeoutInterval
            self.RTMConnectingTimeoutInterval = RTMConnectingTimeoutInterval
            self.RTMCommandTimeoutInterval = RTMCommandTimeoutInterval
            self.RTMCustomServerURL = RTMCustomServerURL
        }
    }
    
    /// Application Configuration.
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
    
    /// Current Installation.
    public internal(set) lazy var currentInstallation: LCInstallation = {
        do {
            if let installation = try LCInstallation.currentInstallation(application: self) {
                return installation
            }
        } catch {
            Logger.shared.error(error)
        }
        return LCInstallation(application: self)
    }()
    
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
    
    /// Current User.
    public var currentUser: LCUser?
    
    // MARK: Internal Context
    
    private(set) var localStorageContext: LocalStorageContext?
    private(set) var httpClient: HTTPClient!
    private(set) var appRouter: AppRouter!
    
    // MARK: Init

    init() {}
    
    /// Create an application.
    /// - Parameter id: The ID.
    /// - Parameter key: The Key.
    /// - Parameter serverURL: The server URL string.
    /// - Parameter configuration: The Configuration.
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
    
    /// Initialize default application.
    /// - Parameter id: The ID.
    /// - Parameter key: The Key.
    /// - Parameter serverURL: The server URL string.
    /// - Parameter configuration: The Configuration.
    public func set(
        id: String,
        key: String,
        serverURL: String? = nil,
        configuration: Configuration = .default)
        throws
    {
        if let oldID = self.id {
            LCApplication.registry.removeValue(forKey: oldID)
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
        
        self.localStorageContext = try LocalStorageContext(applicationID: self.id)
        self.httpClient = HTTPClient(application: self)
        self.appRouter = AppRouter(application: self)
        
        self.logInitializationInfo()
    }
    
    func logInitializationInfo() {
        Logger.shared.debug("""
            \n------ LCApplication Initialization Infomation\n
            Version: \(__LeanCloudVersion)
            ID: \(self.id!)
            Server URL: \(self.serverURL ?? "")
            Configuration: \(self.configuration)
            Region: \(self.region)
            \n------ END\n
            """)
    }

}
