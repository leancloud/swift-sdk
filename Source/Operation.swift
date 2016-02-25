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
        /// Operations list.
        /// Used to store all object operations.
        lazy var operations = [Operation]()

        /**
         Append an operation to hub.

         - parameter name:  Operation name.
         - parameter key:   Key on which to perform.
         - parameter value: Value to be assigned.
         */
        func append(name: Operation.Name, _ key: String, _ value: AnyObject?) {
            self.operations.append(Operation(name: name, key: key, value: value))
        }

        /**
         Reduce operations to produce an array of non-redundant operations.

         - returns: An array of non-redundant operations.
         */
        func reduce() -> [Operation] {
            /* Stub method */
            return [Operation]()
        }
    }
}