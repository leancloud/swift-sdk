//
//  HTTPClient.swift
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
class HTTPClient {
    /// HTTP Method.
    enum Method: String {
        case get
        case post
        case put
        case delete

        /// Get Alamofire corresponding method
        var alamofireMethod: Alamofire.HTTPMethod {
            switch self {
            case .get:    return .get
            case .post:   return .post
            case .put:    return .put
            case .delete: return .delete
            }
        }
    }

    /// Data type.
    enum DataType: String {
        case object   = "Object"
        case pointer  = "Pointer"
        case relation = "Relation"
        case geoPoint = "GeoPoint"
        case bytes    = "Bytes"
        case date     = "Date"
    }

    /// Header field name.
    class HeaderFieldName {
        static let id         = "X-LC-Id"
        static let signature  = "X-LC-Sign"
        static let session    = "X-LC-Session"
        static let production = "X-LC-Prod"
        static let userAgent  = "User-Agent"
        static let accept     = "Accept"
    }

    let application: LCApplication

    private lazy var logger: Logger = {
        return Logger(application: application)
    }()

    /// REST API version.
    static let apiVersion = "1.1"

    /// Default timeout interval of each request.
    let defaultTimeoutInterval: TimeInterval = HTTPClient.defaultTimeoutInterval

    /// Default timeout interval of each request.
    static let defaultTimeoutInterval: TimeInterval = NSURLRequest().timeoutInterval

    /// Request dispatch queue.
    static let dispatchQueue = DispatchQueue(label: "LeanCloud.REST", qos: .userInteractive, attributes: .concurrent)

    /// Shared session manager.
    lazy var requestManager: Alamofire.SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = defaultTimeoutInterval
        return SessionManager(configuration: configuration)
    }()

    /// User agent of SDK.
    let userAgent = "LeanCloud-Swift-SDK/\(Version)"

    /// Signature of each request.
    var signature: String {
        let timestamp = String(format: "%.0f", 1000 * Date().timeIntervalSince1970)
        let hash = (timestamp + application.key).md5String.lowercased()

        return "\(hash),\(timestamp)"
    }

    /// Common REST request headers.
    var commonHeaders: [String: String] {
        var headers: [String: String] = [
            HeaderFieldName.id:        application.ID,
            HeaderFieldName.signature: self.signature,
            HeaderFieldName.userAgent: self.userAgent,
            HeaderFieldName.accept:    "application/json"
        ]

        if let sessionToken = LCUser.current?.sessionToken {
            headers[HeaderFieldName.session] = sessionToken.value
        }

        return headers
    }

    /// REST host for current service region.
    var host: String {
        switch application.region {
        case .cn: return "api.leancloud.cn"
        case .us: return "us-api.leancloud.cn"
        }
    }

    init(application: LCApplication) {
        self.application = application
    }

    /**
     Get endpoint of object.

     - parameter object: The object from which you want to get the endpoint.

     - returns: The endpoint of object.
     */
    static func endpoint(_ object: LCObject) -> String {
        return endpoint(object.actualClassName)
    }

    /**
     Get eigen endpoint of object.

     - parameter object: The object from which you want to get the eigen endpoint.

     - returns: The eigen endpoint of object.
     */
    static func eigenEndpoint(_ object: LCObject) -> String? {
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
    static func endpoint(_ className: String) -> String {
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
    func absoluteURLString(_ endpoint: String) -> String {
        return "https://\(self.host)/\(HTTPClient.apiVersion)/\(endpoint)"
    }

    /**
     Merge headers with common headers.

     Field in `headers` will overrides the field in common header with the same name.

     - parameter headers: The headers to be merged.

     - returns: The merged headers.
     */
    func mergeCommonHeaders(_ headers: [String: String]?) -> [String: String] {
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
    func request(
        _ method: Method,
        _ endpoint: String,
        parameters: [String: AnyObject]? = nil,
        headers: [String: String]? = nil,
        completionHandler: @escaping (LCResponse) -> Void)
        -> LCRequest
    {
        let method    = method.alamofireMethod
        let urlString = absoluteURLString(endpoint)
        let headers   = mergeCommonHeaders(headers)
        var encoding: ParameterEncoding!

        switch method {
        case .get: encoding = URLEncoding.default
        default:   encoding = JSONEncoding.default
        }

        let request = requestManager.request(urlString, method: method, parameters: parameters, encoding: encoding, headers: headers).validate()
        log(request)

        request.responseJSON(queue: HTTPClient.dispatchQueue) { response in
            self.log(request, response)
            completionHandler(LCResponse(response, self.application))
        }

        return LCRequest(request)
    }

    func log(_ request: Request) {
        logger.debug("\n\n\(request.lcDebugDescription)\n")
    }

    func log(_ request: Request, _ response: DataResponse<Any>) {
        logger.debug("\n\n\(response.lcDebugDescription(request))\n")
    }

    /**
     Creates a request to REST API and sends it synchronously.

     - parameter method:     The HTTP Method.
     - parameter endpoint:   The REST API endpoint.
     - parameter parameters: The request parameters.
     - parameter headers:    The request headers.

     - returns: A response object.
     */
    func request(
        _ method: Method,
        _ endpoint: String,
        parameters: [String: AnyObject]? = nil,
        headers: [String: String]? = nil)
        -> LCResponse
    {
        var result: LCResponse!

        let semaphore = DispatchSemaphore(value: 0)

        _ = request(method, endpoint, parameters: parameters, headers: headers) { response in
            result = response
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: DispatchTime.distantFuture)

        return result
    }

    /**
     Asynchronize task into request dispatch queue.

     - parameter task:       The task to be asynchronized.
     - parameter completion: The completion closure to be called on main thread after task finished.
     */
    static func asynchronize<Result>(_ task: @escaping () -> Result, completion: @escaping (Result) -> Void) {
        Utility.asynchronize(task, dispatchQueue, completion)
    }
}

extension Request {

    var lcDebugDescription : String {
        var curl: String = debugDescription

        if curl.hasPrefix("$ ") {
            let startIndex: String.Index = curl.index(curl.startIndex, offsetBy: 2)
            curl = String(curl[startIndex...])
        }

        let taskIdentifier = task?.taskIdentifier ?? 0
        let message = "------ BEGIN LeanCloud HTTP Request\n" +
                      "task: \(taskIdentifier)\n" +
                      "curl: \(curl)\n" +
                      "------ END"
        return message
    }

}

extension DataResponse {

    func lcDebugDescription(_ request : Request) -> String {
        var body : Any

        switch value {
        case let value as [String : AnyObject]:
            /* Print pertty JSON string. */
            body = LCDictionary(unsafeObject: value).jsonString
            break
        default:
            body = value ?? ""
            break
        }

        let taskIdentifier = request.task?.taskIdentifier ?? 0
        let message = "------ BEGIN LeanCloud HTTP Response\n" +
                      "task: \(taskIdentifier)\n" +
                      "body: \(body)\n" +
                      "------ END"
        return message
    }

}
