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
public final class LCCQLValue {
    let count: Int

    let objects: [LCObject]

    init(response: LCResponse) {
        var objects: [LCObject] = []

        if
            let application = response.application,
            let results = response["results"] as? [[String: AnyObject]]
        {
            let className = (response["className"] as? String) ?? LCObject.objectClassName()
            do {
                objects = try results.map { dictionary in
                    try ObjectProfiler.object(dictionary: dictionary, className: className, application: application)
                }
            } catch {
                objects = []
            }
        }

        self.objects = objects

        if let count = response["count"] as? Int {
            self.count = count
        } else {
            self.count = objects.count
        }
    }
}

/**
 CQL client.

 CQLClient allow you to use CQL (Cloud Query Language) to make CRUD for object.
 */
public final class LCCQLClient {
    /// Application
    public let application: LCApplication

    private lazy var httpClient: HTTPClient = {
        return HTTPClient(application: application)
    }()

    init(application: LCApplication = .current ?? .shared) {
        self.application = application
    }

    let endpoint = "cloudQuery"

    /// The dispatch queue for asynchronous CQL execution task.
    let backgroundQueue = DispatchQueue(label: "LeanCloud.CQLClient", attributes: .concurrent)

    /**
     Asynchronize task into background queue.

     - parameter task:       The task to be performed.
     - parameter completion: The completion closure to be called on main thread after task finished.
     */
    func asynchronize(_ task: @escaping () -> LCCQLResult, completion: @escaping (LCCQLResult) -> Void) {
        Utility.asynchronize(task, backgroundQueue, completion)
    }

    /**
     Assemble parameters for CQL execution.

     - parameter cql:        The CQL statement.
     - parameter parameters: The parameters for placeholders in CQL statement.

     - returns: The parameters for CQL execution.
     */
    func parameters(_ cql: String, parameters: LCArrayConvertible?) -> [String: AnyObject] {
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
    public func execute(_ cql: String, parameters: LCArrayConvertible? = nil) -> LCCQLResult {
        let parameters = self.parameters(cql, parameters: parameters)
        let response   = httpClient.request(.get, endpoint, parameters: parameters)

        return LCCQLResult(response: response)
    }

    /**
     Execute CQL statement asynchronously.

     - parameter cql:        The CQL statement to be executed.
     - parameter parameters: The parameters for placeholders in CQL statement.
     - parameter completion: The completion callback closure.
     */
    public func execute(_ cql: String, parameters: LCArrayConvertible? = nil, completion: @escaping (_ result: LCCQLResult) -> Void) {
        asynchronize({ self.execute(cql, parameters: parameters) }) { result in
            completion(result)
        }
    }
}
