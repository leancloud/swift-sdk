//
//  LCType.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

infix operator +~ {
    associativity left
}

struct LCParent {
    weak var object: LCType?
    let      propertyName: String
}

func + (left: LCType, right: LCType?) -> LCType? {
    return left.add(right)
}

func +~ (left: LCType, right: LCType?) -> LCType? {
    return left.add(right, unique: true)
}

func - (left: LCType, right: LCType?) -> LCType? {
    return left.subtract(right)
}

func & (left: LCType, right: LCType?) -> LCType? {
    return left.union(right)
}

/**
 Check whether two parents are unequal.

 - parameter left:  Left parent.
 - parameter right: Right parent.

 - returns: true if two parents are unequal, false otherwise.
 */
func != (
    left:  LCParent,
    right: LCParent
) -> Bool {
    return (left.object != right.object) || (left.propertyName != right.propertyName)
}

/**
 LeanCloud abstract data type.
 
 It is superclass of all LeanCloud data type.
 */
public class LCType: NSObject, NSCopying {
    /// Parent object.
    var parent: LCParent? {
        willSet {
            validateParent(newValue)
        }
    }

    var JSONValue: AnyObject? {
        Exception.raise(.InvalidType, reason: "No JSON representation.")
        return nil
    }

    /// Make class abstract.
    internal override init() {
        super.init()
    }

    class func instance() -> LCType? {
        Exception.raise(.InvalidType, reason: "Cannot be instantiated.")
        return nil
    }

    public func copyWithZone(zone: NSZone) -> AnyObject {
        return self
    }

    /**
     Validate parent.

     A LCType object can be bound to another LCType object's property.
     It can only be bound once. We add this constraint for consistency.

     - parameter parent: The parent to validate.
     */
    func validateParent(parent: LCParent?) {
        if let previousParent = self.parent {
            if parent == nil || parent! != previousParent {
                /* TODO: throw an exception that parent cannot be altered once bound. */
            }
        }
    }

    /**
     Get operation reducer type.

     This method gets an operation reducer type for current LCType.
     You should override this method in subclass and return an actual operation reducer type.
     The default implementation returns the OperationReducer.Key type.
     That is, current type noly accepts SET and DELETE operation.

     - returns: An operation reducer type.
     */
    class func operationReducerType() -> OperationReducer.Type {
        return OperationReducer.Key.self
    }

    // MARK: Iteration

    func forEachChild(body: (child: LCType) -> Void) {
        /* Stub method. */
    }

    // MARK: Arithmetic

    func add(another: LCType?) -> LCType? {
        return add(another, unique: false)
    }

    func add(another: LCType?, unique: Bool) -> LCType? {
        Exception.raise(.InvalidType, reason: "Two types cannot be added.")
        return nil
    }

    func subtract(another: LCType?) -> LCType? {
        Exception.raise(.InvalidType, reason: "Two types cannot be subtracted.")
        return nil
    }

    func union(another: LCType?) -> LCType? {
        Exception.raise(.InvalidType, reason: "Two types cannot be unioned.")
        return nil
    }
}