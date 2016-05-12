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

    public static func call<Value: LCType>(function: String) -> OptionalObjectResult<Value> {
        return call(function, parameters: nil)
    }

    public static func call<Value: LCType>(function: String, parameters: LCDictionary) -> OptionalObjectResult<Value> {
        return call(function, parameters: ObjectProfiler.JSONValue(parameters) as? Parameters)
    }

    public static func call<Value: LCType>(function: String, parameters: LCObject) -> OptionalObjectResult<Value> {
        return call(function, parameters: ObjectProfiler.JSONValue(parameters) as? Parameters)
    }

    static func call<Value: LCType>(function: String, parameters: Parameters?) -> OptionalObjectResult<Value> {
        let response = RESTClient.request(.POST, "call/\(function)", parameters: parameters)

        return response.engineResult()
    }
}