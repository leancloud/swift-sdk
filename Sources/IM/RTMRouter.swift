//
//  RTMRouter.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/11/5.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/**
 RTM routing table.
 */
struct RTMRoutingTable {

    /// Primary URL.
    let primary: URL

    /// Secondary URL.
    let secondary: URL?

    /// Expiration date, it's a local date.
    let expiration: Date

}

/**
 RTM (Real Time Message) router for application.
 */
final class RTMRouter {

    /// The application to route.
    let application: LCApplication

    /// The HTTP router for application.
    private(set) lazy var httpRouter = HTTPRouter(application: application, configuration: .default)

    /// The HTTP client for application.
    private(set) lazy var httpClient = HTTPClient(application: application, configuration: .default)

    /// RTM router cache.
    private(set) lazy var cache = RTMRouterCache(application: application)

    /**
     Initialize RTM router with application.

     - parameter application: The application to route.
     */
    init(application: LCApplication) {
        self.application = application
    }

    /**
     Get result of routing table response.

     - parameter reponse: The response of routing table request.

     - returns: Result of routing table response.
     */
    private func result(response: LCResponse) -> LCGenericResult<RTMRoutingTable> {
        if let error = response.error {
            return .failure(error: error)
        }

        guard
            let object = response.value as? [String: Any],
            let primaryURLString = object["server"] as? String,
            let primaryURL = URL(string: primaryURLString),
            let ttl = object["ttl"] as? TimeInterval
        else {
            return .failure(error: LCError.malformedRTMRouterResponse)
        }

        var secondaryURL: URL?

        if let secondaryURLString = object["secondary"] as? String {
            secondaryURL = URL(string: secondaryURLString)
        }

        let expirationDate = Date(timeIntervalSinceNow: ttl)

        let routingTable = RTMRoutingTable(primary: primaryURL, secondary: secondaryURL, expiration: expirationDate)

        return .success(value: routingTable)
    }

    /**
     Handle response of routing table request.

     - parameter response: The response of routing table request.
     - parameter completion: The completion handler.
     */
    private func handle(response: LCResponse, completion: (LCGenericResult<RTMRoutingTable>) -> Void) {
        let result = self.result(response: response)

        completion(result)

        switch result {
        case .success(let routingTable):
            do {
                try cache.setRoutingTable(routingTable)
            } catch let error {
                Logger.shared.error(error)
            }
        case .failure:
            break
        }
    }

    /**
     Request routing table.

     - parameter completion: The completion handler.

     - returns: Routing table request.
     */
    @discardableResult
    private func request(completion: @escaping (LCGenericResult<RTMRoutingTable>) -> Void) -> LCRequest {
        guard let appId = application.id else {
            return httpClient.request(
                error: LCError.applicationNotInitialized,
                completionHandler: completion)
        }

        guard let routerURL = httpRouter.route(path: "v1/route") else {
            return httpClient.request(
                error: LCError.rtmRouterURLNotFound,
                completionHandler: completion)
        }

        let parameters: [String: Any] = ["appId": appId, "secure": 1]

        return httpClient.request(url: routerURL, method: .get, parameters: parameters) { response in
            self.handle(response: response, completion: completion)
        }
    }

    /**
     Get routing table.

     It will request and cache routing table, and return cached routing table if possible.

     - parameter completion: The completion handler.
     */
    func route(completion: @escaping (LCGenericResult<RTMRoutingTable>) -> Void) {
        do {
            if let routingTable = try cache.getRoutingTable() {
                completion(.success(value: routingTable))
            } else {
                request(completion: completion)
            }
        } catch let error {
            request(completion: completion)
            Logger.shared.error(error)
        }
    }

}

extension LCError {

    static let rtmRouterURLNotFound = LCError(
        code: .inconsistency,
        reason: "RTM router URL not found.")

    static let malformedRTMRouterResponse = LCError(
        code: .malformedData,
        reason: "Malformed RTM router response.")

}
