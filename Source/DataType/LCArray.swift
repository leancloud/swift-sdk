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

 It is a wrapper of Swift.Array type, used to store a list of objects.
 */
public final class LCArray: LCType, NSCoding, SequenceType, ArrayLiteralConvertible {
    public typealias Element = LCType

    public private(set) var value: [Element] = []

    override var JSONValue: AnyObject? {
        return value.map { element in element.JSONValue! }
    }

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

    public required init?(coder aDecoder: NSCoder) {
        value = (aDecoder.decodeObjectForKey("value") as? [Element]) ?? []
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(value, forKey: "value")
    }

    class override func instance() -> LCType? {
        return self.init([])
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        return LCArray(value)
    }

    public override func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if let another = another as? LCArray {
            return another.value == value
        } else {
            return false
        }
    }

    public subscript(index: Int) -> LCType? {
        get { return value[index] }
    }

    public func generate() -> IndexingGenerator<[Element]> {
        return value.generate()
    }

    override class func operationReducerType() -> OperationReducer.Type {
        return OperationReducer.List.self
    }

    /**
     Append elements.

     - parameter elements: The elements to be appended.
     */
    func appendElements(elements: [Element]) {
        appendElements(elements, unique: false)
    }

    /**
     Append elements with unique option.

     This method will append elements based on the `unique` option.
     If `unique` is true, element will not be appended if it had already existed in array.
     Otherwise, the element will always be appended.

     - parameter elements: The elements to be appended.
     - parameter unique:   Unique or not.
     */
    func appendElements(elements: [Element], unique: Bool) {
        value = unique ? (value +~ elements) : (value + elements)
    }

    /**
     Remove elements.

     - parameter elements: The elements to be removed.
     */
    func removeElements(elements: [Element]) {
        value = value - elements
    }

    // MARK: Iteration

    override func forEachChild(body: (child: LCType) -> Void) {
        forEach { element in body(child: element) }
    }

    // MARK: Arithmetic

    override func add(another: LCType?) -> LCType? {
        return add(another, unique: false)
    }

    override func add(another: LCType?, unique: Bool) -> LCType? {
        guard let another = another as? LCArray else {
            Exception.raise(.InvalidType, reason: "Array expected.")
            return nil
        }

        let sum = unique ? (value +~ another.value) : (value + another.value)

        return LCArray(sum)
    }

    override func subtract(another: LCType?) -> LCType? {
        guard let another = another as? LCArray else {
            Exception.raise(.InvalidType, reason: "Array expected.")
            return nil
        }

        let difference = value - another.value

        return LCArray(difference)
    }
}