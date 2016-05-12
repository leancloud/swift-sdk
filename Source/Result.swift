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

public enum ObjectResult<T: LCObject>: ResultType {
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

    init(response: Response) {
        if let error = response.error {
            self = .Failure(error: error)
        } else {
            let object = T()
            if let value = response.value {
                ObjectProfiler.updateObject(object, value)
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