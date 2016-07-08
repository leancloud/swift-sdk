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

    /// Data type.
    enum DataType: String {
        case Object   = "Object"
        case Pointer  = "Pointer"
        case Relation = "Relation"
        case GeoPoint = "GeoPoint"
        case Bytes    = "Bytes"
        case Date     = "Date"
    }

    /// Reserved key.
    class ReservedKey {
        static let Op         = "__op"
        static let Type       = "__type"
        static let InternalId = "__internalId"
        static let Children   = "__children"
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
    static var commonHeaders: [String: String] {
        var headers: [String: String] = [
            HeaderFieldName.ID:        Configuration.sharedInstance.applicationID,
            HeaderFieldName.Signature: self.signature,
            HeaderFieldName.UserAgent: self.userAgent,
            HeaderFieldName.Accept:    "application/json"
        ]

        if let sessionToken = LCUser.current?.sessionToken {
            headers[HeaderFieldName.Session] = sessionToken.value
        }

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
     Get endpoint of object.

     - parameter object: The object from which you want to get the endpoint.

     - returns: The endpoint of object.
     */
    static func endpoint(object: LCObject) -> String {
        return endpoint(object.actualClassName)
    }

    /**
     Get eigen endpoint of object.

     - parameter object: The object from which you want to get the eigen endpoint.

     - returns: The eigen endpoint of object.
     */
    static func eigenEndpoint(object: LCObject) -> String? {
        guard let objectId = object.objectId else {
            return nil
        }

        return "\(endpoint(object))/\(objectId.value)"
    }

    /**
     Get endpoint for class name.

     - parameter className: The class name.

     - returns: The endpoint for class name.
     */
    static func endpoint(className: String) -> String {
        switch className {
        case LCUser.objectClassName():
            return "users"
        case LCRole.objectClassName():
            return "roles"
        default:
            return "classes/\(className)"
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

     Field in `headers` will overrides the field in common header with the same name.

     - parameter headers: The headers to be merged.

     - returns: The merged headers.
     */
    static func mergeCommonHeaders(headers: [String: String]?) -> [String: String] {
        var result = commonHeaders

        headers?.forEach { (key, value) in result[key] = value }

        return result
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
        completionHandler: (LCResponse) -> Void)
        -> LCRequest
    {
        let method    = method.alamofireMethod
        let URLString = absoluteURLString(endpoint)
        let headers   = mergeCommonHeaders(headers)
        var encoding: ParameterEncoding!

        switch method {
        case .GET: encoding = .URLEncodedInURL
        default:   encoding = .JSON
        }

        let request = requestManager.request(method, URLString, parameters: parameters, encoding: encoding, headers: headers)

        request.responseJSON(queue: dispatchQueue) { response in
            completionHandler(LCResponse(response))
        }

        return LCRequest(request)
    }

    /**
     Creates a request to REST API and sends it synchronously.

     - parameter method:     The HTTP Method.
     - parameter endpoint:   The REST API endpoint.
     - parameter parameters: The request parameters.
     - parameter headers:    The request headers.

     - returns: A response object.
     */
    static func request(
        method: Method,
        _ endpoint: String,
        headers: [String: String]? = nil,
        parameters: [String: AnyObject]? = nil)
        -> LCResponse
    {
        var result: LCResponse!

        let semaphore = dispatch_semaphore_create(0)

        request(method, endpoint, parameters: parameters, headers: headers) { response in
            result = response
            dispatch_semaphore_signal(semaphore)
        }

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        return result
    }

    /**
     Asynchronize task into request dispatch queue.

     - parameter task:       The task to be asynchronized.
     - parameter completion: The completion closure to be called on main thread after task finished.
     */
    static func asynchronize<Result>(task: () -> Result, completion: (Result) -> Void) {
        Utility.asynchronize(task, dispatchQueue, completion)
    }
}