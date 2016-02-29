//
//  LCType.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

typealias LinkedProperty = (object: LCObject, property: String)

/**
 Check whether two linked properties are unequal.

 - parameter left:  Left linked property.
 - parameter right: Right linked property.

 - returns: true if two linked properties are unequal, false otherwise.
 */
func != (left: LinkedProperty, right: LinkedProperty) -> Bool {
    return (left.object != right.object) || (left.property != right.property)
}

/**
 LeanCloud abstract data type.
 
 It is superclass of all LeanCloud data type.
 */
public class LCType: NSObject {
    /// Linked property.
    var linkedProperty: LinkedProperty? {
        willSet {
            /* A property can be attached to only one owner.
               Once attached, it cannot be changed to another owner.
               We add this constraint for consistency. */
            if let oldValue = linkedProperty {
                if newValue == nil || newValue! != oldValue {
                    print("Property owner can not be changed.")
                    /* TODO: throw exception. */
                }
            }
        }
    }

    public override required init() {
        /* Stub method. */
    }
}