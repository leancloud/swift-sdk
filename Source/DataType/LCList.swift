//
//  LCList.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud list type.

 It is a wrapper of NSArray type, used to store a list of objects.
 */
public class LCList: LCType, ArrayLiteralConvertible {
    public private(set) var value: NSArray?

    public required init() {
        super.init()
    }

    public convenience init(_ value: NSArray) {
        self.init()
        self.value = value
    }

    public convenience required init(arrayLiteral elements: AnyObject...) {
        self.init(elements)
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCList

        if let value = self.value {
            copy.value = NSArray(array: value as [AnyObject], copyItems: false)
        }

        return copy
    }

    override class func operationReducerType() -> OperationReducer.Type {
        return OperationReducer.List.self
    }

    /**
     Append an element.

     - parameter element: The element to be appended.
     */
    public func append(element: AnyObject) {
        self.value = concatenateObjects([element])

        updateParent { (object, key) in
            object.addOperation(.Add, key, LCList([element]))
        }
    }

    /**
     Append an element with unique option.

     This method will append an element based on the `unique` option.
     If `unique` is true, element will not be appended if it had already existed in array.
     Otherwise, the element will always be appended.

     - parameter element: The element to be appended.
     - parameter unique:  Unique or not.
     */
    public func append(element: AnyObject, unique: Bool) {
        self.value = concatenateObjects([element], unique: unique)

        updateParent { (object, key) in
            object.addOperation(.AddUnique, key, LCList([element]))
        }
    }

    /**
     Remove an element from list.

     - parameter element: The element to be removed.
     */
    public func remove(element: AnyObject) {
        self.value = subtractObjects([element])

        updateParent { (object, key) -> Void in
            object.addOperation(.Remove, key, LCList([element]))
        }
    }

    /**
     Concatenate objects.

     - parameter another: Another array of objects to be concatenated.

     - returns: A new concatenated array.
     */
    func concatenateObjects(another: NSArray?) -> NSArray? {
        return concatenateObjects(another, unique: false)
    }

    /**
     Concatenate objects with unique option.

     If unique is true, element in another array will not be concatenated if it had existed.

     - parameter another: Another array of objects to be concatenated.
     - parameter unique:  Unique or not.

     - returns: A new concatenated array.
     */
    func concatenateObjects(another: NSArray?, unique: Bool) -> NSArray? {
        guard let another = another else {
            return self.value
        }

        let result = NSMutableArray(array: (self.value ?? []) as [AnyObject], copyItems: false)

        if unique {
            another.forEach({ (element) in
                if !result.containsObject(element) {
                    result.addObject(element)
                }
            })
        } else {
            result.addObjectsFromArray(another as [AnyObject])
        }

        return result
    }

    /**
     Subtract objects.

     - parameter another: Another array of objects to be subtracted.

     - returns: A new subtracted array.
     */
    func subtractObjects(another: NSArray?) -> NSArray? {
        guard let minuend = self.value else {
            return nil
        }

        guard let subtrahend = another else {
            return minuend
        }

        let result = NSMutableArray(array: minuend)

        result.removeObjectsInArray(subtrahend as [AnyObject])

        return result
    }

    // MARK: Arithmetic

    override func add(another: LCType?) -> LCType? {
        return add(another, unique: false)
    }

    override func add(another: LCType?, unique: Bool) -> LCType? {
        guard let another = another as? LCList else {
            /* TODO: throw an exception that one type cannot be appended to another type. */
            return nil
        }

        if let array = concatenateObjects(another.value, unique: unique) {
            return LCList(array)
        } else {
            return LCList()
        }
    }

    override func subtract(another: LCType?) -> LCType? {
        guard let another = another as? LCList else {
            /* TODO: throw an exception that one type cannot be appended to another type. */
            return nil
        }

        if let array = subtractObjects(another.value) {
            return LCList(array)
        } else {
            return LCList()
        }
    }
}