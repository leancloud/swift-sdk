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
public class LCDouble: LCType, IntegerLiteralConvertible, FloatLiteralConvertible {
    public private(set) var value: Double?

    var doubleValue: Double {
        return value ?? 0
    }

    public required init() {
        super.init()
    }

    public convenience init(_ value: Double) {
        self.init()
        self.value = value
    }

    public convenience required init(integerLiteral value: IntegerLiteralType) {
        self.init(Double(value))
    }

    public convenience required init(floatLiteral value: FloatLiteralType) {
        self.init(Double(value))
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCDouble
        copy.value = self.value
        return copy
    }

    override public func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if let another = another as? LCDouble {
            return another.value == value
        } else {
            return false
        }
    }

    override class func operationReducerType() -> OperationReducer.Type {
        return OperationReducer.Number.self
    }

    /**
     Increase value by specified amount.

     - parameter amount: The amount to increase.
     */
    public func increaseBy(amount: Double) {
        self.value = doubleValue + amount

        updateParent { (object, key) -> Void in
            object.addOperation(.Increment, key, LCDouble(amount))
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
        guard let another = another as? LCDouble else {
            /* TODO: throw an exception that two type cannot be added. */
            return nil
        }

        let base = self.doubleValue
        let increment = another.doubleValue

        return LCDouble(base + increment)
    }
}