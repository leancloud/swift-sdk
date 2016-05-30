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
public final class LCNumber: LCType, NSCoding, IntegerLiteralConvertible, FloatLiteralConvertible {
    public private(set) var value: Double = 0

    override var JSONValue: AnyObject? {
        return value
    }

    public override init() {
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

    public required init?(coder aDecoder: NSCoder) {
        value = aDecoder.decodeDoubleForKey("value")
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeDouble(value, forKey: "value")
    }

    class override func instance() -> LCType? {
        return self.init()
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        return LCNumber(value)
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
        value += amount.value
    }

    // MARK: Arithmetic

    override func add(another: LCType?) -> LCType? {
        guard let another = another as? LCNumber else {
            Exception.raise(.InvalidType, reason: "Number expected.")
            return nil
        }

        let sum = value + another.value

        return LCNumber(sum)
    }
}