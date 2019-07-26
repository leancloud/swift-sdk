//
//  Engine.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2019/7/4.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import Foundation

public class LCEngine {
    
    /// call the cloud function synchronously
    ///
    /// - Parameters:
    ///   - application: The application
    ///   - function: The name of the function in the cloud
    ///   - parameters: The parameters of the function
    /// - Returns: The result of the function
    public static func run(
        application: LCApplication = LCApplication.default,
        _ function: String,
        parameters: [String: Any]? = nil)
        -> LCGenericResult<Any>
    {
        return expect { (fulfill) in
            self.run(application: application, function: function, parameters: parameters, completionInBackground: { (result) in
                fulfill(result)
            })
        }
    }
    
    /// call the cloud function asynchronously
    ///
    /// - Parameters:
    ///   - application: The application
    ///   - function: The name of the function in the cloud
    ///   - parameters: The parameters of the function
    ///   - completion: The result of the callback
    /// - Returns: The Request
    @discardableResult
    public static func run(
        application: LCApplication = LCApplication.default,
        _ function: String,
        parameters: [String: Any]? = nil,
        completion: @escaping (LCGenericResult<Any>) -> Void)
        -> LCRequest
    {
        return self.run(application: application, function: function, parameters: parameters, completionInBackground: { (result) in
            mainQueueAsync {
                completion(result)
            }
        })
    }
    
    @discardableResult
    private static func run(
        application: LCApplication,
        function: String,
        parameters: [String: Any]?,
        completionInBackground completion: @escaping (LCGenericResult<Any>) -> Void)
        -> LCRequest
    {
        let httpClient: HTTPClient = application.httpClient
        
        let request = httpClient.request(.post, "functions/\(function)", parameters: parameters) { (response) in
            if let error: Error = LCError(response: response) {
                completion(.failure(error: LCError(error: error)))
            } else {
                if let value = response.value as? [String: Any], let result = value["result"] {
                    completion(.success(value: result))
                } else {
                    let error = LCError(code: .invalidType, reason: "invalid response data type.")
                    completion(.failure(error: error))
                }
            }
        }
        
        return request
    }
    
    /// call the cloud function by RPC synchronously
    ///
    /// - Parameters:
    ///   - application: The application
    ///   - function: The name of the function in the cloud
    ///   - parameters: The parameters of the function
    /// - Returns: The result of the function
    public static func call(
        application: LCApplication = LCApplication.default,
        _ function: String,
        parameters: LCDictionaryConvertible? = nil)
        -> LCValueOptionalResult
    {
        return expect { (fulfill) in
            self.call(application: application, function: function, parameters: parameters, completionInBackground: { (result) in
                fulfill(result)
            })
        }
    }
    
    /// call the cloud function by RPC asynchronously
    ///
    /// - Parameters:
    ///   - application: The application
    ///   - function: The name of the function in the cloud
    ///   - parameters: The parameters of the function
    ///   - completion: The result of the callback
    /// - Returns: The Request
    @discardableResult
    public static func call(
        application: LCApplication = LCApplication.default,
        _ function: String,
        parameters: LCDictionaryConvertible? = nil,
        completion: @escaping (LCValueOptionalResult) -> Void)
        -> LCRequest
    {
        return self.call(application: application, function: function, parameters: parameters, completionInBackground: { (result) in
            mainQueueAsync {
                completion(result)
            }
        })
    }
    
    /// call the cloud function by RPC synchronously
    ///
    /// - Parameters:
    ///   - application: The application
    ///   - function: The name of the function in the cloud
    ///   - parameters: The parameters of the function
    /// - Returns: The result of the function
    public static func call(
        application: LCApplication = LCApplication.default,
        _ function: String,
        parameters: LCObject)
        -> LCValueOptionalResult
    {
        return self.call(application: application, function, parameters: parameters.dictionary)
    }
    
    /// call the cloud function by RPC asynchronously
    ///
    /// - Parameters:
    ///   - application: The application
    ///   - function: The name of the function in the cloud
    ///   - parameters: The parameters of the function
    ///   - completion: The result of the callback
    /// - Returns: The Request
    public static func call(
        application: LCApplication = LCApplication.default,
        _ function: String,
        parameters: LCObject,
        completion: @escaping (LCValueOptionalResult) -> Void)
        -> LCRequest
    {
        return self.call(application: application, function, parameters: parameters.dictionary, completion: completion)
    }
    
    @discardableResult
    private static func call(
        application: LCApplication,
        function: String,
        parameters: LCDictionaryConvertible?,
        completionInBackground completion: @escaping (LCValueOptionalResult) -> Void)
        -> LCRequest
    {
        let parameters = parameters?.lcDictionary.lconValue as? [String: Any]
        
        let request = application.httpClient.request(.post, "call/\(function)", parameters: parameters) { response in
            let result = LCValueOptionalResult(response: response, keyPath: "result")
            completion(result)
        }
        
        return request
    }
    
}
