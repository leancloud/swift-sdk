//
//  LCBool.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud boolean type.

 It is a wrapper of `Swift.Bool` type, used to store a boolean value.
 */
public final class LCBool: NSObject, LCValue, LCValueExtension, BooleanLiteralConvertible {
    public private(set) var value: Bool = false

    public override init() {
        super.init()
    }

    public convenience init(_ value: Bool) {
        self.init()
        self.value = value
    }

    public convenience required init(booleanLiteral value: BooleanLiteralType) {
        self.init(value)
    }

    public required init?(coder aDecoder: NSCoder) {
        value = aDecoder.decodeBoolForKey("value")
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeBool(value, forKey: "value")
    }

    public func copyWithZone(zone: NSZone) -> AnyObject {
        return LCBool(value)
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        if object === self {
            return true
        } else if let object = object as? LCBool {
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

    static func instance() -> LCValue {
        return LCBool()
    }

    func forEachChild(body: (child: LCValue) -> Void) {
        /* Nothing to do. */
    }

    func add(other: LCValue) throws -> LCValue {
        throw LCError(code: .InvalidType, reason: "Object cannot be added.")
    }

    func concatenate(other: LCValue, unique: Bool) throws -> LCValue {
        throw LCError(code: .InvalidType, reason: "Object cannot be concatenated.")
    }

    func differ(other: LCValue) throws -> LCValue {
        throw LCError(code: .InvalidType, reason: "Object cannot be differed.")
    }
}