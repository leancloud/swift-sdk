//
//  Result.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/26/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

public protocol ResultType {
    var error: Error? { get }
    var isSuccess: Bool { get }
    var isFailure: Bool { get }
}

extension ResultType {
    public var isFailure: Bool {
        return !isSuccess
    }
}

public enum BooleanResult: ResultType {
    case Success
    case Failure(error: Error)

    public var error: Error? {
        switch self {
        case .Success:
            return nil
        case let .Failure(error):
            return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .Success: return true
        case .Failure: return false
        }
    }

    init(response: Response) {
        if let error = response.error {
            self = .Failure(error: error)
        } else {
            self = .Success
        }
    }
}

/**
 Result type for object request.
 */
public enum ObjectResult<T: LCType>: ResultType {
    case Success(object: T)
    case Failure(error: Error)

    public var error: Error? {
        switch self {
        case .Success:
            return nil
        case let .Failure(error):
            return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .Success: return true
        case .Failure: return false
        }
    }

    public var object: T? {
        switch self {
        case let .Success(object):
            return object
        case .Failure:
            return nil
        }
    }
}

/**
 Result type for optional request.
 */
public enum OptionalResult<T: LCType>: ResultType {
    case Success(object: T?)
    case Failure(error: Error)

    public var error: Error? {
        switch self {
        case .Success:
            return nil
        case let .Failure(error):
            return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .Success: return true
        case .Failure: return false
        }
    }

    public var object: T? {
        switch self {
        case let .Success(object):
            return object
        case .Failure:
            return nil
        }
    }
}

public enum QueryResult<T: LCObject>: ResultType {
    case Success(objects: [T])
    case Failure(error: Error)

    public var error: Error? {
        switch self {
        case .Success:
            return nil
        case let .Failure(error):
            return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .Success: return true
        case .Failure: return false
        }
    }

    public var objects: [T]? {
        switch self {
        case let .Success(objects):
            return objects
        case .Failure:
            return nil
        }
    }
}

public enum CountResult: ResultType {
    case Success(count: Int)
    case Failure(error: Error)

    public var error: Error? {
        switch self {
        case .Success:
            return nil
        case let .Failure(error):
            return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .Success: return true
        case .Failure: return false
        }
    }

    init(response: Response) {
        if let error = response.error {
            self = .Failure(error: error)
        } else {
            self = .Success(count: response.count)
        }
    }

    public var intValue: Int {
        switch self {
        case let .Success(count):
            return count
        case .Failure:
            return 0
        }
    }
}

public enum CQLResult: ResultType {
    case Success(value: CQLValue)
    case Failure(error: Error)

    public var error: Error? {
        switch self {
        case .Success:
            return nil
        case let .Failure(error):
            return error
        }
    }

    public var isSuccess: Bool {
        switch self {
        case .Success: return true
        case .Failure: return false
        }
    }

    public var objects: [LCObject] {
        switch self {
        case let .Success(value):
            return value.objects
        case .Failure:
            return []
        }
    }

    public var count: Int {
        switch self {
        case let .Success(value):
            return value.count
        case .Failure:
            return 0
        }
    }

    init(response: Response) {
        if let error = response.error {
            self = .Failure(error: error)
        } else {
            self = .Success(value: CQLValue(response: response))
        }
    }
}

extension Response {
    /**
     Get object result of response.

     - returns: `.Success` if response has no error and response data has valid type, `.Failure` otherwise.
     */
    func objectResult<T: LCType>() -> ObjectResult<T> {
        if let error = error {
            return .Failure(error: error)
        }

        guard let value = value else {
            return .Failure(error: Error(code: .NotFound, reason: "Response data not found."))
        }

        let any = ObjectProfiler.object(JSONValue: value)

        guard let object = any as? T else {
            return .Failure(error: Error(code: .InvalidType, reason: "Invalid response data type.", userInfo: ["response": value, "object": any]))
        }

        return .Success(object: object)
    }

    /**
     Get engine result of response.

     - returns: `.Success` if response has no error, `.Failure` otherwise.
     */
    func optionalResult<T: LCType>(keyPath: String? = nil) -> OptionalResult<T> {
        if let error = error {
            return .Failure(error: error)
        }

        guard let value = value else {
            return .Success(object: nil)
        }

        var optionalValue: AnyObject? = value

        if let keyPath = keyPath {
            optionalValue = value.valueForKeyPath(keyPath)
        }

        guard let someValue = optionalValue else {
            return .Success(object: nil)
        }

        let object = ObjectProfiler.object(JSONValue: someValue) as? T

        return .Success(object: object)
    }
}