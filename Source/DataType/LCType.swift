//
//  LCType.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 Check whether two parents are unequal.

 - parameter left:  Left parent.
 - parameter right: Right parent.

 - returns: true if two parents are unequal, false otherwise.
 */
func != (
    left:  LCType.Parent,
    right: LCType.Parent
) -> Bool {
    return (left.object != right.object) || (left.propertyName != right.propertyName)
}

/**
 LeanCloud abstract data type.
 
 It is superclass of all LeanCloud data type.
 */
public class LCType: NSObject {
    struct Parent {
        weak var object: LCType?
        let      propertyName: String
    }

    /// Parent object.
    var parent: Parent? {
        willSet {
            validateParent(newValue)
        }
    }

    public override required init() {
        super.init()
        ObjectProfiler.bindParent(self)
    }

    /**
     Validate parent.

     A LCType object can be bound to another LCType object's property.
     It can only be bound once. We add this constraint for consistency.

     - parameter parent: The parent to validate.
     */
    func validateParent(parent: Parent?) {
        if let previousParent = self.parent {
            if parent == nil || parent! != previousParent {
                print("Reverse property binding cannot be altered once bound.")
                /* TODO: throw exception. */
            }
        }
    }

    /**
     Update reverse object.

     - parameter block: The update logic block.
     */
    func updateParent(block: (object: LCObject, key: String) -> Void) {
        guard let parent = parent else {
            /* TODO: throw an exception. */
            return
        }

        guard let object = parent.object as? LCObject else {
            /* TODO: throw an exception. */
            return
        }

        block(object: object, key: parent.propertyName)
    }
}