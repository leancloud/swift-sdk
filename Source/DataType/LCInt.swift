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
    public private(set) var value: Int?

    var intValue: Int {
        return value ?? 0
    }

    public required init() {
        super.init()
    }

    public convenience init(_ value: Int) {
        self.init()
        self.value = value
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCInt
        copy.value = self.value
        return copy
    }

    override class func operationReducerType() -> OperationReducer.Type {
        return OperationReducer.Number.self
    }

    /**
     Increase value by specified amount.

     - parameter amount: The amount to increase.
     */
    public func increaseBy(amount: Int) {
        self.value = intValue + amount

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
        guard let another = another as? LCInt else {
            /* TODO: throw an exception that two type cannot be added. */
            return nil
        }

        let base = self.intValue
        let increment = another.intValue

        return LCInt(base + increment)
    }
}