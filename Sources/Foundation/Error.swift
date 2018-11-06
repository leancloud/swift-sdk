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
