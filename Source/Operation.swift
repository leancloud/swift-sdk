//
//  Operation.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/25/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

extension Object {

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
        let value: AnyObject?

        init(name: Name, key: String, value: AnyObject?) {
            self.name  = name
            self.key   = key
            self.value = value
        }

        /**
         Merge previous operation.

         - parameter operation: Operation to be merged.

         - returns: A new merged operation.
         */
        func merge(previousOperation operation: Operation) -> Operation {
            /* Stub method */

            return self
        }
    }

    /**
     Operation hub.

     Used to manage a batch of operations.
     */
    class OperationHub {
        /// A list of all operations.
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
        func reduce() -> [String:Operation] {
            stageOperations()
            return OperationReducer(operations: stagedOperations).reduce()
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

     Used to reduce a batch of operations to avoid redundance and invalid operations.
     */
    private class OperationReducer {
        let operations: [Operation]

        /// A table of non-redundant operations indexed by operation key.
        lazy var operationTable: [String:Operation] = [:]

        init(operations: [Operation]) {
            self.operations = operations
        }

        /**
         Reduce an operation.

         - parameter operation: Operation to be reduced.
         */
        func reduceOperation(var operation: Operation) {
            /* Merge with previous operation which has the same key. */
            if let previousOperation = operationTable[operation.key] {
                operation = operation.merge(previousOperation: previousOperation)
            }

            /* Stub method */
        }

        /**
         Reduce operations to produce a non-redundant representation.

         - returns: a table of reduced operations.
         */
        func reduce() -> [String:Operation] {
            operations.forEach { reduceOperation($0) }
            return operationTable
        }
    }
}