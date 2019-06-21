//
//  HTTPRouter.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/9/5.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/**
 HTTP router for application.
 */
class HTTPRouter {

    /**
     Application API module.
     */
    enum Module: String {

        case api
        case push
        case engine
        case stats
        case rtm = "rtm_router"

        var key: String {
            return "\(rawValue)_server"
        }

        init?(key: String) {
            guard key.hasSuffix("_server") else {
                return nil
            }

            let prefix = String(key.dropLast(7))

            if let module = Module(rawValue: prefix) {
                self = module
            } else {
                return nil
            }
        }

    }

    /**
     HTTP router configuration.
     */
    struct Configuration {

        let apiVersion: String

        static let `default` = Configuration(apiVersion: "1.1")

    }

    let application: LCApplication

    let configuration: Configuration

    init(application: LCApplication, configuration: Configuration) {
        self.application = application
        
        var _customizedServerTable: [String: String] = [:]
        application.configuration.customizedServers.forEach { (item) in
            let tuple = item.moduleKeyAndHost
            _customizedServerTable[tuple.key] = tuple.host
        }
        self.customizedHostTable = _customizedServerTable
        
        self.configuration = configuration
        if let localStorageContext = application.localStorageContext {
            do {
                let url: URL = try localStorageContext.fileURL(place: .systemCaches, module: .router, file: .appServer)
                self.cacheTable = try localStorageContext.table(from: url)
                self.cacheTableURL = url
            } catch {
                Logger.shared.error(error)
            }
        }
    }

    private let appRouterURL = URL(string: "https://app-router.leancloud.cn/2/route")

    /// Current app router request.
    private var appRouterRequest: LCRequest?

    /// App router completion array.
    private var appRouterCompletions: [(LCBooleanResult) -> Void] = []
    
    private(set) var cacheTable: CacheTable?
    
    private(set) var cacheTableURL: URL?

    /// RTM router path.
    private let rtmRouterPath = "v1/route"

    /// Module table indexed by first path component.
    private let moduleTable: [String: Module] = [
        "push": .push,
        "installations": .push,

        "call": .engine,
        "functions": .engine,

        "stats": .stats,
        "statistics": .stats,
        "always_collect": .stats
    ]
    
    private let customizedHostTable: [String: String]

    /**
     Get module of path.

     - parameter path: A REST API path.

     - returns: The module of path.
     */
    private func findModule(path: String) -> Module {
        if path == rtmRouterPath {
            return .rtm
        } else if let firstPathComponent = path.components(separatedBy: "/").first, let module = moduleTable[firstPathComponent] {
            return module
        } else {
            return .api
        }
    }

    /**
     Check if a host has scheme.

     - parameter host: URL host string.

     - returns: true if host has scheme, false otherwise.
     */
    private func hasScheme(host: String) -> Bool {
        guard let url = URL(string: host), let scheme = url.scheme else {
            return false
        }

        /* For host "example.com:8080", url.scheme is "example.com". So, we need a farther check here. */

        guard host.hasPrefix(scheme + "://") else {
            return false
        }

        return true
    }

    /**
     Add scheme to host.

     - parameter host: URL host string. If the host already has scheme, it will be returned without change.

     - returns: A host with scheme.
     */
    private func addScheme(host: String) -> String {
        if hasScheme(host: host) {
            return host
        } else {
            return "https://\(host)"
        }
    }

    /**
     Versionize a path.

     - parameter path: The path to be versionized.

     - returns: A versionized path.
     */
    private func versionizedPath(_ path: String, module: Module? = nil) -> String {
        let module = module ?? findModule(path: path)

        switch module {
        case .rtm:
            return path // RTM router path itself has API version already.
        default:
            return configuration.apiVersion.appendingPathComponent(path)
        }
    }

    /**
     Make path to be absolute.

     - parameter path: The path. It may already be a absolute path.

     - returns: An absolute path.
     */
    private func absolutePath(_ path: String) -> String {
        return "/".appendingPathComponent(path)
    }

    /**
     Create batch request path.

     - parameter path: A path without API version.

     - returns: A versionized absolute path.
     */
    func batchRequestPath(for path: String) -> String {
        return absolutePath(versionizedPath(path))
    }

    /**
     Create absolute url with host and path.

     - parameter host: URL host, maybe with scheme and port, or even path, like "http://example.com:8000/foo".
     - parameter path: URL path.

     - returns: An absolute URL.
     */
    func absoluteUrl(host: String, path: String) -> URL? {
        let fullHost = addScheme(host: host)

        guard var components = URLComponents(string: fullHost) else {
            return nil
        }

        let fullPath = absolutePath(components.path.appendingPathComponent(path))

        if let fullPathUrl = URL(string: fullPath) {
            components.path = fullPathUrl.path
            components.query = fullPathUrl.query
            components.fragment = fullPathUrl.fragment
        }

        let url = components.url

        return url
    }

    /**
     Get fallback URL for path and module.

     - parameter path: A REST API path.
     - parameter module: The module of path.

     - returns: The fallback URL.
     */
    func fallbackUrl(path: String, module: Module) -> URL? {
        let tld = application.region.domain
        let prefix = String(application.id.prefix(upTo: 8)).lowercased()

        let host = "\(prefix).\(module).\(tld)"
        let url = absoluteUrl(host: host, path: path)

        return url
    }

    /**
     Cache app router.

     - parameter dictionary: The raw dictionary returned by app router.
     */
    func cacheAppRouter(_ dictionary: LCDictionary) throws {
        let key = CacheTable.CodingKeys.self
        let table = CacheTable(
            apiServer: dictionary[key.apiServer.rawValue]?.stringValue,
            engineServer: dictionary[key.engineServer.rawValue]?.stringValue,
            pushServer: dictionary[key.pushServer.rawValue]?.stringValue,
            rtmRouterServer: dictionary[key.rtmRouterServer.rawValue]?.stringValue,
            statsServer: dictionary[key.statsServer.rawValue]?.stringValue,
            ttl: dictionary[key.ttl.rawValue]?.doubleValue,
            createdTimestamp: Date().timeIntervalSince1970
        )
        self.cacheTable = table
        if let url: URL = self.cacheTableURL {
            try self.application.localStorageContext?.save(table: table, to: url)
        }
    }

    /**
     Handle app router request.

     It will call and clear app router completions.

     - parameter result: Result of app router request.
     */
    private func handleAppRouterResult(_ result: LCValueResult<LCDictionary>) {
        synchronize(on: self) {
            var booleanResult = LCBooleanResult.success

            switch result {
            case .success(let object):
                do {
                    try cacheAppRouter(object)
                } catch let error {
                    booleanResult = .failure(error: LCError(error: error))
                }
            case .failure(let error):
                booleanResult = .failure(error: error)
            }

            appRouterCompletions.forEach { completion in
                completion(booleanResult)
            }

            appRouterCompletions.removeAll()
            appRouterRequest = nil
        }
    }

    /**
     Request app router without throttle.

     - parameter completion: The completion handler.

     - returns: App router request.
     */
    private func requestAppRouterWithoutThrottle(completion: @escaping (LCValueResult<LCDictionary>) -> Void) -> LCRequest {
        let httpClient: HTTPClient = self.application.httpClient
        
        let url = self.appRouterURL!
        
        let appID = self.application.id!
        
        return httpClient.request(url: url, method: .get, parameters: ["appId": appID]) { response in
            completion(LCValueResult(response: response))
        }
    }

    /**
     Request app router.

     - note: The request will be controlled by a throttle, only one request is allowed one at a time.

     - parameter completion: The completion handler.

     - returns: App router request.
     */
    @discardableResult
    func requestAppRouter(completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        return synchronize(on: self) {
            appRouterCompletions.append(completion)

            if let appRouterRequest = appRouterRequest {
                return appRouterRequest
            } else {
                let appRouterRequest = requestAppRouterWithoutThrottle { result in
                    self.handleAppRouterResult(result)
                }
                self.appRouterRequest = appRouterRequest
                return appRouterRequest
            }
        }
    }

    /**
     Get cached url for path and module.

     - parameter path: URL path.
     - parameter module: API module.

     - returns: The cached url, or nil if cache expires or not found.
     */
    func cachedUrl(path: String, module: Module) -> URL? {
        return synchronize(on: self) {
            guard let host: String = self.cacheTable?.host(module: module) else {
                return nil
            }
            return absoluteUrl(host: host, path: path)
        }
    }

    /**
     Route a path to API module.

     - parameter path: A path without API version.
     - parameter module: API module. If nil, it will use default rules.

     - returns: An absolute URL.
     */
    func route(path: String, module: Module? = nil) -> URL? {
        let module = module ?? findModule(path: path)
        let fullPath = versionizedPath(path, module: module)
        
        if let host = self.customizedHostTable[module.key] {
            return absoluteUrl(host: host, path: fullPath)
        }

        if let url = cachedUrl(path: fullPath, module: module) {
            return url
        } else {
            requestAppRouter { _ in /* Nothing to do */ }
        }

        if let url = fallbackUrl(path: fullPath, module: module) {
            return url
        } else {
            return nil
        }
    }

}

extension HTTPRouter {
    
    struct CacheTable: Codable {
        let apiServer: String?
        let engineServer: String?
        let pushServer: String?
        let rtmRouterServer: String?
        let statsServer: String?
        let ttl: TimeInterval?
        let createdTimestamp: TimeInterval
        
        enum CodingKeys: String, CodingKey {
            case apiServer = "api_server"
            case engineServer = "engine_server"
            case pushServer = "push_server"
            case rtmRouterServer = "rtm_router_server"
            case statsServer = "stats_server"
            case ttl = "ttl"
            case createdTimestamp = "created_timestamp"
        }
        
        func host(module: Module) -> String? {
            guard (self.createdTimestamp + (ttl ?? 0)) > Date().timeIntervalSince1970 else {
                return nil
            }
            switch module {
            case .api:
                return self.apiServer
            case .engine:
                return self.engineServer
            case .push:
                return self.pushServer
            case .rtm:
                return self.rtmRouterServer
            case .stats:
                return self.statsServer
            }
        }
    }
    
}
