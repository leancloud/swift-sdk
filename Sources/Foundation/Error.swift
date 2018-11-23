//
//  Error.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/26/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

public struct LCError: Error {
    public typealias UserInfo = [String: Any]

    public let code: Int
    public let reason: String?
    public let userInfo: UserInfo?

    /// Underlying error.
    public private(set) var underlyingError: Error?

    enum InternalErrorCode: Int {
        case notFound           = 9973
        case invalidType        = 9974
        case malformedData      = 9975
        case inconsistency      = 9976
        case underlyingError    = 9977
    }

    enum ServerErrorCode: Int {
        case objectNotFound = 101
    }

    /**
     Convert an error to LCError.

     - parameter error: The error to be converted.
     */
    init(error: Error) {
        if let error = error as? LCError {
            self = error
        } else {
            self = LCError(error: error as NSError)
        }
    }

    /**
     Initialize with a NSError object.

     - parameter error: The NSError object.
     */
    init(error: NSError) {
        self.code = error.code
        self.reason = error.localizedDescription
        self.userInfo = error.userInfo
    }

    /**
     Initialize with an LCResponse object.

     - parameter response: The response object.
     */
    init?(response: LCResponse) {
        /*
         Guard response has error.
         If error not found, it means that the response is OK, there's no need to create error.
         */
        guard let error = response.error else {
            return nil
        }

        guard let data = response.data else {
            self = LCError(underlyingError: error)
            return
        }

        let body: Any

        do {
            body = try JSONSerialization.jsonObject(with: data, options: [])
        } catch
            /*
             We discard the deserialization error,
             because it's not the real error that user should care about.
             */
            _
        {
            self = LCError(underlyingError: error)
            return
        }

        /*
         Try to extract error from HTTP body,
         which contains the error defined in https://leancloud.cn/docs/error_code.html
         */
        if
            let body = body as? [String: Any],
            let code = body["code"] as? Int,
            let reason = body["error"] as? String
        {
            self = LCError(code: code, reason: reason, userInfo: nil)
        } else {
            self = LCError(underlyingError: error)
        }
    }

    init(code: Int, reason: String? = nil, userInfo: UserInfo? = nil) {
        self.code = code
        self.reason = reason
        self.userInfo = userInfo
    }

    init(code: InternalErrorCode, reason: String? = nil, userInfo: UserInfo? = nil) {
        self = LCError(code: code.rawValue, reason: reason, userInfo: userInfo)
    }

    init(code: ServerErrorCode, reason: String? = nil, userInfo: UserInfo? = nil) {
        self = LCError(code: code.rawValue, reason: reason, userInfo: userInfo)
    }

    init(dictionary: [String: Any]) {
        code = dictionary["code"] as? Int ?? 0
        reason = dictionary["error"] as? String
        userInfo = dictionary
    }

    /**
     Initialize with underlying error.

     - parameter underlyingError: The underlying error.
     */
    init(underlyingError: Error) {
        var error = LCError(code: .underlyingError, reason: nil, userInfo: nil)
        error.underlyingError = underlyingError
        self = error
    }
}

extension LCError: LocalizedError {

    public var failureReason: String? {
        return reason ?? underlyingError?.localizedDescription
    }

}

extension LCError: CustomNSError {

    public static var errorDomain: String {
        return String(describing: self)
    }

    public var errorUserInfo: [String : Any] {
        if let userInfo = userInfo {
            return userInfo
        } else if let underlyingError = underlyingError {
            return (underlyingError as NSError).userInfo
        } else {
            return [:]
        }
    }

    public var errorCode: Int {
        return code
    }

}
