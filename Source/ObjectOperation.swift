//
//  ObjectOperation.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/24/16.
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
        let object: AnyObject?

        init(name: Name, key: String, object: AnyObject?) {
            self.name   = name
            self.key    = key
            self.object = object
        }
    }
}