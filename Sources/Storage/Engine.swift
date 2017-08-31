//
//  Engine.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 5/10/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

public final class LCEngine {
    /// The dispatch queue for network request task.
    static let backgroundQueue = DispatchQueue(label: "LeanCloud.Engine", attributes: .concurrent)

    /**
     Asynchronize task into background queue.

     - parameter task:       The task to be performed.
     - parameter completion: The completion closure to be called on main thread after task finished.
     */
    static func asynchronize<Result>(_ task: @escaping () -> Result, completion: @escaping (Result) -> Void) {
        Utility.asynchronize(task, backgroundQueue, completion)
    }

    /**
     Call LeanEngine function with parameters.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - returns: The result of function call.
     */
    public static func call(_ function: String, parameters: LCDictionaryConvertible? = nil) -> LCOptionalResult {
        let parameters = parameters?.lcDictionary.lconValue as? [String: AnyObject]
        let response   = RESTClient.request(.post, "call/\(function)", parameters: parameters)

        return response.optionalResult("result")
    }

    /**
     Call LeanEngine function with parameters asynchronously.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - parameter completion: The completion callback closure.
     */
    public static func call(_ function: String, parameters: LCDictionaryConvertible? = nil, completion: @escaping (LCOptionalResult) -> Void) {
        asynchronize({ call(function, parameters: parameters) }) { result in
            completion(result)
        }
    }

    /**
     Call LeanEngine function with parameters.

     The parameters will be serialized to JSON representation.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - returns: The result of function call.
     */
    public static func call(_ function: String, parameters: LCObject) -> LCOptionalResult {
        return call(function, parameters: parameters.dictionary)
    }

    /**
     Call LeanEngine function with parameters asynchronously.

     The parameters will be serialized to JSON representation.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - parameter completion: The completion callback closure.
     */
    public static func call(_ function: String, parameters: LCObject, completion: @escaping (LCOptionalResult) -> Void) {
        asynchronize({ call(function, parameters: parameters) }) { result in
            completion(result)
        }
    }
}
