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
public final class LCArray: LCType, SequenceType, ArrayLiteralConvertible {
    public typealias Element = LCType

    public private(set) var value: [Element]?

    public required init() {
        super.init()
    }

    public convenience init(_ value: [Element]) {
        self.init()
        self.value = value
    }

    public convenience required init(arrayLiteral elements: Element...) {
        self.init(elements)
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCArray
        copy.value = value
        return copy
    }

    override public func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if let another = another as? LCArray {
            let lhs = value
            let rhs = another.value

            if let lhs = lhs, rhs = rhs {
                return lhs == rhs
            } else if lhs == nil && rhs == nil {
                return true
            }
        }

        return false
    }

    public func generate() -> IndexingGenerator<[Element]> {
        return (value ?? []).generate()
    }

    override class func operationReducerType() -> OperationReducer.Type {
        return OperationReducer.List.self
    }

    /**
     Append an element.

     - parameter element: The element to be appended.
     */
    func append(element: Element) {
        self.value = self.value + [element]
    }

    /**
     Append an element with unique option.

     This method will append an element based on the `unique` option.
     If `unique` is true, element will not be appended if it had already existed in array.
     Otherwise, the element will always be appended.

     - parameter element: The element to be appended.
     - parameter unique:  Unique or not.
     */
    func append(element: Element, unique: Bool) {
        self.value = unique ? (self.value +~ [element]) : (self.value + [element])
    }

    /**
     Remove an element from list.

     - parameter element: The element to be removed.
     */
    func remove(element: Element) {
        self.value = self.value - [element]
    }

    // MARK: Iteration

    override func forEachChild(body: (child: LCType) -> Void) {
        forEach { body(child: $0) }
    }

    // MARK: Arithmetic

    override func add(another: LCType?) -> LCType? {
        return add(another, unique: false)
    }

    override func add(another: LCType?, unique: Bool) -> LCType? {
        guard let another = another as? LCArray else {
            /* TODO: throw an exception that one type cannot be appended to another type. */
            return nil
        }

        if let array = unique ? (self.value +~ another.value) : (self.value + another.value) {
            return LCArray(array)
        } else {
            return LCArray()
        }
    }

    override func subtract(another: LCType?) -> LCType? {
        guard let another = another as? LCArray else {
            /* TODO: throw an exception that one type cannot be appended to another type. */
            return nil
        }

        if let array = self.value - another.value {
            return LCArray(array)
        } else {
            return LCArray()
        }
    }
}