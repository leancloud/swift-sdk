//
//  Error.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/26/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

public struct LCError: ErrorType {
    public typealias UserInfo = [NSObject: AnyObject]

    public let code: Int
    public let reason: String?
    public let userInfo: UserInfo?

    enum InternalErrorCode: Int {
        case NotFound      = 9973
        case InvalidType   = 9974
        case MalformedData = 9975
    }

    enum ServerErrorCode: Int {
        case ObjectNotFound = 101
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

    init(error: NSError) {
        code = error.code
        reason = error.localizedFailureReason
        userInfo = error.userInfo
    }
}