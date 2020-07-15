//
//  PushClient.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2019/7/9.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import Foundation

/// LeanCloud Push Client
public class LCPush {
    
    /// Send push notification synchronously.
    /// - Parameters:
    ///   - application: The application, default is `LCApplication.default`.
    ///   - data: The body data of the push message.
    ///   - query: The query condition, if this parameter be set, then `channels` will be ignored.
    ///   - channels: The channels condition, if `query` be set, then this parameter will be ignored.
    ///   - pushDate: The date when to send.
    ///   - expirationDate: The expiration date of this push notification.
    ///   - expirationInterval: The expiration interval from `pushDate` of this push notification.
    ///   - extraParameters: The extra parameters, for some specific configuration.
    /// - Returns: Boolean result, see `LCBooleanResult`.
    public static func send(
        application: LCApplication = .default,
        data: [String: Any],
        query: LCQuery? = nil,
        channels: [String]? = nil,
        pushDate: Date? = nil,
        expirationDate: Date? = nil,
        expirationInterval: TimeInterval? = nil,
        extraParameters: [String: Any]? = nil)
        -> LCBooleanResult
    {
        return expect { (fulfill) in
            self.send(
                application: application,
                data: data,
                query: query,
                channels: channels,
                pushDate: pushDate,
                expirationDate: expirationDate,
                expirationInterval: expirationInterval,
                extraParameters: extraParameters,
                completionInBackground: { (result) in
                    fulfill(result)
            })
        }
    }
    
    /// Send push notification asynchronously.
    /// - Parameters:
    ///   - application: The application, default is `LCApplication.default`.
    ///   - data: The body data of the push message.
    ///   - query: The query condition, if this parameter be set, then `channels` will be ignored.
    ///   - channels: The channels condition, if `query` be set, then this parameter will be ignored.
    ///   - pushDate: The date when to send.
    ///   - expirationDate: The expiration date of this push notification.
    ///   - expirationInterval: The expiration interval from `pushDate` of this push notification.
    ///   - extraParameters: The extra parameters, for some specific configuration.
    ///   - completionQueue: The queue where `completion` be called.
    ///   - completion: The result callback.
    /// - Returns: The request, see `LCRequest`.
    @discardableResult
    public static func send(
        application: LCApplication = .default,
        data: [String: Any],
        query: LCQuery? = nil,
        channels: [String]? = nil,
        pushDate: Date? = nil,
        expirationDate: Date? = nil,
        expirationInterval: TimeInterval? = nil,
        extraParameters: [String: Any]? = nil,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.send(
            application: application,
            data: data,
            query: query,
            channels: channels,
            pushDate: pushDate,
            expirationDate: expirationDate,
            expirationInterval: expirationInterval,
            extraParameters: extraParameters,
            completionInBackground: { (result) in
                completionQueue.async {
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
        extraParameters: [String: Any]?,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        var parameters: [String: Any] = [
            "prod": application.pushMode,
            "data": data,
        ]
        if let query = query {
            if let lconWhere = query.lconWhere {
                parameters["where"] = lconWhere
            }
        } else if let channels = channels {
            parameters["channels"] = channels
        }
        if let pushDate = pushDate {
            parameters["push_time"] = LCDate.stringFromDate(pushDate)
        }
        if let expirationDate = expirationDate {
            parameters["expiration_time"] = LCDate.stringFromDate(expirationDate)
        }
        if let expirationInterval = expirationInterval {
            if pushDate == nil {
                parameters["push_time"] = LCDate().isoString
            }
            parameters["expiration_interval"] = expirationInterval
        }
        if let extraParameters = extraParameters {
            parameters.merge(extraParameters) { (current, _) in current }
        }
        return application.httpClient.request(
            .post, "push",
            parameters: parameters) { (response) in
                completion(LCBooleanResult(response: response))
        }
    }
}
