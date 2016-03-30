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

    /// REST API version.
    static let APIVersion = "1.1"

    /// REST client shared instance.
    static let sharedInstance = RESTClient()

    /// Request dispatch queue.
    static let queue = dispatch_queue_create("LeanCloud.REST", DISPATCH_QUEUE_CONCURRENT)

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
    func URLString(endpoint: String) -> String {
        return "https://\(RESTClient.host)/\(RESTClient.APIVersion)/\(endpoint)"
    }

    /**
     Creates a request to REST API and sends it asynchronously.

     - parameter method:            The HTTP Method.
     - parameter endpoint:          The REST API endpoint.
     - parameter parameters:        The request parameters.
     - parameter completionHandler: The completion handler.

     - returns: A request object.
     */
    func request(
        method: Method,
        endpoint: String,
        parameters: [String: AnyObject]? = nil,
        handler: (Response) -> Void)
        -> Request
    {
        let URLString = self.URLString(endpoint)
        let request = Alamofire.request(method.alamofireMethod, URLString, parameters: parameters)

        request.responseJSON(queue: RESTClient.queue) { response in
            handler(Response(response))
        }

        return Request(request)
    }
}