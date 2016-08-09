//
//  LCType.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 Abstract data type.

 All LeanCloud data types must confirm this protocol.
 */
@objc public protocol LCType: NSObjectProtocol, NSCoding, NSCopying {
    /**
     The JSON representation.
     */
    var JSONValue: AnyObject { get }

    /**
     The pretty description.
     */
    var JSONString: String { get }
}

protocol LCTypeExtension {
    /**
     The LCON (LeanCloud Object Notation) representation.

     For JSON-compatible objects, such as string, array, etc., LCON value is the same as JSON value.

     However, some types might have different representations, or even have no LCON value.
     For example, when an object has not been saved, its LCON value is nil.
     */
    var LCONValue: AnyObject? { get }

    /**
     Create an instance of current type.

     This method exists because some data types cannot be instantiated externally.

     - returns: An instance of current type.
     */
    static func instance() throws -> LCType

    // MARK: Enumeration

    /**
     Iterate children by a closure.

     - parameter body: The iterator closure.
     */
    func forEachChild(body: (child: LCType) -> Void)

    // MARK: Arithmetic

    /**
     Add an object.

     - parameter other: The object to be added, aka the addend.

     - returns: The sum of addition.
     */
    func add(other: LCType) throws -> LCType

    /**
     Concatenate an object with unique option.

     - parameter other:  The object to be concatenated.
     - parameter unique: Whether to concatenate with unique or not.

        If `unique` is true, for each element in `other`, if current object has already included the element, do nothing.
        Otherwise, the element will always be appended.

     - returns: The concatenation result.
     */
    func concatenate(other: LCType, unique: Bool) throws -> LCType

    /**
     Calculate difference with other.

     - parameter other: The object to differ.

     - returns: The difference result.
     */
    func differ(other: LCType) throws -> LCType
}