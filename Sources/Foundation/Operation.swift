//
//  Operation.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/25/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 Operation.

 Used to present an action of object update.
 */
class Operation {
    
    static let key: String = "__op"
    
    /**
     Operation Name.
     */
    enum Name: String {
        case set            = "Set"
        case delete         = "Delete"
        case increment      = "Increment"
        case add            = "Add"
        case addUnique      = "AddUnique"
        case remove         = "Remove"
        case addRelation    = "AddRelation"
        case removeRelation = "RemoveRelation"
    }
    
    enum Key {
        case key(_ key: String)
        case keyPath(key: String, path: [String])
        
        var rawValue: String {
            switch self {
            case let .key(v):
                return v
            case let .keyPath(key: v, path: _):
                return v
            }
        }
        
        init(key: String) throws {
            if key.contains(".") {
                let keys = key.components(separatedBy: ".")
                guard let fk = keys.first, !fk.isEmpty,
                    let lk = keys.last, !lk.isEmpty else {
                        throw LCError.malformedKey(key)
                }
                try Operation.validateKey(fk)
                self = .keyPath(key: key, path: keys)
            } else {
                try Operation.validateKey(key)
                self = .key(key)
            }
        }
    }

    let name: Name
    let key: Key
    let value: LCValue?
    
    init(name: Name, key: String, value: LCValue?) throws {
        self.name = name
        self.key = try Key.init(key: key)
        self.value = value?.copy(with: nil) as? LCValue
    }

    /**
     The LCON representation of operation.
     */
    var lconValue: Any? {
        let lconValue = (value as? LCValueExtension)?.lconValue

        switch name {
        case .set:
            return lconValue
        case .delete:
            return [
                Operation.key: name.rawValue
            ]
        case .increment:
            guard let lconValue = lconValue else {
                return nil
            }
            return [
                Operation.key: name.rawValue,
                "amount": lconValue
            ]
        case .add,
             .addUnique,
             .addRelation,
             .remove,
             .removeRelation:
            guard let lconValue = lconValue else {
                return nil
            }
            return [
                Operation.key: name.rawValue,
                "objects": lconValue
            ]
        }
    }

    /**
     Validate the column name of object.

     - parameter key: The key you want to validate.

     - throws: A MalformedData error if key is invalid.
     */
    static func validateKey(_ key: String) throws {
        let options: NSString.CompareOptions = [
            .regularExpression,
            .caseInsensitive
        ]

        guard key.range(of: "^[a-z0-9][a-z0-9_]*$", options: options) != nil else {
            throw LCError.malformedKey(key)
        }
    }

    static func reducerType(_ type: LCValue.Type) -> OperationReducer.Type {
        switch type {
        case _ where type === LCArray.self:
            return OperationReducer.Array.self

        case _ where type === LCNumber.self:
            return OperationReducer.Number.self

        case _ where type === LCRelation.self:
            return OperationReducer.Relation.self

        default:
            return OperationReducer.Key.self
        }
    }

    func reducerType() throws -> OperationReducer.Type? {
        switch name {
        case .set:
            if let value: LCValue = self.value {
                return Operation.reducerType(type(of: value))
            } else {
                throw LCError(code: .inconsistency, reason: "Operation value not exist.")
            }
        case .delete:
            return nil
        case .add,
             .addUnique,
             .remove:
            return OperationReducer.Array.self
        case .increment:
            return OperationReducer.Number.self
        case .addRelation,
             .removeRelation:
            return OperationReducer.Relation.self
        }
    }
}

typealias OperationStack     = [String:[Operation]]
typealias OperationTable     = [String:Operation]
typealias OperationTableList = [OperationTable]

/**
 Operation hub.

 Used to manage a batch of operations.
 */
class OperationHub {
    weak var object: LCObject?

    /// The table of operation reducers indexed by operation key.
    var operationReducerTable: [String: OperationReducer] = [:]

    /// The table of unreduced operations indexed by operation key.
    var unreducedOperationTable: [String: Operation] = [:]

    /// Return true iff operation hub has no operations.
    var isEmpty: Bool {
        return operationReducerTable.isEmpty && unreducedOperationTable.isEmpty
    }

    init(_ object: LCObject) {
        self.object = object
    }

    /**
     Reduce an operation.

     - parameter operation: The operation which you want to reduce.
     */
    func reduce(_ operation: Operation) throws {
        let key = operation.key.rawValue
        if let operationReducer = self.operationReducerTable[key] {
            try operationReducer.reduce(operation)
        } else if let operationReducerType = try self.operationReducerType(operation) {
            let operationReducer = operationReducerType.init()
            self.operationReducerTable[key] = operationReducer
            if let unreducedOperation = self.unreducedOperationTable[key] {
                self.unreducedOperationTable.removeValue(forKey: key)
                try operationReducer.reduce(unreducedOperation)
            }
            try operationReducer.reduce(operation)
        } else {
            self.unreducedOperationTable[key] = operation
        }
    }

    /**
     Get operation reducer type for operation.

     - parameter operation: The operation object.

     - returns: Operation reducer type, or nil if not found.
     */
    func operationReducerType(_ operation: Operation) throws -> OperationReducer.Type? {
        guard let object = self.object else {
            throw LCError(code: .inconsistency, reason: "Object not exist.")
        }
        switch operation.key {
        case let .key(propertyName):
            if let propertyType = ObjectProfiler.shared.getLCValue(object, propertyName) {
                return Operation.reducerType(propertyType)
            } else {
                return try operation.reducerType()
            }
        case .keyPath:
            return try operation.reducerType()
        }
    }

    /**
     Get an operation stack.

     The operation stack is a structure that maps operation key to a list of operations.

     - returns: An operation stack indexed by property key.
     */
    func operationStack() -> OperationStack {
        var operationStack: OperationStack = [:]

        operationReducerTable.forEach { (key, operationReducer) in
            let operations = operationReducer.operations()

            if operations.count > 0 {
                operationStack[key] = operations
            }
        }

        unreducedOperationTable.forEach { (key, operation) in
            operationStack[key] = [operation]
        }

        return operationStack
    }

    /**
     Extract an operation table from an operation stack.

     - parameter operationStack: An operation stack from which the operation table will be extracted.

     - returns: An operation table, or nil if no operations can be extracted.
     */
    func extractOperationTable(_ operationStack: inout OperationStack) -> OperationTable? {
        var table: OperationTable = [:]

        operationStack.forEach { (key, operations) in
            if operations.isEmpty {
                operationStack.removeValue(forKey: key)
            } else {
                table[key] = operations.first
                operationStack[key] = Array(operations[1..<operations.count])
            }
        }

        return table.isEmpty ? nil : table
    }

    /**
     Get an operation table list.

     Operation table list is flat version of operation stack.
     When a key has two or more operations in operation stack,
     each operation will be extracted to each operation table in an operation table list.

     For example, `["foo":[op1,op2]]` will extracted as `[["foo":op1],["foo":op2]]`.

     The reason for making this transformation is that one request should
     not contain multiple operations on one key.

     - returns: An operation table list.
     */
    func operationTableList() -> OperationTableList {
        var list: OperationTableList = []
        var operationStack = self.operationStack()

        while !operationStack.isEmpty {
            if let operationTable = extractOperationTable(&operationStack) {
                list.append(operationTable)
            }
        }

        return list
    }

    /**
     Remove all operations.
     */
    func reset() {
        operationReducerTable = [:]
        unreducedOperationTable = [:]
    }
}

/**
 Operation reducer.

 Operation reducer is used to reduce operations to remove redundancy.
 */
class OperationReducer {
    required init() {
        /* Stub method. */
    }

    class func validOperationNames() -> [Operation.Name] {
        return []
    }

    /**
     Validate operation.

     - parameter operation: The operation to validate.
     */
    func validate(_ operation: Operation) throws {
        let operationNames = type(of: self).validOperationNames()

        guard operationNames.contains(operation.name) else {
            throw LCError(code: .invalidType, reason: "Invalid operation type.", userInfo: nil)
        }
    }

    /**
     Reduce another operation.

     - parameter operation: The operation to be reduced.
     */
    func reduce(_ operation: Operation) throws {
        throw LCError(code: .invalidType, reason: "Operation cannot be reduced.", userInfo: nil)
    }

    /**
     Get all reduced operations.

     - returns: An array of reduced operations.
     */
    func operations() -> [Operation] {
        return []
    }

    /**
     Key oriented operation.

     It only accepts following operations:

     - SET
     - DELETE
     */
    class Key: OperationReducer {
        var operation: Operation?

        override class func validOperationNames() -> [Operation.Name] {
            return [.set, .delete]
        }

        override func reduce(_ operation: Operation) throws {
            try super.validate(operation)

            /* SET or DELETE will always override the previous. */
            self.operation = operation
        }

        override func operations() -> [Operation] {
            if let operation = self.operation {
                return [operation]
            } else {
                return []
            }
        }
    }

    /**
     Number oriented operation.

     It only accepts following operations:

     - SET
     - DELETE
     - INCREMENT
     */
    class Number: OperationReducer {
        var operation: Operation?

        override class func validOperationNames() -> [Operation.Name] {
            return [.set, .delete, .increment]
        }

        override func reduce(_ operation: Operation) throws {
            try super.validate(operation)

            if let previousOperation = self.operation {
                self.operation = try reduce(operation, previousOperation: previousOperation)
            } else {
                self.operation = operation
            }
        }

        func reduce(_ operation: Operation, previousOperation: Operation) throws -> Operation? {
            let lhs = previousOperation
            let rhs = operation

            switch (lhs.name, rhs.name) {
            case (.set,       .set):
                return rhs
            case (.delete,    .set):
                return rhs
            case (.increment, .set):
                return rhs
            case (.set,       .delete):
                return rhs
            case (.delete,    .delete):
                return rhs
            case (.increment, .delete):
                return rhs
            case (.set,       .increment):
                guard let lhsValue = lhs.value as? LCValueExtension, let rhsValue = rhs.value else {
                    throw LCError(code: .invalidType, reason: "Invalid value type.")
                }
                return try Operation(
                    name: .set,
                    key: operation.key.rawValue,
                    value: try (lhsValue).add(rhsValue))
            case (.increment, .increment):
                guard let lhsValue = lhs.value as? LCValueExtension, let rhsValue = rhs.value else {
                    throw LCError(code: .invalidType, reason: "Invalid value type.")
                }
                return try Operation(
                    name: .increment,
                    key: operation.key.rawValue,
                    value: try (lhsValue).add(rhsValue))
            case (.delete,    .increment):
                return try Operation(
                    name: .set,
                    key: operation.key.rawValue,
                    value: rhs.value)
            default:
                return nil
            }
        }

        override func operations() -> [Operation] {
            if let operation = self.operation {
                return [operation]
            } else {
                return []
            }
        }
    }

    /**
     Array oriented operation.

     It only accepts following operations:

     - SET
     - DELETE
     - ADD
     - ADDUNIQUE
     - REMOVE
     */
    class Array: OperationReducer {
        var operationSequence: [Operation] = []
        
        override class func validOperationNames() -> [Operation.Name] {
            return [.set, .delete, .add, .addUnique, .remove]
        }
        
        override func reduce(_ operation: Operation) throws {
            try super.validate(operation)
            self.operationSequence.append(operation)
        }
        
        override func operations() -> [Operation] {
            return self.operationSequence
        }
    }

    /**
     Relation oriented operation.

     It only accepts following operations:

     - ADDRELATION
     - REMOVERELATION
     */
    class Relation: Array {
        override class func validOperationNames() -> [Operation.Name] {
            return [.addRelation, .removeRelation]
        }
    }
}

private extension LCError {
    
    static func malformedKey(_ key: String) -> LCError {
        return LCError(
            code: .malformedData,
            reason: "Malformed key.",
            userInfo: ["key": key])
    }
}
