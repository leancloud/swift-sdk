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
    public private(set) var value = 0

    public required init() {
        super.init()
    }

    public convenience init(_ value: Int) {
        self.init()
        self.value = value
    }

    /**
     Increase value by specified amount.

     - parameter amount: The amount to increase.
     */
    public func increaseBy(amount: Int) {
        updateParent { (object, key) -> Void in
            object.addOperation(.Increment, key, LCInt(amount))
        }
    }

    /**
     Increase value by 1.
     */
    public func increase() {
        increaseBy(1)
    }

    // MARK: Arithmetic

    override func add(another: LCType?) -> LCType? {
        if let some = another as? LCInt {
            return LCInt(self.value + some.value)
        } else {
            /* TODO: throw an exception. */
            return nil
        }
    }
}