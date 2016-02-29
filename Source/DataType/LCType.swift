//
//  LCType.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 Check whether two linked properties are unequal.

 - parameter left:  Left linked property.
 - parameter right: Right linked property.

 - returns: true if two linked properties are unequal, false otherwise.
 */
func != (
    left:  LCType.PropertyBinding,
    right: LCType.PropertyBinding
) -> Bool {
    return (left.object != right.object) || (left.property != right.property)
}

/**
 LeanCloud abstract data type.
 
 It is superclass of all LeanCloud data type.
 */
public class LCType: NSObject {
    typealias PropertyBinding = (object: LCType, property: String)

    /// Parent object.
    var parent: PropertyBinding? {
        willSet {
            /* A LCType object can be bound to another LCType object's property.
               It can only be bound once. We add this constraint for consistency. */
            if let oldValue = parent {
                if newValue == nil || newValue! != oldValue {
                    print("Reverse property binding cannot be altered once bound.")
                    /* TODO: throw exception. */
                }
            }
        }
    }

    public override required init() {
        super.init()
        ObjectProfiler.bindUnboundProperties(self)
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

        block(object: object, key: parent.property)
    }
}