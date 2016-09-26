//
//  LCArray.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud list type.

 It is a wrapper of `Swift.Array` type, used to store a list of objects.
 */
public final class LCArray: NSObject, LCValue, LCValueExtension, CollectionType, ArrayLiteralConvertible {
    public typealias Index = Int
    public typealias Element = LCValue

    public private(set) var value: [Element] = []

    public override init() {
        super.init()
    }

    public convenience init(_ value: [Element]) {
        self.init()
        self.value = value
    }

    public convenience required init(arrayLiteral elements: Element...) {
        self.init(elements)
    }

    public convenience init(unsafeObject: [AnyObject]) {
        self.init()
        value = unsafeObject.map { element in
            try! ObjectProfiler.object(JSONValue: element)
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        value = (aDecoder.decodeObjectForKey("value") as? [Element]) ?? []
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(value, forKey: "value")
    }

    public func copyWithZone(zone: NSZone) -> AnyObject {
        return LCArray(value)
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        if let object = object as? LCArray {
            return object === self || object.value == value
        } else {
            return false
        }
    }

    public func generate() -> IndexingGenerator<[Element]> {
        return value.generate()
    }

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return value.count
    }

    public subscript(index: Int) -> LCValue {
        get { return value[index] }
    }

    public var JSONValue: AnyObject {
        return value.map { element in element.JSONValue }
    }

    public var JSONString: String {
        return ObjectProfiler.getJSONString(self)
    }

    var LCONValue: AnyObject? {
        return value.map { element in (element as! LCValueExtension).LCONValue! }
    }

    static func instance() -> LCValue {
        return self.init([])
    }

    func forEachChild(body: (child: LCValue) -> Void) {
        forEach { element in body(child: element) }
    }

    func add(other: LCValue) throws -> LCValue {
        throw LCError(code: .InvalidType, reason: "Object cannot be added.")
    }

    func concatenate(other: LCValue, unique: Bool) throws -> LCValue {
        let result   = LCArray(value)
        let elements = (other as! LCArray).value

        result.concatenateInPlace(elements, unique: unique)

        return result
    }

    func concatenateInPlace(elements: [Element], unique: Bool) {
        value = unique ? (value +~ elements) : (value + elements)
    }

    func differ(other: LCValue) throws -> LCValue {
        let result   = LCArray(value)
        let elements = (other as! LCArray).value

        result.differInPlace(elements)

        return result
    }

    func differInPlace(elements: [Element]) {
        value = value - elements
    }
}