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

    public var code: Int = 0
    public var reason: String?
    public var userInfo: UserInfo?

    enum InternalErrorCode: Int {
        case notFound      = 9973
        case invalidType   = 9974
        case malformedData = 9975
        case inconsistency = 9976
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

    init(dictionary: [String: AnyObject]) {
        code = dictionary["code"] as? Int ?? 0
        reason = dictionary["error"] as? String
        userInfo = dictionary
    }
}

extension LCError: LocalizedError {

    public var failureReason: String? {
        return reason
    }

}

extension LCError: CustomNSError {

    public static var errorDomain: String {
        return String(describing: self)
    }

    public var errorUserInfo: [String : Any] {
        return userInfo ?? [:]
    }

    public var errorCode: Int {
        return code
    }

}
