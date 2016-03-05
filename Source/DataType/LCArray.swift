//
//  LCArray.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud array type.

 It is a wrapper of Array type, used to store an array value.
 */
public class LCArray: LCType {
    public private(set) var value: NSArray

    public required init() {
        self.value = []
        super.init()
    }

    public convenience init(_ value: NSArray) {
        self.init()
        self.value = value
    }

    /**
     Append an element.

     - parameter element: The element to be appended.
     */
    public func append(element: AnyObject) {
        append(element, unique: false)
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
        if unique {
            if contains(element) == false {
                updateParent { (object, key) in
                    object.addOperation(.AddUnique, key, LCArray([element]))
                }
            }
        } else {
            updateParent { (object, key) in
                object.addOperation(.Add, key, LCArray([element]))
            }
        }
    }

    func contains(element: AnyObject) -> Bool {
        return self.value.containsObject(element)
    }

    /**
     Concatenate another array.

     If unique is true, element in another array will not be concatenated if it had existed.

     - parameter another: Another array to be concatenated.
     - parameter unique:  Unique or not.

     - returns: A new concatenated array.
     */
    func concatenate(another: NSArray, unique: Bool) -> NSArray {
        let result = NSMutableArray(array: self.value)

        if unique {
            another.forEach({ (element) in
                if contains(element) == false {
                    result.addObject(element)
                }
            })
        } else {
            result.addObjectsFromArray(another as [AnyObject])
        }

        return result
    }

    // MARK: Arithmetic

    override func add(another: LCType?) -> LCType? {
        return add(another, unique: false)
    }

    override func add(another: LCType?, unique: Bool) -> LCType? {
        guard let some = another as? LCArray else {
            /* TODO: throw an exception that one type cannot be appended to another type. */
            return nil
        }

        let array = concatenate(some.value, unique: unique)

        return LCArray(array)
    }

    override func subtract(another: LCType?) -> LCType? {
        guard let some = another as? LCArray else {
            /* TODO: throw an exception that one type cannot be appended to another type. */
            return nil
        }

        let array = NSMutableArray(array: self.value);

        array.removeObjectsInArray(some.value as [AnyObject])

        return LCArray(array)
    }
}