//
//  Push.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2019/7/9.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import Foundation

public class LCPush {
    
    /// send push notification synchronously
    ///
    /// - Parameters:
    ///   - application: The application
    ///   - data: The data of the push message
    ///   - query: The query condition, if this parameter be set, then `channels` will be ignored
    ///   - channels: The channels condition, if `query` be set, then this parameter will be ignored
    ///   - pushDate: The date of sending
    ///   - expirationDate: The date of expiration
    ///   - expirationInterval: If time interval since sending date is greater then this parameter, then the push expired
    /// - Returns: Result
    public static func send(
        application: LCApplication = LCApplication.default,
        data: [String: Any],
        query: LCQuery? = nil,
        channels: [String]? = nil,
        pushDate: Date? = nil,
        expirationDate: Date? = nil,
        expirationInterval: TimeInterval? = nil)
        -> LCBooleanResult
    {
        return expect { (fulfill) in
            self.send(application: application, data: data, query: query, channels: channels, pushDate: pushDate, expirationDate: expirationDate, expirationInterval: expirationInterval, completionInBackground: { (result) in
                fulfill(result)
            })
        }
    }
    
    /// send push notification asynchronously
    ///
    /// - Parameters:
    ///   - application: The application
    ///   - data: The data of the push message
    ///   - query: The query condition, if this parameter be set, then `channels` will be ignored
    ///   - channels: The channels condition, if `query` be set, then this parameter will be ignored
    ///   - pushDate: The date of sending
    ///   - expirationDate: The date of expiration
    ///   - expirationInterval: If time interval since sending date is greater then this parameter, then the push expired
    ///   - completion: The callback of the result
    /// - Returns: Request
    @discardableResult
    public static func send(
        application: LCApplication = LCApplication.default,
        data: [String: Any],
        query: LCQuery? = nil,
        channels: [String]? = nil,
        pushDate: Date? = nil,
        expirationDate: Date? = nil,
        expirationInterval: TimeInterval? = nil,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.send(application: application, data: data, query: query, channels: channels, pushDate: pushDate, expirationDate: expirationDate, expirationInterval: expirationInterval, completionInBackground: { (result) in
            mainQueueAsync {
                completion(result)
            }
        })
    }
    
    @discardableResult
    private static func send(
        application: LCApplication,
        data: [String: Any],
        query: LCQuery?,
        channels: [String]?,
        pushDate: Date?,
        expirationDate: Date?,
        expirationInterval: TimeInterval?,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let httpClient: HTTPClient = application.httpClient
        
        var parameters: [String: Any] = [
            "prod": (application.configuration.environment.contains(.pushDevelopment) ? "dev" : "prod"),
            "data": data
        ]
        if let query: LCQuery = query {
            parameters.merge(query.lconValue) { (current, _) in current }
        } else if let channels: [String] = channels {
            parameters["channels"] = channels
        }
        if let pushDate: Date = pushDate {
            parameters["push_time"] = LCDate.stringFromDate(pushDate)
        }
        if let expirationDate: Date = expirationDate {
            parameters["expiration_time"] = LCDate.stringFromDate(expirationDate)
        }
        if let expirationInterval: TimeInterval = expirationInterval {
            if pushDate == nil {
                parameters["push_time"] = LCDate.stringFromDate(Date())
            }
            parameters["expiration_interval"] = expirationInterval
        }
        
        let request = httpClient.request(.post, "push", parameters: parameters) { (response) in
            completion(LCBooleanResult(response: response))
        }
        
        return request
    }
    
}
