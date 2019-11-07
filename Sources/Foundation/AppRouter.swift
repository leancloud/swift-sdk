//
//  AppRouter.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/9/5.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

class AppRouter: InternalSynchronizing {
    
    // MARK: Constant
    
    static let url: URL = URL(string: "https://app-router.com/2/route")!
    static let rtmRouterPath: String = "v1/route"
    static let pathToModuleTable: [String: Module] = [
        "push": .push,
        "installations": .push,
        "call": .engine,
        "functions": .engine
    ]
    
    enum Module: String {
        case api
        case push
        case engine
        case rtm
    }
    
    struct Configuration {
        static let `default` = Configuration(apiVersion: "1.1")
        let apiVersion: String
    }
    
    struct CacheTable: Codable {
        let apiServer: String?
        let engineServer: String?
        let pushServer: String?
        let rtmRouterServer: String?
        
        let ttl: TimeInterval?
        var createdTimestamp: TimeInterval?
        
        enum CodingKeys: String, CodingKey {
            case apiServer = "api_server"
            case engineServer = "engine_server"
            case pushServer = "push_server"
            case rtmRouterServer = "rtm_router_server"
            
            case ttl = "ttl"
            case createdTimestamp = "created_timestamp"
        }
        
        func host(module: Module) -> String? {
            guard let ttl = self.ttl,
                let createdTimestamp = self.createdTimestamp,
                createdTimestamp + ttl > Date().timeIntervalSince1970 else {
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
            }
        }
    }
    
    // MARK: Property

    let application: LCApplication
    let configuration: Configuration
    let customizedServerTable: [String: String]
    
    var cacheTable: CacheTable? {
        set {
            self.sync(self._cacheTable = newValue)
        }
        get {
            self.sync(self._cacheTable)
        }
    }
    private var _cacheTable: CacheTable?
    
    var cacheFileURL: URL? {
        do {
            return try self.application
                .localStorageContext?
                .fileURL(
                    place: .systemCaches,
                    module: .router,
                    file: .appServer)
        } catch {
            Logger.shared.error(error)
            return nil
        }
    }
    
    // MARK: Init
    
    init(application: LCApplication, configuration: Configuration = .default) {
        self.application = application
        self.configuration = configuration
        self.customizedServerTable = application.configuration.customizedServers
            .reduce(into: [:], { (map, customizedServer) in
                let (module, url) = customizedServer.values
                map[module.rawValue] = url
            })
        
        if let fileURL = self.cacheFileURL {
            do {
                self.cacheTable = try self.application
                    .localStorageContext?
                    .table(from: fileURL)
            } catch {
                Logger.shared.error(error)
            }
        }
    }
    
    // MARK: Internal Synchronizing
    
    let lock = NSLock()
    var mutex: NSLock {
        return self.lock
    }

    private(set) var isRequesting: Bool = false
}

// MARK: Private

extension AppRouter {
    
    // MARK: Module

    func module(_ path: String) -> Module {
        var path = path
        while path.hasPrefix("/") {
            path = String(path.dropFirst())
        }
        if path == AppRouter.rtmRouterPath {
            return .rtm
        } else if let firstPathComponent = path.components(separatedBy: "/").first,
            let module = AppRouter.pathToModuleTable[firstPathComponent] {
            return module
        } else {
            return .api
        }
    }
    
    // MARK: Path
    
    func versionizedPath(_ path: String) -> String {
        return self.configuration.apiVersion.appendingPathComponent(path)
    }
    
    func absolutePath(_ path: String) -> String {
        return "/".appendingPathComponent(path)
    }
    
    // MARK: URL

    func schemingURL(_ host: String) -> String {
        if let url = URL(string: host),
            let scheme: String = url.scheme,
            /*
             For host "example.com:8080",
             url.scheme is "example.com".
             So, we need a farther check here.
             */
            host.hasPrefix("\(scheme)://") {
            return host
        } else {
            return "https://\(host)"
        }
    }
    
    func absoluteURL(_ host: String, path: String) -> URL? {
        guard var components = URLComponents(string:
            self.schemingURL(host)) else {
                return nil
        }
        if let absolutePathURL = URL(string:
            self.absolutePath(components.path
                .appendingPathComponent(path))) {
            components.path = absolutePathURL.path
            components.query = absolutePathURL.query
            components.fragment = absolutePathURL.fragment
        }
        return components.url
    }
    
    // MARK: Fallback
    
    func fallbackURL(module: Module, path: String) -> URL? {
        let TLD: String = self.application.region.domain
        let prefix: String = self.application.id.prefix(upTo: 8).lowercased()
        return self.absoluteURL(
            "\(prefix).\(module).\(TLD)",
            path: path)
    }
    
    // MARK: Cache
    
    func cachedHost(module: Module) -> String? {
        if let host = self.cacheTable?.host(module: module) {
            return host
        } else {
            self.requestAppRouter()
            return nil
        }
    }
    
    func cacheAppRouter(data: Data) {
        do {
            var table = try JSONDecoder().decode(CacheTable.self, from: data)
            table.createdTimestamp = Date().timeIntervalSince1970
            self.cacheTable = table
            if let url = self.cacheFileURL,
                let context = self.application.localStorageContext {
                try context.save(table: table, to: url)
            }
        } catch {
            Logger.shared.error(error)
        }
    }
    
    // MARK: Request
    
    @discardableResult
    func getAppRouter(_ completion: @escaping (LCResponse) -> Void) -> LCRequest {
        return self.application.httpClient.request(
            url: AppRouter.url,
            method: .get,
            parameters: ["appId": self.application.id!],
            completionHandler: { completion($0) })
    }
    
    func requestAppRouter() {
        guard self.sync(closure: {
            if self.isRequesting {
                return false
            } else {
                self.isRequesting = true
                return true
            }
        }) else { return }
        self.getAppRouter { (response) in
            if response.isSuccess, let data = response.data {
                self.cacheAppRouter(data: data)
            }
            self.sync(self.isRequesting = false)
        }
    }
    
}

// MARK: Public

extension AppRouter {
    
    func batchRequestPath(_ path: String) -> String {
        return self.absolutePath(self.versionizedPath(path))
    }
    
    func route(path: String, module: Module? = nil) -> URL? {
        let module = module ?? self.module(path)
        let path = (module != .rtm) ? self.versionizedPath(path) : path
        
        if let host = self.customizedServerTable[module.rawValue] ??
            self.application.serverURL {
            return self.absoluteURL(host, path: path)
        }
        
        if self.application.region == .us {
            if let host = self.cachedHost(module: module) {
                return self.absoluteURL(host, path: path)
            }
            return self.fallbackURL(module: module, path: path)
        }
        
        return nil
    }
    
}
