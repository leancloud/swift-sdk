//
//  Operation.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/25/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

extension Object {
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
        let value: AnyObject?

        init(name: Name, key: String, value: AnyObject?) {
            self.name  = name
            self.key   = key
            self.value = value
        }
    }

    class OperationHub {
        /// All operations list.
        /// Used to store all object operations.
        lazy var allOperations = [Operation]()

        /// Staged operations.
        /// Used to stage operations to be reduced.
        lazy var stagedOperations = [Operation]()

        /// Untraced operations.
        /// Used to store operations that not ready to be reduced.
        lazy var untracedOperations = [Operation]();

        /**
         Append an operation to hub.

         - parameter name:  Operation name.
         - parameter key:   Key on which to perform.
         - parameter value: Value to be assigned.
         */
        func append(name: Operation.Name, _ key: String, _ value: AnyObject?) {
            let operation = Operation(name: name, key: key, value: value)

            untracedOperations.append(operation)
            allOperations.append(operation)
        }

        /**
         Stage untraced operations.
         */
        func stageOperations() {
            stagedOperations.appendContentsOf(untracedOperations)
            untracedOperations.removeAll()
        }

        /**
         Clear all reduced operations.
         */
        func clearReducedOperations() {
            stagedOperations.removeAll()
        }

        /**
         Reduce operations to produce a non-redundant representation.

         - returns: a non-redundant representation of operations.
         */
        func reduce() -> [Operation.Name:[String:AnyObject]] {
            stageOperations()
            return OperationReducer(operations: stagedOperations).reduce()
        }
    }

    private class OperationReducer {
        let operations: [Operation]

        init(operations: [Operation]) {
            self.operations = operations
        }

        /**
         Reduce operations to produce a non-redundant representation.

         - returns: a non-redundant representation of operations.
         */
        func reduce() -> [Operation.Name:[String:AnyObject]] {
            /* Stub method */
            return [:]
        }
    }
}