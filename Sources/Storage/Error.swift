//
//  Error.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/26/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation
import Alamofire

public struct LCError: Error {
    public typealias UserInfo = [AnyHashable: Any]

    public var code: Int = 0
    public var reason: String?
    public var userInfo: UserInfo?

    public var underlyingError: Error?

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

    init(error: Error) {
        underlyingError = error

        switch error {
        case let error as NSError:
            code = error.code
            reason = error.localizedFailureReason
            userInfo = error.userInfo
        default:
            break
        }
    }
}
