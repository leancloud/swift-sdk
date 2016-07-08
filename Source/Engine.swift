//
//  Engine.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 5/10/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

public final class LCEngine {
    typealias Parameters = [String: AnyObject]

    /// The dispatch queue for network request task.
    static let backgroundQueue = dispatch_queue_create("LeanCloud.Engine", DISPATCH_QUEUE_CONCURRENT)

    /**
     Asynchronize task into background queue.

     - parameter task:       The task to be performed.
     - parameter completion: The completion closure to be called on main thread after task finished.
     */
    static func asynchronize<Result>(task: () -> Result, completion: (Result) -> Void) {
        Utility.asynchronize(task, backgroundQueue, completion)
    }

    /**
     Call LeanEngine function.

     - parameter function: The function name to be called.

     - returns: The result of function call.
     */
    public static func call<Value: LCType>(function: String) -> LCOptionalResult<Value> {
        return call(function, parameters: nil)
    }

    /**
     Call LeanEngine function.

     - parameter completion: The completion callback closure.
     */
    public static func call<Value: LCType>(function: String, completion: (LCOptionalResult<Value>) -> Void) {
        asynchronize({ call(function) }) { result in
            completion(result)
        }
    }

    /**
     Call LeanEngine function with parameters.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - returns: The result of function all.
     */
    public static func call<Value: LCType>(function: String, parameters: [String: AnyObject]) -> LCOptionalResult<Value> {
        return call(function, parameters: ObjectProfiler.JSONValue(parameters) as? Parameters)
    }

    /**
     Call LeanEngine function with parameters asynchronously.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - parameter completion: The completion callback closure.
     */
    public static func call<Value: LCType>(function: String, parameters: [String: AnyObject], completion: (LCOptionalResult<Value>) -> Void) {
        asynchronize({ call(function, parameters: parameters) }) { result in
            completion(result)
        }
    }

    /**
     Call LeanEngine function with parameters.

     The parameters will be serialized to JSON representation.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - returns: The result of function all.
     */
    public static func call<Value: LCType>(function: String, parameters: LCDictionary) -> LCOptionalResult<Value> {
        return call(function, parameters: ObjectProfiler.JSONValue(parameters) as? Parameters)
    }

    /**
     Call LeanEngine function with parameters asynchronously.

     The parameters will be serialized to JSON representation.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - parameter completion: The completion callback closure.
     */
    public static func call<Value: LCType>(function: String, parameters: LCDictionary, completion: (LCOptionalResult<Value>) -> Void) {
        asynchronize({ call(function, parameters: parameters) }) { result in
            completion(result)
        }
    }

    /**
     Call LeanEngine function with parameters.

     The parameters will be serialized to JSON representation.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - returns: The result of function all.
     */
    public static func call<Value: LCType>(function: String, parameters: LCObject) -> LCOptionalResult<Value> {
        return call(function, parameters: ObjectProfiler.JSONValue(parameters) as? Parameters)
    }

    /**
     Call LeanEngine function with parameters asynchronously.

     The parameters will be serialized to JSON representation.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - parameter completion: The completion callback closure.
     */
    public static func call<Value: LCType>(function: String, parameters: LCObject, completion: (LCOptionalResult<Value>) -> Void) {
        asynchronize({ call(function, parameters: parameters) }) { result in
            completion(result)
        }
    }

    /**
     Call LeanEngine function with parameters.

     - parameter function:   The function name.
     - parameter parameters: The JSON parameters to be passed to remote function.

     - returns: The result of function call.
     */
    static func call<Value: LCType>(function: String, parameters: Parameters?) -> LCOptionalResult<Value> {
        let response = RESTClient.request(.POST, "call/\(function)", parameters: parameters)

        return response.optionalResult("result")
    }
}