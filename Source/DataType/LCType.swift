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
    left:  LCType.ReversePropertyBinding,
    right: LCType.ReversePropertyBinding
) -> Bool {
    return (left.object != right.object) || (left.property != right.property)
}

/**
 LeanCloud abstract data type.
 
 It is superclass of all LeanCloud data type.
 */
public class LCType: NSObject {
    typealias ReversePropertyBinding = (object: LCType, property: String)

    /// Reverse property binding.
    var reversePropertyBinding: ReversePropertyBinding? {
        willSet {
            /* A LCType object can be bound to another LCType object's property.
               It can only be bound once. We add this constraint for consistency. */
            if let oldValue = reversePropertyBinding {
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
}