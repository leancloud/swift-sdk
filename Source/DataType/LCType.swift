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
public class LCType: NSObject {
    /// Parent object.
    var parent: LCParent? {
        willSet {
            validateParent(newValue)
        }
    }

    public override required init() {
        super.init()
    }

    public func copyWithZone(zone: NSZone) -> AnyObject {
        return self.dynamicType.init()
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

    /**
     Update reverse object.

     - parameter block: The update logic block.
     */
    func updateParent(block: (object: LCObject, key: String) -> Void) {
        guard let parent = parent else {
            /* TODO: throw an exception. */
            return
        }

        guard let object = parent.object as? LCObject else {
            /* TODO: throw an exception. */
            return
        }

        block(object: object, key: parent.propertyName)
    }

    public func delete() {
        ObjectProfiler.updateProperty(self, "value", nil)

        updateParent { (object, key) -> Void in
            object.addOperation(.Delete, key, nil)
        }
    }

    // MARK: Iteration

    func forEachChild(body: (child: LCType) -> Void) {
        /* Stub method. */
    }

    // MARK: Arithmetic

    func add(another: LCType?) -> LCType? {
        /* TODO: throw an exception that two types cannot be added. */
        return nil
    }

    func add(another: LCType?, unique: Bool) -> LCType? {
        /* TODO: throw an exception that two types cannot be added by unique. */
        return nil
    }

    func subtract(another: LCType?) -> LCType? {
        /* TODO: throw an exception that two types cannot be subtracted. */
        return nil
    }

    func union(another: LCType?) -> LCType? {
        /* TODO: throw an exception that two types cannot be unioned. */
        return nil
    }
}