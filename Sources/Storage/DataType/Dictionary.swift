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
public final class LCDictionary: NSObject, LCValue, LCValueExtension, Collection, ExpressibleByDictionaryLiteral {
    public typealias Key   = String
    public typealias Value = LCValue
    public typealias Index = DictionaryIndex<Key, Value>

    public fileprivate(set) var value: [Key: Value] = [:]

    var elementDidChange: ((Key, Value?) -> Void)?

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
            try! ObjectProfiler.object(jsonValue: value)
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        /* Note: We have to make type casting twice here, or it will crash for unknown reason.
                 It seems that it's a bug of Swift. */
        value = (aDecoder.decodeObject(forKey: "value") as? [String: AnyObject] as? [String: LCValue]) ?? [:]
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(value, forKey: "value")
    }

    public func copy(with zone: NSZone?) -> Any {
        return LCDictionary(value)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? LCDictionary {
            return object === self || object.value == value
        } else {
            return false
        }
    }

    public func makeIterator() -> DictionaryIterator<Key, Value> {
        return value.makeIterator()
    }

    public var startIndex: DictionaryIndex<Key, Value> {
        return value.startIndex
    }

    public var endIndex: DictionaryIndex<Key, Value> {
        return value.endIndex
    }

    public func index(after i: DictionaryIndex<Key, Value>) -> DictionaryIndex<Key, Value> {
        return value.index(after: i)
    }

    public subscript(position: DictionaryIndex<Key, Value>) -> (key: Key, value: Value) {
        return value[position]
    }

    public subscript(key: Key) -> Value? {
        get { return value[key] }
        set {
            value[key] = newValue
            elementDidChange?(key, newValue)
        }
    }

    func set(_ key: String, _ value: LCValue?) {
        self.value[key] = value
    }

    public var jsonValue: AnyObject {
        return value.mapValue { value in value.jsonValue } as AnyObject
    }

    public var jsonString: String {
        return ObjectProfiler.getJSONString(self)
    }

    public var rawValue: LCValueConvertible {
        return value.mapValue { value in value.rawValue }
    }

    var lconValue: AnyObject? {
        return value.mapValue { value in (value as! LCValueExtension).lconValue! } as AnyObject
    }

    static func instance() -> LCValue {
        return self.init([:])
    }

    func forEachChild(_ body: (_ child: LCValue) -> Void) {
        forEach { body($1) }
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
