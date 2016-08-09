//
//  LCNull.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud null type.

 A LeanCloud data type represents null value.

 - note: This type is not a singleton type, because Swift does not support singleton well currently.
 */
public class LCNull: NSObject, LCType, LCTypeExtension {
    public override init() {
        super.init()
    }

    public required init?(coder aDecoder: NSCoder) {
        /* Nothing to decode. */
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        /* Nothing to encode. */
    }

    public func copyWithZone(zone: NSZone) -> AnyObject {
        return LCNull()
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        return object === self || object is LCNull
    }

    public var JSONValue: AnyObject {
        return NSNull()
    }

    public var JSONString: String {
        return ObjectProfiler.getJSONString(self)
    }

    var LCONValue: AnyObject? {
        return NSNull()
    }

    static func instance() throws -> LCType {
        return LCNull()
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