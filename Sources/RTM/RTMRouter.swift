//
//  RTMRouter.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/11/5.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

class RTMRouter {
    
    let application: LCApplication
    
    let tableCacheURL: URL?
    
    private(set) var table: RTMRouter.Table?
    
    init(application: LCApplication) throws {
        
        self.application = application
        
        if let storageContext = application.localStorageContext {
            let fileURL = try storageContext.fileURL(place: .systemCaches, module: .router, file: .rtmServer)
            self.tableCacheURL = fileURL
            self.table = try storageContext.table(from: fileURL)
        } else {
            self.tableCacheURL = nil
        }
    }
    
    private func result(response: LCResponse) -> LCGenericResult<RTMRouter.Table> {
        if let error = LCError(response: response) {
            return .failure(error: error)
        }

        guard
            let object = response.value as? [String: Any],
            let primaryServer = object[RTMRouter.Table.CodingKeys.primary.rawValue] as? String,
            let ttl = object[RTMRouter.Table.CodingKeys.ttl.rawValue] as? TimeInterval
            else
        {
            return .failure(error: LCError.RTMRouterResponseDataMalformed)
        }

        let secondaryServer = object[RTMRouter.Table.CodingKeys.secondary.rawValue] as? String

        let table = RTMRouter.Table(
            primary: primaryServer,
            secondary: secondaryServer,
            ttl: ttl,
            createdTimestamp: Date().timeIntervalSince1970,
            continuousFailureCount: 0
        )

        return .success(value: table)
    }

    private func handle(response: LCResponse, completion: (LCGenericResult<RTMRouter.Table>) -> Void) {
        let result = self.result(response: response)
        
        if let table = result.value {
            self.table = table
            if
                let cacheURL = self.tableCacheURL,
                let storageContext = self.application.localStorageContext
            {
                do {
                    try storageContext.save(table: table, to: cacheURL)
                } catch {
                    Logger.shared.error(error)
                }
            }
        }
        
        completion(result)
    }
    
    @discardableResult
    private func request(completion: @escaping (LCGenericResult<RTMRouter.Table>) -> Void) -> LCRequest {
        guard let routerURL = self.application.appRouter.route(path: "v1/route") else {
            return self.application.httpClient.request(
                error: LCError.RTMRouterURLNotFound,
                completionHandler: completion
            )
        }
        
        let parameters: [String: Any] = [
            "appId": self.application.id!,
            "secure": 1
        ]
        
        return self.application.httpClient.request(url: routerURL, method: .get, parameters: parameters) { response in
            self.handle(response: response, completion: completion)
        }
    }
    
    func route(completion: @escaping (_ direct: Bool, _ result: LCGenericResult<RTMRouter.Table>) -> Void) {
        if let table = self.table {
            if table.shouldClear {
                self.clearTableCache()
                self.request { (result) in
                    completion(false, result)
                }
            } else {
                completion(true, .success(value: table))
            }
        } else {
            self.request { (result) in
                completion(false, result)
            }
        }
    }
    
    func updateFailureCount(reset: Bool = false) {
        if reset {
            if self.table?.continuousFailureCount == 0 {
                return
            }
            self.table?.continuousFailureCount = 0
        } else {
            self.table?.continuousFailureCount += 1
        }
        if
            let table = self.table,
            let cacheURL = self.tableCacheURL,
            let storageContext = self.application.localStorageContext
        {
            do {
                try storageContext.save(table: table, to: cacheURL)
            } catch {
                Logger.shared.error(error)
            }
        }
    }
    
    func clearTableCache() {
        self.table = nil
        guard
            let cacheURL = self.tableCacheURL,
            let storageContext = self.application.localStorageContext
            else
        {
            return
        }
        do {
            try storageContext.clear(file: cacheURL)
        } catch {
            Logger.shared.error(error)
        }
    }
    
}

extension RTMRouter {
    
    struct Table: Codable {
        
        let primary: String
        let secondary: String?
        let ttl: TimeInterval
        let createdTimestamp: TimeInterval
        var continuousFailureCount: Int
        
        enum CodingKeys: String, CodingKey {
            case primary = "server"
            case secondary
            case ttl
            case createdTimestamp = "created_timestamp"
            case continuousFailureCount = "continuous_failure_count"
        }
        
        var primaryURL: URL? {
            return URL(string: self.primary)
        }
        
        var secondaryURL: URL? {
            if let secondary = self.secondary {
                return URL(string: secondary)
            } else {
                return nil
            }
        }
        
        var isExpired: Bool {
            return Date().timeIntervalSince1970 > self.ttl + self.createdTimestamp
        }
        
        var shouldClear: Bool {
            return (self.continuousFailureCount >= 10) || self.isExpired
        }
    }
    
}

extension LCError {

    static var RTMRouterURLNotFound: LCError {
        return LCError(
            code: .inconsistency,
            reason: "\(RTMRouter.self): URL not found."
        )
    }

    static var RTMRouterResponseDataMalformed: LCError {
        return LCError(
            code: .malformedData,
            reason: "\(RTMRouter.self): response data malformed."
        )
    }

}
