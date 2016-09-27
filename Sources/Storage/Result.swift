//
//  Result.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/26/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

public protocol LCResultType {
    var error: LCError? { get }
    var isSuccess: Bool { get }
    var isFailure: Bool { get }
}

extension LCResultType {
    public var isFailure: Bool {
        return !isSuccess
    }
}

public enum LCBooleanResult: LCResultType {
    case success
    case failure(error: LCError)

    public var error: LCError? {
        switch self {
        case .success:
            return nil
        case let .failure(error):
            return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    init(response: LCResponse) {
        if let error = response.error {
            self = .failure(error: error)
        } else {
            self = .success
        }
    }
}

/**
 Result type for object request.
 */
public enum LCObjectResult<T: LCValue>: LCResultType {
    case success(object: T)
    case failure(error: LCError)

    public var error: LCError? {
        switch self {
        case .success:
            return nil
        case let .failure(error):
            return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    public var object: T? {
        switch self {
        case let .success(object):
            return object
        case .failure:
            return nil
        }
    }
}

/**
 Result type for optional request.
 */
public enum LCOptionalResult: LCResultType {
    case success(object: LCValue?)
    case failure(error: LCError)

    public var error: LCError? {
        switch self {
        case .success:
            return nil
        case let .failure(error):
            return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    public var object: LCValue? {
        switch self {
        case let .success(object):
            return object
        case .failure:
            return nil
        }
    }
}

public enum LCQueryResult<T: LCObject>: LCResultType {
    case success(objects: [T])
    case failure(error: LCError)

    public var error: LCError? {
        switch self {
        case .success:
            return nil
        case let .failure(error):
            return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    public var objects: [T]? {
        switch self {
        case let .success(objects):
            return objects
        case .failure:
            return nil
        }
    }
}

public enum LCCountResult: LCResultType {
    case success(count: Int)
    case failure(error: LCError)

    public var error: LCError? {
        switch self {
        case .success:
            return nil
        case let .failure(error):
            return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    init(response: LCResponse) {
        if let error = response.error {
            self = .failure(error: error)
        } else {
            self = .success(count: response.count)
        }
    }

    public var intValue: Int {
        switch self {
        case let .success(count):
            return count
        case .failure:
            return 0
        }
    }
}

public enum LCCQLResult: LCResultType {
    case success(value: LCCQLValue)
    case failure(error: LCError)

    public var error: LCError? {
        switch self {
        case .success:
            return nil
        case let .failure(error):
            return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    public var objects: [LCObject] {
        switch self {
        case let .success(value):
            return value.objects
        case .failure:
            return []
        }
    }

    public var count: Int {
        switch self {
        case let .success(value):
            return value.count
        case .failure:
            return 0
        }
    }

    init(response: LCResponse) {
        if let error = response.error {
            self = .failure(error: error)
        } else {
            self = .success(value: LCCQLValue(response: response))
        }
    }
}

extension LCResponse {
    /**
     Get object result of response.

     - returns: `.Success` if response has no error and response data has valid type, `.Failure` otherwise.
     */
    func objectResult<T: LCValue>() -> LCObjectResult<T> {
        if let error = error {
            return .failure(error: error)
        }

        guard let value = value else {
            return .failure(error: LCError(code: .notFound, reason: "Response data not found."))
        }

        let any = try! ObjectProfiler.object(jsonValue: value)

        guard let object = any as? T else {
            return .failure(error: LCError(code: .invalidType, reason: "Invalid response data type.", userInfo: ["response": value, "object": any]))
        }

        return .success(object: object)
    }

    /**
     Get engine result of response.

     - returns: `.Success` if response has no error, `.Failure` otherwise.
     */
    func optionalResult(_ keyPath: String? = nil) -> LCOptionalResult {
        if let error = error {
            return .failure(error: error)
        }

        guard let value = value else {
            return .success(object: nil)
        }

        var optionalValue: AnyObject? = value

        if let keyPath = keyPath {
            optionalValue = value.value(forKeyPath: keyPath) as AnyObject?
        }

        guard let someValue = optionalValue else {
            return .success(object: nil)
        }

        let object = try! ObjectProfiler.object(jsonValue: someValue)

        return .success(object: object)
    }
}
