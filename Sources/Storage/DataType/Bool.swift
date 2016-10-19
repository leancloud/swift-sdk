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
public final class LCBool: NSObject, LCValue, LCValueExtension, ExpressibleByBooleanLiteral {
    public fileprivate(set) var value: Bool = false

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
        value = aDecoder.decodeBool(forKey: "value")
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(value, forKey: "value")
    }

    public func copy(with zone: NSZone?) -> Any {
        return LCBool(value)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? LCBool {
            return object === self || object.value == value
        } else {
            return false
        }
    }

    public var jsonValue: AnyObject {
        return value as AnyObject
    }

    public var jsonString: String {
        return ObjectProfiler.getJSONString(self)
    }

    public var rawValue: LCValueConvertible {
        return value
    }

    var lconValue: AnyObject? {
        return value as AnyObject?
    }

    static func instance() -> LCValue {
        return LCBool()
    }

    func forEachChild(_ body: (_ child: LCValue) -> Void) {
        /* Nothing to do. */
    }

    func add(_ other: LCValue) throws -> LCValue {
        throw LCError(code: .invalidType, reason: "Object cannot be added.")
    }

    func concatenate(_ other: LCValue, unique: Bool) throws -> LCValue {
        throw LCError(code: .invalidType, reason: "Object cannot be concatenated.")
    }

    func differ(_ other: LCValue) throws -> LCValue {
        throw LCError(code: .invalidType, reason: "Object cannot be differed.")
    }
}
