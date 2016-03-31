//
//  RESTClient.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/30/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation
import Alamofire

/**
 LeanCloud REST client.

 This class manages requests for LeanCloud REST API.
 */
class RESTClient {
    /// HTTP Method.
    enum Method: String {
        case GET
        case POST
        case PUT
        case DELETE

        /// Get Alamofire corresponding method
        var alamofireMethod: Alamofire.Method {
            switch self {
            case .GET:    return .GET
            case .POST:   return .POST
            case .PUT:    return .PUT
            case .DELETE: return .DELETE
            }
        }
    }

    /// Header field name.
    class HeaderFieldName {
        static let ID         = "X-LC-Id"
        static let Signature  = "X-LC-Sign"
        static let Session    = "X-LC-Session"
        static let Production = "X-LC-Prod"
        static let UserAgent  = "User-Agent"
        static let Accept     = "Accept"
    }

    /// REST API version.
    static let APIVersion = "1.1"

    /// Default timeout interval of each request.
    static let defaultTimeoutInterval: NSTimeInterval = 10

    /// REST client shared instance.
    static let sharedInstance = RESTClient()

    /// Request dispatch queue.
    static let dispatchQueue = dispatch_queue_create("LeanCloud.REST", DISPATCH_QUEUE_CONCURRENT)

    /// Shared request manager.
    static var requestManager: Alamofire.Manager = {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.timeoutIntervalForRequest = defaultTimeoutInterval
        return Manager(configuration: configuration)
    }()

    /// User agent of SDK.
    static let userAgent = "LeanCloud Swift-\(Version) SDK"

    /// Signature of each request.
    static var signature: String {
        let timestamp = String(format: "%.0f", 1000 * NSDate().timeIntervalSince1970)
        let hash = "\(timestamp)\(Configuration.sharedInstance.applicationKey)".MD5String.lowercaseString

        return "\(hash),\(timestamp)"
    }

    /// Common REST request headers.
    static var commonHeaders: [String:String] {
        let headers: [String:String] = [
            HeaderFieldName.ID:        Configuration.sharedInstance.applicationID,
            HeaderFieldName.Signature: self.signature,
            HeaderFieldName.UserAgent: self.userAgent,
            HeaderFieldName.Accept:    "application/json"
        ]

        /* TODO: Add user session and production mode fields etc. */

        return headers
    }

    /// REST host for current service region.
    static var host: String {
        switch Configuration.sharedInstance.serviceRegion {
        case .CN: return "api.leancloud.cn"
        case .US: return "us-api.leancloud.cn"
        }
    }

    /**
     Get absolute REST API URL string for endpoint.

     - parameter endpoint: The REST API endpoint.
     - returns: An absolute REST API URL string.
     */
    static func absoluteURLString(endpoint: String) -> String {
        return "https://\(self.host)/\(self.APIVersion)/\(endpoint)"
    }

    /**
     Merge headers with common headers.

     - parameter headers: The headers to be merged.
     - returns: The merged headers.
     */
    static func mergeCommonHeaders(headers: [String: String]?) -> [String: String] {
        var headers = headers ?? [:]
        commonHeaders.forEach { (key, value) in headers[key] = value }
        return headers
    }

    /**
     Creates a request to REST API and sends it asynchronously.

     - parameter method:            The HTTP Method.
     - parameter endpoint:          The REST API endpoint.
     - parameter parameters:        The request parameters.
     - parameter headers:           The request headers.
     - parameter completionHandler: The completion callback closure.

     - returns: A request object.
     */
    static func request(
        method: Method,
        _ endpoint: String,
        parameters: [String: AnyObject]? = nil,
        headers: [String: String]? = nil,
        completionHandler: (Response) -> Void)
        -> Request
    {
        let method    = method.alamofireMethod
        let URLString = absoluteURLString(endpoint)
        let headers   = mergeCommonHeaders(headers)

        let request = requestManager.request(method, URLString, parameters: parameters, encoding: .JSON, headers: headers)

        request.responseJSON(queue: RESTClient.dispatchQueue) { response in
            completionHandler(Response(response))
        }

        return Request(request)
    }

    /**
     Creates a request to REST API and sends it synchronously.

     - parameter method:            The HTTP Method.
     - parameter endpoint:          The REST API endpoint.
     - parameter parameters:        The request parameters.
     - parameter headers:           The request headers.

     - returns: A response object.
     */
    static func request(
        method: Method,
        _ endpoint: String,
        headers: [String: String]? = nil,
        parameters: [String: AnyObject]? = nil)
        -> Response
    {
        var result: Response!

        let semaphore = dispatch_semaphore_create(0)

        request(method, endpoint, parameters: parameters, headers: headers) { response in
            result = response
        }

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        return result
    }
}