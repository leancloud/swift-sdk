//
//  Engine.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 5/10/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

public final class Engine {
    typealias Parameters = [String: AnyObject]

    /**
     Call LeanEngine function.

     - parameter function: The function name to be called.

     - returns: The result of function call.
     */
    public static func call<Value: LCType>(function: String) -> OptionalResult<Value> {
        return call(function, parameters: nil)
    }

    /**
     Call LeanEngine function with parameters.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - returns: The result of function all.
     */
    public static func call<Value: LCType>(function: String, parameters: [String: AnyObject]) -> OptionalResult<Value> {
        return call(function, parameters: ObjectProfiler.JSONValue(parameters) as? Parameters)
    }

    /**
     Call LeanEngine function with parameters.

     The parameters will be serialized to JSON representation.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - returns: The result of function all.
     */
    public static func call<Value: LCType>(function: String, parameters: LCDictionary) -> OptionalResult<Value> {
        return call(function, parameters: ObjectProfiler.JSONValue(parameters) as? Parameters)
    }

    /**
     Call LeanEngine function with parameters.

     The parameters will be serialized to JSON representation.

     - parameter function:   The function name.
     - parameter parameters: The parameters to be passed to remote function.

     - returns: The result of function all.
     */
    public static func call<Value: LCType>(function: String, parameters: LCObject) -> OptionalResult<Value> {
        return call(function, parameters: ObjectProfiler.JSONValue(parameters) as? Parameters)
    }

    /**
     Call LeanEngine function with parameters.

     - parameter function:   The function name.
     - parameter parameters: The JSON parameters to be passed to remote function.

     - returns: The result of function call.
     */
    static func call<Value: LCType>(function: String, parameters: Parameters?) -> OptionalResult<Value> {
        let response = RESTClient.request(.POST, "call/\(function)", parameters: parameters)

        return response.optionalResult("result")
    }
}