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
public final class LCString: NSObject, LCType, LCTypeExtension, StringLiteralConvertible {
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
        if object === self {
            return true
        } else if let object = object as? LCString {
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

    class func instance() -> LCType {
        return self.init()
    }

    func forEachChild(body: (child: LCType) -> Void) {
        /* Nothing to do. */
    }

    func add(other: LCType) throws -> LCType {
        throw LCError(code: .InvalidType, reason: "Object cannot be added.")
    }

    func concatenate(other: LCType, unique: Bool) throws -> LCType {
        throw LCError(code: .InvalidType, reason: "Object cannot be concatenated.")
    }

    func differ(other: LCType) throws -> LCType {
        throw LCError(code: .InvalidType, reason: "Object cannot be differed.")
    }
}