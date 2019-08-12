//
//  Application.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/8/28.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

var applicationRegistry: [String: LCApplication] = [:]

/**
 LeanCloud application.

 An `LCApplication` object is an abstract of remote LeanCloud application.

 It is a context of application-specific settings and objects.
 */
public class LCApplication {
    
    /// log level.
    public static var logLevel: LogLevel = .off
    
    /**
     Default application.
     
     You must call method `set(id:key:region:)` to initialize it before your starting.
     */
    public static let `default` = LCApplication()

    /**
     Application region.
     */
    enum Region {

        case cn
        case ce
        case us

        private enum Suffix: String {

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
            } else { /* Old application of cn region may have no suffix. */
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

    /**
     Application log level.
     */
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
    
    /// Application Configuration.
    public struct Configuration {
        
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
        
        public static let `default` = Configuration()
        
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
    
    public enum ServerCustomizableModule {
        case api(_ host: String)
        case push(_ host: String)
        case engine(_ host: String)
        case rtm(_ host: String)
        
        var moduleKeyAndHost: (key: String, host: String) {
            switch self {
            case .api(let host):
                return (HTTPRouter.Module.api.key, host)
            case .engine(let host):
                return (HTTPRouter.Module.engine.key, host)
            case .push(let host):
                return (HTTPRouter.Module.push.key, host)
            case .rtm(let host):
                return (HTTPRouter.Module.rtm.key, host)
            }
        }
    }
    
    public typealias Identifier = String

    /// Application ID.
    public private(set) var id: LCApplication.Identifier!

    /// Application key.
    public private(set) var key: String!
    
    /// Application Configuration.
    public private(set) var configuration: Configuration = .default

    /// Application region.
    private(set) lazy var region: Region = {
        return Region(id: id)
    }()
    
    lazy var currentInstallationCacheURL: URL? = {
        do {
            return try self.localStorageContext?.fileURL(place: .systemCaches, module: .push, file: .installation)
        } catch {
            Logger.shared.error(error)
            return nil
        }
    }()
    
    /// Current Installation.
    public internal(set) lazy var currentInstallation: LCInstallation = {
        if
            let localStorageContext = self.localStorageContext,
            let fileURL: URL = self.currentInstallationCacheURL
        {
            do {
                if
                    let table: LCInstallation.CacheTable = try localStorageContext.table(from: fileURL),
                    let data: Data = table.jsonString.data(using: .utf8),
                    let dictionary: [String: Any] = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                {
                    let lcDictionary = try LCDictionary(application: self, unsafeObject: dictionary)
                    return LCInstallation(application: self, dictionary: lcDictionary)
                }
            } catch {
                Logger.shared.error(error)
            }
        }
        return LCInstallation(application: self)
    }()
    
    /// Current User.
    public var currentUser: LCUser?
    
    private(set) var localStorageContext: LocalStorageContext?
    
    private(set) var httpClient: HTTPClient!
    
    private(set) var httpRouter: HTTPRouter!

    /**
     Create an application.

     - note: We make initializer internal before multi-applicaiton is supported.
     */
    init() {}

    /**
     Create an application with id and key.

     - parameter id: Application ID.
     - parameter key: Application key.
     - parameter configuration: Application Configuration.
     */
    public init(id: String, key: String, configuration: Configuration = .default) throws {
        if let _ = applicationRegistry[id] {
            throw LCError.applicationDidRegister(id: id)
        }
        self.id = id
        self.key = key
        self.configuration = configuration
        applicationRegistry[id] = self
        
        self.doInitializing(configuration: configuration)
    }

    /**
     Initialize default application.

     - parameter id:    Application ID.
     - parameter key:   Application key.
     - parameter configuration: Application Configuration.
     */
    public func set(id: String, key: String, configuration: Configuration = .default) throws {
        guard self === LCApplication.default else {
            throw LCError(code: .inconsistency, reason: "Only LCApplication.default can call this function.")
        }
        if let setID = self.id, let setKey = self.key {
            guard setID == id, setKey == key else {
                throw LCError(code: .inconsistency, reason: "Should not modify the id and key of LCApplication.default.")
            }
            applicationRegistry[id] = self
            return
        }
        if let _ = applicationRegistry[id] {
            throw LCError.applicationDidRegister(id: id)
        }
        self.id = id
        self.key = key
        self.configuration = configuration
        applicationRegistry[id] = self
        
        self.doInitializing(configuration: configuration)
    }
    
    func doInitializing(configuration: Configuration) {
        // init local storage context
        do {
            self.localStorageContext = try LocalStorageContext(applicationID: self.id)
        } catch {
            Logger.shared.error(error)
        }
        // register default LeanCloud object classes if needed.
        _ = ObjectProfiler.shared
        // init HTTP client
        self.httpClient = HTTPClient(
            application: self,
            configuration: .default
        )
        self.httpRouter = HTTPRouter(
            application: self,
            configuration: .default
        )
        
        Logger.shared.debug(
            """
            \n
            ------ LCApplication Initializing Infomation
            
            LCApplication with ID<\"\(self.id!)\"> did initialize success.
            
            The Configuration of this Application is \(configuration).
            
            ------ END
            
            """
        )
    }

}

extension LCError {
    
    static func applicationDidRegister(id: String) -> LCError {
        return LCError(
            code: .inconsistency,
            reason: "Application with \"\(id)\" has been registered."
        )
    }
    
}
