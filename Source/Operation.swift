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
    /**
     Operation Name.
     */
    enum Name: String {
        case Set            = "Set"
        case Delete         = "Delete"
        case Increment      = "Increment"
        case Add            = "Add"
        case AddUnique      = "AddUnique"
        case AddRelation    = "AddRelation"
        case Remove         = "Remove"
        case RemoveRelation = "RemoveRelation"
    }

    let name: Name
    let key: String
    let value: LCType?

    required init(name: Name, key: String, value: LCType?) {
        self.name  = name
        self.key   = key
        self.value = value
    }
}

/**
 Operation hub.

 Used to manage a batch of operations.
 */
class OperationHub {
    weak var object: LCObject!

    /// A list of all operations.
    lazy var operations = [Operation]()

    /// A table of operation reducer indexed by operation key.
    lazy var operationReducerTable: [String:OperationReducer] = [:]

    init(_ object: LCObject) {
        self.object = object
    }

    /**
     Append an operation to hub.

     - parameter name:  Operation name.
     - parameter key:   Key on which to perform.
     - parameter value: Value to be assigned.
     */
    func append(name: Operation.Name, _ key: String, _ value: LCType?) {
        let operation = Operation(name: name, key: key, value: value)
        operations.append(operation)
        reduce(operation)
    }

    /**
     Reduce operation to operation table.

     - parameter operation: The operation which you want to reduce.
     */
    func reduce(operation: Operation) {
        let reducer = operationReducer(operation)

        reducer.validate(operation)
        reducer.reduce(operation)
    }

    func operationReducer(operation: Operation) -> OperationReducer {
        let key = operation.key

        if let previousOperationReducer = operationReducerTable[key] {
            return previousOperationReducer
        } else {
            let operationReducer = operationReducerSubclass(object, key).init()
            operationReducerTable[key] = operationReducer
            return operationReducer
        }
    }

    /**
     Get operation reducer class of an object property.

     - parameter object:       The object to be inspected.
     - parameter propertyName: The property name of object.

     - returns: The concrete operation reducer subclass.
     */
    func operationReducerSubclass(object: LCObject, _ propertyName: String) -> OperationReducer.Type {
        let subclass = ObjectProfiler.getLCType(object: object, propertyName: propertyName) as LCType.Type!
        return subclass.operationReducerType()
    }

    /**
     Produce a payload dictionary for request.

     - returns: A payload dictionary.
     */
    func payload() -> NSDictionary {
        return [:]
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
    func validate(operation: Operation) {
        let operationNames = self.dynamicType.validOperationNames()

        guard operationNames.contains(operation.name) else {
            /* TODO: throw an exception that current reducer cannot reduce operation. */
            return
        }
    }

    /**
     Reduce another operation.

     - parameter operation: The operation to be reduced.
     */
    func reduce(operation: Operation) {
        /* TODO: throw an exception that current reducer cannot reduce operation. */
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
            return [.Set, .Delete]
        }

        override func reduce(operation: Operation) {
            /* SET or DELETE will always override the previous. */
            self.operation = operation
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
            return [.Set, .Delete, .Increment]
        }

        override func reduce(operation: Operation) {
            if let previousOperation = self.operation {
                self.operation = reduce(operation, previousOperation: previousOperation)
            } else {
                self.operation = operation
            }
        }

        func reduce(operation: Operation, previousOperation: Operation) -> Operation? {
            let left  = previousOperation
            let right = operation

            switch (left.name, right.name) {
            case (.Set,       .Set):       return right
            case (.Delete,    .Set):       return right
            case (.Increment, .Set):       return right
            case (.Set,       .Delete):    return right
            case (.Delete,    .Delete):    return right
            case (.Increment, .Delete):    return right
            case (.Set,       .Increment): return Operation(name: .Set,       key: operation.key, value: left.value! + right.value!)
            case (.Delete,    .Increment): return Operation(name: .Set,       key: operation.key, value: right.value)
            case (.Increment, .Increment): return Operation(name: .Increment, key: operation.key, value: left.value! + right.value!)
            default:                       return nil
            }
        }
    }

    /**
     List oriented operation.

     It only accepts following operations:

     - SET
     - DELETE
     - ADD
     - ADDUNIQUE
     - REMOVE
     */
    class List: OperationReducer {
        var operationTable: [Operation.Name:Operation] = [:]

        override class func validOperationNames() -> [Operation.Name] {
            return [.Set, .Delete, .Add, .AddUnique, .Remove]
        }

        override func reduce(operation: Operation) {
            switch operation.name {
            case .Set:
                reset()
                setOperation(operation)
            case .Delete:
                reset()
                setOperation(operation)
            case .Add:
                removeObjects(operation, [.AddUnique, .Remove])

                if hasOperation(.Set) || hasOperation(.Delete) {
                    addObjects(operation, .Set)
                } else {
                    addObjects(operation, .Add)
                }
            case .AddUnique:
                removeObjects(operation, [.Add, .Remove])

                if hasOperation(.Set) || hasOperation(.Delete) {
                    unionObjects(operation, .Set)
                } else {
                    unionObjects(operation, .AddUnique)
                }
            case .Remove:
                removeObjects(operation, [.Set, .Add, .AddUnique])

                if hasOperation(.Remove) {
                    unionObjects(operation, .Remove)
                }
            default:
                break
            }
        }

        func hasOperation(name: Operation.Name) -> Bool {
            return operationTable[name] != nil
        }

        func removeObjects(operation: Operation, _ operationNames: Set<Operation.Name>) {
            var operations: [Operation] = []
            let subtrahend = operation.value as! LCList

            operationTable.forEach { (operationName, operation) in
                guard operationNames.contains(operationName)   else { return }
                guard let minuend = operation.value as? LCList else { return }

                operations.append(Operation(name: operation.name, key: operation.key, value: minuend - subtrahend))
            }

            operations.forEach({ setOperation($0) })
        }

        func addObjects(operation: Operation, _ name: Operation.Name) {
            var value = operation.value

            if let baseValue = operationTable[name]?.value as? LCList {
                value = baseValue + value
            }

            let operation = Operation(name: name, key: operation.key, value: value)

            setOperation(operation)
        }

        func unionObjects(operation: Operation, _ name: Operation.Name) {
            var value = operation.value

            if let baseValue = operationTable[name]?.value as? LCList {
                value = baseValue +~ value
            }

            let operation = Operation(name: name, key: operation.key, value: value)

            setOperation(operation)
        }

        func setOperation(operation: Operation) {
            self.operationTable[operation.name] = operation
        }

        func reset() {
            self.operationTable = [:]
        }
    }

    /**
     Relation oriented operation.

     It only accepts following operations:

     - ADDRELATION
     - REMOVERELATION
     */
    class Relation: OperationReducer {
        /* Stub class. */
    }
}