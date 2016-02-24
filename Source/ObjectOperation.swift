//
//  ObjectOperation.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/24/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

class ObjectOperation {
    /**
     Operation type.
     */
    enum Type: String {
        case Set            = "Set"
        case Delete         = "Delete"
        case Increment      = "Increment"
        case Add            = "Add"
        case AddUnique      = "AddUnique"
        case AddRelation    = "AddRelation"
        case Remove         = "Remove"
        case RemoveRelation = "RemoveRelation"
    }

    let type: Type
    let key: String
    let object: AnyObject?

    init(type: Type, key: String, object: AnyObject?) {
        self.type   = type
        self.key    = key
        self.object = object
    }
}