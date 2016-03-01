//
//  LCDouble.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud double type.

 It is a wrapper of Double type, used to store a double value.
 */
public class LCDouble: LCType {
    public private(set) var value = Double(0)

    /**
     Increase value by specified amount.

     - parameter amount: The amount to increase.
     */
    public func increaseBy(amount: Double) {
        value += amount
        updateParent { (object, key) -> Void in
            object.addOperation(.Increment, key, amount)
        }
    }

    /**
     Increase value by 1.
     */
    public func increase() {
        increaseBy(1)
    }
}