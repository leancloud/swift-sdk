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

    /// ref: https://github.com/leancloud/paas/wiki/SDK-Internal-Error-Definition
    enum InternalErrorCode: Int {
        // session/client
        case commandTimeout             = 9000
        case connectionLost             = 9001
        case clientNotOpen              = 9002
        case commandInvalid             = 9003
        case commandDataLengthTooLong   = 9008
        // conversation
        case conversationNotFound       = 9100
        case updatingMessageNotAllowed  = 9120
        case updatingMessageNotSent     = 9121
        case ownerPromotionNotAllowed   = 9130
        // other
        case notFound                   = 9973
        case invalidType                = 9974
        case malformedData              = 9975
        case inconsistency              = 9976
        case underlyingError            = 9977
        
        var description: String? {
            switch self {
            case .commandTimeout:
                return "Out command timeout"
            case .connectionLost:
                return "Connection lost"
            case .clientNotOpen:
                return "IM client not open"
            case .commandInvalid:
                return "In command invalid"
            case .commandDataLengthTooLong:
                return "Data length of out command is too long"
            case .conversationNotFound:
                return "Conversation not found"
            case .updatingMessageNotAllowed:
                return "Updating message from others is not allowed"
            case .updatingMessageNotSent:
                return "Message is not sent"
            case .ownerPromotionNotAllowed:
                return "Updating a member's role to owner is not allowed"
            case .notFound:
                return "Not found"
            case .invalidType:
                return "Data type invalid"
            case .malformedData:
                return "Data format invalid"
            case .inconsistency:
                return "Internal inconsistency exception"
            default:
                return nil
            }
        }
    }

    enum ServerErrorCode: Int {
        case objectNotFound = 101
        case sessionConflict = 4111
        case sessionTokenExpired = 4112
    }

    /**
     Convert an error to LCError.

     The non-LCError will be wrapped into an underlying LCError.

     - parameter error: The error to be converted.
     */
    init(error: Error) {
        if let error = error as? LCError {
            self = error
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
        self = LCError(code: code.rawValue, reason: (reason ?? code.description), userInfo: userInfo)
    }

    init(code: ServerErrorCode, reason: String? = nil, userInfo: UserInfo? = nil) {
        self = LCError(code: code.rawValue, reason: reason, userInfo: userInfo)
    }

    /**
     Initialize with underlying error.

     - parameter underlyingError: The underlying error.
     */
    init(underlyingError: Error) {
        var error = LCError(code: InternalErrorCode.underlyingError, reason: nil, userInfo: nil)
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
