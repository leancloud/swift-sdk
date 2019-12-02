//
//  EngineClient.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2019/7/4.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import Foundation

/// LeanCloud Cloud Engine Client
public class LCEngine {
    
    /// Call the cloud function synchronously.
    /// - Parameters:
    ///   - application: The application.
    ///   - function: The name of the function in the cloud.
    ///   - parameters: The parameters passing to the function in the cloud.
    public static func run(
        application: LCApplication = .default,
        _ function: String,
        parameters: [String: Any]? = nil)
        -> LCGenericResult<Any>
    {
        return expect { (fulfill) in
            self.run(
                application: application,
                function: function,
                parameters: parameters,
                completionInBackground: { (result) in
                    fulfill(result)
            })
        }
    }
    
    /// Call the cloud function asynchronously.
    /// - Parameters:
    ///   - application: The application.
    ///   - function: The name of the function in the cloud.
    ///   - parameters: The parameters passing to the function in the cloud.
    ///   - completionQueue: The queue where the `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func run(
        application: LCApplication = .default,
        _ function: String,
        parameters: [String: Any]? = nil,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCGenericResult<Any>) -> Void)
        -> LCRequest
    {
        return self.run(
            application: application,
            function: function,
            parameters: parameters,
            completionInBackground: { (result) in
                completionQueue.async {
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
        return application.httpClient.request(
            .post, "functions/\(function)",
            parameters: parameters)
        { (response) in
            if let error: Error = LCError(response: response) {
                completion(.failure(error: LCError(error: error)))
            } else {
                if let result: Any = response["result"] {
                    completion(.success(value: result))
                } else {
                    completion(.failure(
                        error: LCError(
                            code: .invalidType,
                            reason: "invalid response data type.")))
                }
            }
        }
    }
    
    /// RPC call the cloud function synchronously.
    /// - Parameters:
    ///   - application: The application.
    ///   - function: The name of the function in the cloud.
    ///   - parameters: The parameters passing to the function in the cloud.
    public static func call(
        application: LCApplication = .default,
        _ function: String,
        parameters: LCDictionaryConvertible? = nil)
        -> LCValueOptionalResult
    {
        return expect { (fulfill) in
            self.call(
                application: application,
                function: function,
                parameters: parameters,
                completionInBackground: { (result) in
                    fulfill(result)
            })
        }
    }
    
    /// RPC call the cloud function asynchronously.
    /// - Parameters:
    ///   - application: The application.
    ///   - function: The name of the function in the cloud.
    ///   - parameters: The parameters passing to the function in the cloud.
    ///   - completionQueue: The queue where the `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func call(
        application: LCApplication = .default,
        _ function: String,
        parameters: LCDictionaryConvertible? = nil,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCValueOptionalResult) -> Void)
        -> LCRequest
    {
        return self.call(
            application: application,
            function: function,
            parameters: parameters,
            completionInBackground: { (result) in
                completionQueue.async {
                    completion(result)
                }
        })
    }
    
    /// RPC call the cloud function synchronously.
    /// - Parameters:
    ///   - application: The application.
    ///   - function: The name of the function in the cloud.
    ///   - parameters: The parameters passing to the function in the cloud.
    public static func call(
        application: LCApplication = .default,
        _ function: String,
        parameters: LCObject)
        -> LCValueOptionalResult
    {
        let dictionary = LCDictionary(parameters.dictionary)
        dictionary.removeValue(forKey: "__type")
        dictionary.removeValue(forKey: "className")
        return self.call(
            application: application,
            function,
            parameters: dictionary)
    }
    
    /// RPC call the cloud function asynchronously.
    /// - Parameters:
    ///   - application: The application.
    ///   - function: The name of the function in the cloud.
    ///   - parameters: The parameters passing to the function in the cloud.
    ///   - completionQueue: The queue where the `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func call(
        application: LCApplication = .default,
        _ function: String,
        parameters: LCObject,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCValueOptionalResult) -> Void)
        -> LCRequest
    {
        let dictionary = LCDictionary(parameters.dictionary)
        dictionary.removeValue(forKey: "__type")
        dictionary.removeValue(forKey: "className")
        return self.call(
            application: application,
            function,
            parameters: dictionary,
            completionQueue: completionQueue,
            completion: completion)
    }
    
    @discardableResult
    private static func call(
        application: LCApplication,
        function: String,
        parameters: LCDictionaryConvertible?,
        completionInBackground completion: @escaping (LCValueOptionalResult) -> Void)
        -> LCRequest
    {
        return application.httpClient.request(
            .post, "call/\(function)",
            parameters: parameters?.lcDictionary.lconValue as? [String: Any])
        { response in
            completion(LCValueOptionalResult(
                response: response,
                keyPath: "result"))
        }
    }
}
