//
//  LCString.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud string type.

 It is a wrapper of `Swift.String` type, used to store a string value.
 */
public final class LCString: NSObject, LCValue, LCValueExtension, StringLiteralConvertible {
    public private(set) var value: String = ""

    public typealias UnicodeScalarLiteralType = Character
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType

    public override init() {
        super.init()
    }

    public convenience init(_ value: String) {
        self.init()
        self.value = value
    }

    public convenience required init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.init(String(value))
    }

    public convenience required init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.init(String(value))
    }

    public convenience required init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

    public required init?(coder aDecoder: NSCoder) {
        value = (aDecoder.decodeObjectForKey("value") as? String) ?? ""
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(value, forKey: "value")
    }

    public func copyWithZone(zone: NSZone) -> AnyObject {
        return LCString(value)
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        if let object = object as? LCString {
            return object === self || object.value == value
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

    class func instance() -> LCValue {
        return self.init()
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