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
public final class LCApplication {
    
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

     We assume that log levels are ordered.
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

    /// Application ID.
    public private(set) var id: String!

    /// Application key.
    public private(set) var key: String!

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

     - note: We make initializer internal before multi-applicaiton is supported.
     */
    public init(id: String, key: String) throws {
        if let _ = applicationRegistry[id] {
            throw LCError.applicationDidRegister(id: id)
        }
        self.id = id
        self.key = key
        applicationRegistry[id] = self
        
        self.doInitializing()
    }

    /**
     Initialize application by application information.

     - parameter id:    Application ID.
     - parameter key:   Application key.
     */
    public func set(id: String, key: String) throws {
        if let _ = applicationRegistry[id] {
            throw LCError.applicationDidRegister(id: id)
        }
        self.id = id
        self.key = key
        applicationRegistry[id] = self
        
        self.doInitializing()
    }
    
    func doInitializing() {
        // init local storage context
        do {
            self.localStorageContext = try LocalStorageContext(applicationID: self.id)
        } catch {
            Logger.shared.error(error)
        }
        // register default LeanCloud object classes if needed.
        _ = ObjectProfiler.shared
        // init HTTP client
        self.httpClient = HTTPClient(application: self, configuration: .default)
        self.httpRouter = HTTPRouter(application: self, configuration: .default)
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
