//
//  LCType.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud abstract data type.
 
 It is superclass of all LeanCloud data type.
 */
public class LCType: NSObject {
    /// Owner object.
    /// If a LCType object has owner, it is a property of the owner object.
    weak var owner: LCObject? {
        willSet(newOwner) {
            /* A property can be attached to only one owner.
               Once attached, it cannot be changed to another owner.
               We add this constraint for consistency. */
            if let oldOwner = owner {
                if oldOwner != newOwner {
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