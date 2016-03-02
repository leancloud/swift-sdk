//
//  LCType.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

struct LCParent {
    weak var object: LCType?
    let      propertyName: String
}

/**
 Check whether two parents are unequal.

 - parameter left:  Left parent.
 - parameter right: Right parent.

 - returns: true if two parents are unequal, false otherwise.
 */
func != (
    left:  LCParent,
    right: LCParent
) -> Bool {
    return (left.object != right.object) || (left.propertyName != right.propertyName)
}

/**
 LeanCloud abstract data type.
 
 It is superclass of all LeanCloud data type.
 */
public class LCType: NSObject {
    /// Parent object.
    var parent: LCParent? {
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
    func validateParent(parent: LCParent?) {
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

    // MARK: Arithmetic

    func add(another: LCType?) -> LCType? {
        /* TODO: throw an exception. */
        return nil
    }
}