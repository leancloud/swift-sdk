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

    /**
     Construct an object result with response.

     If request is successful and the response matches the type parameter of the generic type,
     the result is .Success with associated object. Otherwise, the result will be .Failure with associated error.

     - parameter response: The response of object request.
     */
    init(response: Response) {
        if let error = response.error {
            self = .Failure(error: error)
        } else {
            guard let value = response.value else {
                self = .Failure(error: Error(code: .NotFound, reason: "Response data not found."))
                return
            }

            let any = ObjectProfiler.object(JSONValue: value)

            guard let object = any as? T else {
                let userInfo = ["response": value, "object": any]
                self = .Failure(error: Error(code: .InvalidType, reason: "Invalid response object.", userInfo: userInfo))
                return
            }

            self = .Success(object: object)
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
}