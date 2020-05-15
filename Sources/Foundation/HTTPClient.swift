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
        case file     = "File"
    }

    /// Header field name.
    struct HeaderFieldName {
        static let id         = "X-LC-Id"
        static let signature  = "X-LC-Sign"
        static let session    = "X-LC-Session"
        static let production = "X-LC-Prod"
        static let userAgent  = "User-Agent"
        static let accept     = "Accept"
    }

    /**
     HTTPClient configuration.
     */
    struct Configuration {
        
        let userAgent: String
        
        static let `default` = Configuration(userAgent: "LeanCloud-Swift-SDK/\(Version.versionString)")
    }

    let application: LCApplication
    let configuration: Configuration
    let session: Alamofire.Session
    
    var urlCache: URLCache? {
        return self.session.sessionConfiguration.urlCache
    }

    init(application: LCApplication, configuration: Configuration = .default) {
        self.application = application
        self.configuration = configuration
        let urlSessionConfiguration = URLSessionConfiguration.default
        urlSessionConfiguration.timeoutIntervalForRequest = application.configuration
            .HTTPRequestTimeoutInterval
        urlSessionConfiguration.urlCache = application.configuration
            .HTTPURLCache
        self.session = Session(configuration: urlSessionConfiguration)
    }

    /// Default completion dispatch queue.
    let defaultCompletionConcurrentQueue = DispatchQueue(
        label: "LC.Swift.\(HTTPClient.self).defaultCompletionConcurrentQueue",
        attributes: .concurrent)

    /// Create a signature for request.
    func createRequestSignature() -> String {
        let timestamp = String(format: "%.0f", 1000 * Date().timeIntervalSince1970)
        let hash = (timestamp + application.key).md5.lowercased()

        return "\(hash),\(timestamp)"
    }

    /// Common REST request headers.
    func createCommonHeaders() -> [String: String] {
        var headers: [String: String] = [
            HeaderFieldName.id:        application.id,
            HeaderFieldName.signature: createRequestSignature(),
            HeaderFieldName.userAgent: configuration.userAgent,
            HeaderFieldName.accept:    "application/json",
            HeaderFieldName.production: self.application.cloudEngineMode
        ]

        if let sessionToken = self.application._currentUser?.sessionToken {
            headers[HeaderFieldName.session] = sessionToken.value
        }

        return headers
    }

    /**
     Get endpoint of class name.

     - parameter className: The object class name.

     - returns: The endpoint of class name.
     */
    func getClassEndpoint(className: String) -> String {
        switch className {
        case LCUser.objectClassName():
            return "users"
        case LCRole.objectClassName():
            return "roles"
        case LCInstallation.objectClassName():
            return "installations"
        default:
            return "classes/\(className)"
        }
    }

    /**
     Get class endpoint of object.

     - parameter object: The object from which you want to get the endpoint.

     - returns: The class endpoint of object.
     */
    func getClassEndpoint(object: LCObject) -> String {
        return getClassEndpoint(className: object.actualClassName)
    }

    /**
     Get endpoint for object.

     - parameter object: The object which the request will access.

     - returns: The endpoint for object.
     */
    func getObjectEndpoint(object: LCObject) -> String? {
        guard let objectId = object.objectId else {
            return nil
        }

        let classEndpoint = getClassEndpoint(object: object)

        return "\(classEndpoint)/\(objectId.value)"
    }

    /**
     Get versioned path for object and method.

     - parameter object: The object which the request will access.
     - parameter method: The HTTP method.

     - returns: A path with API version.
     */
    func getBatchRequestPath(object: LCObject, method: Method) throws -> String {
        var path: String

        switch method {
        case .get, .put, .delete:
            guard let objectEndpoint = getObjectEndpoint(object: object) else {
                throw LCError(code: .notFound, reason: "Cannot access object before save.")
            }
            path = objectEndpoint
        case .post:
            path = getClassEndpoint(object: object)
        }

        return self.application.appRouter.batchRequestPath(path)
    }

    /**
     Merge headers with common headers.

     Field in `headers` will overrides the field in common header with the same name.

     - parameter headers: The headers to be merged.

     - returns: The merged headers.
     */
    func mergeCommonHeaders(_ headers: [String: String]?) -> [String: String] {
        var result = createCommonHeaders()

        headers?.forEach { (key, value) in result[key] = value }

        return result
    }
    
    func response(with error: Error) -> LCResponse {
        return LCResponse(
            application: self.application,
            response: DataResponse<Any, Error>(
                request: nil,
                response: nil,
                data: nil,
                metrics: nil,
                serializationDuration: 0,
                result: .failure(error)))
    }
    
    func requestCache(
        url: URL,
        method: HTTPMethod,
        headers: HTTPHeaders,
        encoding: ParameterEncoding,
        parameters: [String: Any]?,
        completionQueue: DispatchQueue,
        completionHandler: @escaping (LCResponse) -> Void)
    {
        do {
            var request = try URLRequest(
                url: url,
                method: method,
                headers: headers)
            request = try encoding.encode(request, with: parameters)
            completionQueue.sync {
                guard let cachedResponse = self.urlCache?.cachedResponse(for: request),
                    let httpResponse = cachedResponse.response as? HTTPURLResponse else {
                        completionHandler(self.response(
                            with: LCError(
                                code: .notFound,
                                reason: "Cached Response not found.")))
                        return
                }
                let result = Result {
                    try JSONResponseSerializer()
                        .serialize(
                            request: request,
                            response: httpResponse,
                            data: cachedResponse.data,
                            error: nil)
                }.mapError { $0 }
                let response = LCResponse(
                    application: self.application,
                    response: DataResponse<Any, Error>(
                        request: request,
                        response: httpResponse,
                        data: cachedResponse.data,
                        metrics: nil,
                        serializationDuration: 0,
                        result: result))
                completionHandler(response)
            }
        } catch {
            completionQueue.async {
                completionHandler(self.response(
                    with: LCError(
                        error: error)))
            }
        }
    }
    
    func request(
        _ method: Method,
        _ path: String,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        cachePolicy: LCQuery.CachePolicy = .onlyNetwork,
        completionQueue: DispatchQueue? = nil,
        completionHandler: @escaping (LCResponse) -> Void)
        -> LCRequest
    {
        let completionQueue = completionQueue
            ?? self.defaultCompletionConcurrentQueue
        guard let url = self.application.appRouter.route(path: path) else {
            completionQueue.sync {
                completionHandler(self.response(
                    with: LCError(
                        code: .notFound,
                        reason: "URL not found.")))
            }
            return LCSingleRequest(request: nil)
        }
        let method = method.alamofireMethod
        let headers = HTTPHeaders(mergeCommonHeaders(headers))
        let encoding: ParameterEncoding
        switch method {
        case .get:
            encoding = URLEncoding.default
        default:
            encoding = JSONEncoding.default
        }
        let requestCachedResponse: () -> Void = {
            self.requestCache(
                url: url,
                method: method,
                headers: headers,
                encoding: encoding,
                parameters: parameters,
                completionQueue: completionQueue,
                completionHandler: completionHandler)
        }
        switch cachePolicy {
        case .onlyNetwork, .networkElseCache:
            let request = self.session.request(
                url, method: method,
                parameters: parameters,
                encoding: encoding,
                headers: headers).validate()
            request.lcDebugDescription()
            request.responseJSON(queue: completionQueue) { afResponse in
                afResponse.lcDebugDescription(request: request)
                let response = LCResponse(
                    application: self.application,
                    afDataResponse: afResponse)
                if case .onlyNetwork = cachePolicy {
                    completionHandler(response)
                } else {
                    if let _ = LCError(response: response) {
                        requestCachedResponse()
                    } else {
                        completionHandler(response)
                    }
                }
            }
            return LCSingleRequest(request: request)
        case .onlyCache:
            requestCachedResponse()
            return LCSingleRequest(request: nil)
        }
    }
    
    func request(
        url: URL,
        method: Method,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        completionQueue: DispatchQueue? = nil,
        completionHandler: @escaping (LCResponse) -> Void)
        -> LCRequest
    {
        let method = method.alamofireMethod
        let headers = HTTPHeaders(mergeCommonHeaders(headers))
        let encoding: ParameterEncoding
        switch method {
        case .get:
            encoding = URLEncoding.default
        default:
            encoding = JSONEncoding.default
        }
        let request = self.session.request(
            url, method: method,
            parameters: parameters,
            encoding: encoding,
            headers: headers).validate()
        request.lcDebugDescription()
        request.responseJSON(
            queue: completionQueue ?? self.defaultCompletionConcurrentQueue)
        { afResponse in
            afResponse.lcDebugDescription(request: request)
            completionHandler(LCResponse(
                application: self.application,
                afDataResponse: afResponse))
        }
        return LCSingleRequest(request: request)
    }
    
    func request<T: LCResultType>(
        error: Error,
        completionQueue: DispatchQueue? = nil,
        completionHandler: @escaping (T) -> Void)
        -> LCRequest
    {
        return self.request(
            object: error,
            completionQueue: completionQueue)
        { error in
            completionHandler(T(
                error: LCError(
                    error: error)))
        }
    }
    
    func request<T>(
        object: T,
        completionQueue: DispatchQueue? = nil,
        completionHandler: @escaping (T) -> Void)
        -> LCRequest
    {
        (completionQueue ?? self.defaultCompletionConcurrentQueue).async {
            completionHandler(object)
        }
        return LCSingleRequest(request: nil)
    }
}

extension Request {
    
    func lcDebugDescription() {
        guard LCApplication.logLevel >= .debug else {
            return
        }
        self.cURLDescription { (curl) in
            Logger.shared.debug(closure: { () -> String in
                var message = "\n------ BEGIN LeanCloud HTTP Request\n"
                if let taskIdentifier = self.task?.taskIdentifier {
                    message += "task: \(taskIdentifier)\n"
                }
                var curl = curl
                if curl.hasPrefix("$ ") {
                    curl.removeFirst(2)
                }
                message += "curl: \(curl)\n"
                message += "------ END"
                return message
            })
        }
    }
}

extension DataResponse {
    
    func lcDebugDescription(request : Request) {
        Logger.shared.debug(closure: { () -> String in
            var message = "\n------ BEGIN LeanCloud HTTP Response\n"
            if let taskIdentifier = request.task?.taskIdentifier {
                message += "task: \(taskIdentifier)\n"
            }
            if let response = self.response {
                message += "code: \(response.statusCode)\n"
            }
            if let error = self.error {
                message += "error: \(error.localizedDescription)\n"
            }
            if let data = self.data {
                do {
                    if let prettyPrintedJSON = String(
                        data: try JSONSerialization.data(
                            withJSONObject: try JSONSerialization.jsonObject(with: data),
                            options: .prettyPrinted),
                        encoding: .utf8) {
                        message += "data: \(prettyPrintedJSON)\n"
                    }
                } catch {
                    Logger.shared.error(error)
                }
            }
            message += "------ END"
            return message
        })
    }
}
