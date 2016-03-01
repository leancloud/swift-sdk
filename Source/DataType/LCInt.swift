//
//  LCInt.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud integer type.

 It is a wrapper of Int type, used to store an integer value.
 */
public class LCInt: LCType {
    public var value = 0

    /**
     Increase integer value by 1.
     */
    public func increase() {
        value += 1
        updateParent { (object, key) -> Void in
            object.addOperation(.Increment, key, 1)
        }
    }

    /**
     Increase integer value by specified amount.

     - parameter amount: The amount to increase.
     */
    public func increaseBy(amount: Int) {
        value += amount
        updateParent { (object, key) -> Void in
            object.addOperation(.Increment, key, amount)
        }
    }
}