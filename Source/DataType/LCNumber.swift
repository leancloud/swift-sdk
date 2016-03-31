//
//  LCNumber.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud number type.

 It is a wrapper of Swift.Double type, used to store a number value.
 */
public final class LCNumber: LCType, IntegerLiteralConvertible, FloatLiteralConvertible {
    public private(set) var value: Double?

    var doubleValue: Double {
        return value ?? 0
    }

    override var JSONValue: AnyObject? {
        return doubleValue
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
        let copy = super.copyWithZone(zone) as! LCNumber
        copy.value = self.value
        return copy
    }

    public override func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if let another = another as? LCNumber {
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
    func increase(amount: LCNumber) {
        value = doubleValue + amount.doubleValue
    }

    // MARK: Arithmetic

    override func add(another: LCType?) -> LCType? {
        guard let another = another as? LCNumber else {
            /* TODO: throw an exception that two type cannot be added. */
            return nil
        }

        let base = self.doubleValue
        let increment = another.doubleValue

        return LCNumber(base + increment)
    }
}