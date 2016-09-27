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
open class LCCQLValue {
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
    open var objects: [LCObject] {
        let results   = self.results
        let className = self.className

        return results.map { dictionary in
            ObjectProfiler.object(dictionary: dictionary, className: className)
        }
    }

    /**
     Get count value for count query.
     */
    open var count: Int {
        return response.count
    }
}

/**
 CQL client.

 CQLClient allow you to use CQL (Cloud Query Language) to make CRUD for object.
 */
open class LCCQLClient {
    static let endpoint = "cloudQuery"

    /// The dispatch queue for asynchronous CQL execution task.
    static let backgroundQueue = DispatchQueue(label: "LeanCloud.CQLClient", attributes: .concurrent)

    /**
     Asynchronize task into background queue.

     - parameter task:       The task to be performed.
     - parameter completion: The completion closure to be called on main thread after task finished.
     */
    static func asynchronize(_ task: @escaping () -> LCCQLResult, completion: @escaping (LCCQLResult) -> Void) {
        Utility.asynchronize(task, backgroundQueue, completion)
    }

    /**
     Assemble parameters for CQL execution.

     - parameter cql:        The CQL statement.
     - parameter parameters: The parameters for placeholders in CQL statement.

     - returns: The parameters for CQL execution.
     */
    static func parameters(_ cql: String, parameters: LCArrayConvertible?) -> [String: AnyObject] {
        var result = ["cql": cql]

        if let parameters = parameters?.lcArray {
            if !parameters.isEmpty {
                result["pvalues"] = Utility.jsonString(parameters.lconValue!)
            }
        }

        return result as [String : AnyObject]
    }

    /**
     Execute CQL statement synchronously.

     - parameter cql:        The CQL statement to be executed.
     - parameter parameters: The parameters for placeholders in CQL statement.

     - returns: The result of CQL statement.
     */
    open static func execute(_ cql: String, parameters: LCArrayConvertible? = nil) -> LCCQLResult {
        let parameters = self.parameters(cql, parameters: parameters)
        let response   = RESTClient.request(.get, endpoint, parameters: parameters)

        return LCCQLResult(response: response)
    }

    /**
     Execute CQL statement asynchronously.

     - parameter cql:        The CQL statement to be executed.
     - parameter parameters: The parameters for placeholders in CQL statement.
     - parameter completion: The completion callback closure.
     */
    open static func execute(_ cql: String, parameters: LCArrayConvertible? = nil, completion: @escaping (_ result: LCCQLResult) -> Void) {
        asynchronize({ execute(cql, parameters: parameters) }) { result in
            completion(result)
        }
    }
}
