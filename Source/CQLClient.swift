//
//  CQLClient.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 5/30/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 A type represents the result value of CQL execution.
 */
public class LCCQLValue {
    let response: LCResponse

    init(response: LCResponse) {
        self.response = response
    }

    var results: [[String: AnyObject]] {
        return (response.results as? [[String: AnyObject]]) ?? []
    }

    var className: String {
        return (response["className"] as? String) ?? LCObject.objectClassName()
    }

    /**
     Get objects for object query.
     */
    public var objects: [LCObject] {
        let results   = self.results
        let className = self.className

        return results.map { dictionary in
            ObjectProfiler.object(dictionary: dictionary, className: className)
        }
    }

    /**
     Get count value for count query.
     */
    public var count: Int {
        return response.count
    }
}

/**
 CQL client.

 CQLClient allow you to use CQL (Cloud Query Language) to make CRUD for object.
 */
public class LCCQLClient {
    static let endpoint = "cloudQuery"

    /// The dispatch queue for asynchronous CQL execution task.
    static let backgroundQueue = dispatch_queue_create("LeanCloud.CQLClient", DISPATCH_QUEUE_CONCURRENT)

    /**
     Asynchronize task into background queue.

     - parameter task:       The task to be performed.
     - parameter completion: The completion closure to be called on main thread after task finished.
     */
    static func asynchronize<Result>(task: () -> Result, completion: (Result) -> Void) {
        Utility.asynchronize(task, backgroundQueue, completion)
    }

    /**
     Assemble parameters for CQL execution.

     - parameter CQL:        The CQL statement.
     - parameter parameters: The parameters for placeholders in CQL statement.

     - returns: The parameters for CQL execution.
     */
    static func parameters(CQL: String, parameters: [AnyObject]) -> [String: AnyObject] {
        var result = ["cql": CQL]

        if !parameters.isEmpty {
            result["pvalues"] = Utility.JSONString(ObjectProfiler.JSONValue(parameters))
        }

        return result
    }

    /**
     Execute CQL statement synchronously.

     - parameter CQL:        The CQL statement to be executed.
     - parameter parameters: The parameters for placeholders in CQL statement.

     - returns: The result of CQL statement.
     */
    public static func execute(CQL: String, parameters: [AnyObject] = []) -> LCCQLResult {
        let parameters = self.parameters(CQL, parameters: parameters)
        let response   = RESTClient.request(.GET, endpoint, parameters: parameters)

        return LCCQLResult(response: response)
    }

    /**
     Execute CQL statement asynchronously.

     - parameter CQL:        The CQL statement to be executed.
     - parameter parameters: The parameters for placeholders in CQL statement.
     - parameter completion: The completion callback closure.
     */
    public static func execute(CQL: String, parameters: [AnyObject] = [], completion: (result: LCCQLResult) -> Void) {
        asynchronize({ execute(CQL, parameters: parameters) }) { result in
            completion(result: result)
        }
    }
}