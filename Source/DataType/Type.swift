//
//  LCType.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud abstract data type.
 
 It is superclass of all LeanCloud data type.
 */
public class LCType: NSObject, NSCopying {
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
}