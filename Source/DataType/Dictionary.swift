//
//  LCDictionary.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud dictionary type.

 It is a wrapper of `Swift.Dictionary` type, used to store a dictionary value.
 */
public final class LCDictionary: NSObject, LCType, LCTypeExtension, CollectionType, DictionaryLiteralConvertible {
    public typealias Key   = String
    public typealias Value = LCType
    public typealias Index = DictionaryIndex<Key, Value>

    public private(set) var value: [Key: Value] = [:]

    public override init() {
        super.init()
    }

    public convenience init(_ value: [Key: Value]) {
        self.init()
        self.value = value
    }

    public convenience required init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(Dictionary<Key, Value>(elements: elements))
    }

    public convenience init(unsafeObject: [Key: AnyObject]) {
        self.init()
        value = unsafeObject.mapValue { value in
            try! ObjectProfiler.object(JSONValue: value)
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        value = (aDecoder.decodeObjectForKey("value") as? [String: LCType]) ?? [:]
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(value, forKey: "value")
    }

    public func copyWithZone(zone: NSZone) -> AnyObject {
        return LCDictionary(value)
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        if object === self {
            return true
        } else if let object = object as? LCDictionary {
            let lhs: AnyObject = value
            let rhs: AnyObject = object.value

            return lhs.isEqual(rhs)
        } else {
            return false
        }
    }

    public func generate() -> DictionaryGenerator<Key, Value> {
        return value.generate()
    }

    public var startIndex: DictionaryIndex<Key, Value> {
        return value.startIndex
    }

    public var endIndex: DictionaryIndex<Key, Value> {
        return value.endIndex
    }

    public subscript (position: DictionaryIndex<Key, Value>) -> (Key, Value) {
        return value[position]
    }

    public subscript(key: Key) -> Value? {
        get { return value[key] }
        set { value[key] = newValue }
    }

    public var JSONValue: AnyObject {
        return value.mapValue { value in value.JSONValue }
    }

    public var JSONString: String {
        return ObjectProfiler.getJSONString(self)
    }

    var LCONValue: AnyObject? {
        return value.mapValue { value in (value as! LCTypeExtension).LCONValue! }
    }

    static func instance() -> LCType {
        return self.init([:])
    }

    func forEachChild(body: (child: LCType) -> Void) {
        forEach { body(child: $1) }
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