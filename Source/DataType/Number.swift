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

 It is a wrapper of `Swift.Double` type, used to store a number value.
 */
public final class LCNumber: NSObject, LCType, LCTypeExtension, FloatLiteralConvertible, IntegerLiteralConvertible {
    public private(set) var value: Double = 0

    public override init() {
        super.init()
    }

    public convenience init(_ value: Double) {
        self.init()
        self.value = value
    }

    public convenience required init(floatLiteral value: FloatLiteralType) {
        self.init(value)
    }

    public convenience required init(integerLiteral value: IntegerLiteralType) {
        self.init(Double(value))
    }

    public required init?(coder aDecoder: NSCoder) {
        value = aDecoder.decodeDoubleForKey("value")
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeDouble(value, forKey: "value")
    }

    public func copyWithZone(zone: NSZone) -> AnyObject {
        return LCNumber(value)
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        if object === self {
            return true
        } else if let object = object as? LCNumber {
            return object.value == value
        } else {
            return false
        }
    }

    public var JSONValue: AnyObject {
        return value
    }

    public var JSONString: String {
        return ObjectProfiler.getJSONString(self)
    }

    var LCONValue: AnyObject? {
        return value
    }

    static func instance() -> LCType {
        return LCNumber()
    }

    func forEachChild(body: (child: LCType) -> Void) {
        /* Nothing to do. */
    }

    func add(other: LCType) throws -> LCType {
        let result = LCNumber(value)

        result.addInPlace((other as! LCNumber).value)

        return result
    }

    func addInPlace(amount: Double) {
        value += amount
    }

    func concatenate(other: LCType, unique: Bool) throws -> LCType {
        throw LCError(code: .InvalidType, reason: "Object cannot be concatenated.")
    }

    func differ(other: LCType) throws -> LCType {
        throw LCError(code: .InvalidType, reason: "Object cannot be differed.")
    }
}