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
public final class LCArray: NSObject, LCValue, LCValueExtension, Collection, ExpressibleByArrayLiteral {
    public typealias Index = Int
    public typealias Element = LCValue

    public fileprivate(set) var value: [Element] = []

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
            try! ObjectProfiler.object(jsonValue: element)
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        value = (aDecoder.decodeObject(forKey: "value") as? [Element]) ?? []
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(value, forKey: "value")
    }

    public func copy(with zone: NSZone?) -> Any {
        return LCArray(value)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? LCArray {
            return object === self || object.value == value
        } else {
            return false
        }
    }

    public func makeIterator() -> IndexingIterator<[Element]> {
        return value.makeIterator()
    }

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return value.count
    }

    public func index(after i: Int) -> Int {
        return value.index(after: i)
    }

    public subscript(index: Int) -> LCValue {
        get { return value[index] }
    }

    public var jsonValue: AnyObject {
        return value.map { element in element.jsonValue } as AnyObject
    }

    public var jsonString: String {
        return ObjectProfiler.getJSONString(self)
    }

    public var rawValue: LCValueConvertible {
        return value.map { element in element.rawValue }
    }

    var lconValue: AnyObject? {
        return value.map { element in (element as! LCValueExtension).lconValue! } as AnyObject
    }

    static func instance() -> LCValue {
        return self.init([])
    }

    func forEachChild(_ body: (_ child: LCValue) -> Void) {
        forEach { element in body(element) }
    }

    func add(_ other: LCValue) throws -> LCValue {
        throw LCError(code: .invalidType, reason: "Object cannot be added.")
    }

    func concatenate(_ other: LCValue, unique: Bool) throws -> LCValue {
        let result   = LCArray(value)
        let elements = (other as! LCArray).value

        result.concatenateInPlace(elements, unique: unique)

        return result
    }

    func concatenateInPlace(_ elements: [Element], unique: Bool) {
        value = unique ? (value +~ elements) : (value + elements)
    }

    func differ(_ other: LCValue) throws -> LCValue {
        let result   = LCArray(value)
        let elements = (other as! LCArray).value

        result.differInPlace(elements)

        return result
    }

    func differInPlace(_ elements: [Element]) {
        value = value - elements
    }
}
