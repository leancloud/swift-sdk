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

/**
 Extension of LCType.

 By convention, all types that confirm `LCType` must also confirm `LCTypeExtension`.
 */
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

/**
 Convertible protocol for `LCType`.
 */
public protocol LCTypeConvertible {
    /**
     Get the `LCType` value for current object.
     */
    var lcType: LCType { get }
}

/**
 Convertible protocol for `LCNull`.
 */
public protocol LCNullConvertible: LCTypeConvertible {
    var lcNull: LCNull { get }
}

/**
 Convertible protocol for `LCNumber`.
 */
public protocol LCNumberConvertible: LCTypeConvertible {
    var lcNumber: LCNumber { get }
}

/**
 Convertible protocol for `LCBool`.
 */
public protocol LCBoolConvertible: LCTypeConvertible {
    var lcBool: LCBool { get }
}

/**
 Convertible protocol for `LCString`.
 */
public protocol LCStringConvertible: LCTypeConvertible {
    var lcString: LCString { get }
}

/**
 Convertible protocol for `LCArray`.
 */
public protocol LCArrayConvertible: LCTypeConvertible {
    var lcArray: LCArray { get }
}

/**
 Convertible protocol for `LCDictionary`.
 */
public protocol LCDictionaryConvertible: LCTypeConvertible {
    var lcDictionary: LCDictionary { get }
}

/**
 Convertible protocol for `LCData`.
 */
public protocol LCDataConvertible: LCTypeConvertible {
    var lcData: LCData { get }
}

/**
 Convertible protocol for `LCDate`.
 */
public protocol LCDateConvertible: LCTypeConvertible {
    var lcDate: LCDate { get }
}

extension NSNull: LCNullConvertible {
    public var lcType: LCType {
        return lcNull
    }

    public var lcNull: LCNull {
        return LCNull()
    }
}

extension Int: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension UInt: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension Int8: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension UInt8: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension Int16: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension UInt16: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension Int32: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension UInt32: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension Int64: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension UInt64: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension Float: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension Float80: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension Double: LCNumberConvertible {
    public var lcType: LCType {
        return lcNumber
    }

    public var lcNumber: LCNumber {
        return LCNumber(Double(self))
    }
}

extension Bool: LCBoolConvertible {
    public var lcType: LCType {
        return lcBool
    }

    public var lcBool: LCBool {
        return LCBool(self)
    }
}

extension NSNumber: LCNumberConvertible, LCBoolConvertible {
    public var lcType: LCType {
        return try! ObjectProfiler.object(JSONValue: self)
    }

    public var lcNumber: LCNumber {
        return LCNumber(self.doubleValue)
    }

    public var lcBool: LCBool {
        return LCBool(self.boolValue)
    }
}

extension String: LCStringConvertible {
    public var lcType: LCType {
        return lcString
    }

    public var lcString: LCString {
        return LCString(self)
    }
}

extension NSString: LCStringConvertible {
    public var lcType: LCType {
        return lcString
    }

    public var lcString: LCString {
        return LCString(String(self))
    }
}

extension Array: LCArrayConvertible {
    public var lcType: LCType {
        return lcArray
    }

    public var lcArray: LCArray {
        let value = try! map { element -> LCType in
            guard let element = element as? LCTypeConvertible else {
                throw LCError(code: .InvalidType, reason: "Element is not LCType-convertible.", userInfo: nil)
            }
            return element.lcType
        }

        return LCArray(value)
    }
}

extension NSArray: LCArrayConvertible {
    public var lcType: LCType {
        return lcArray
    }

    public var lcArray: LCArray {
        return (self as Array).lcArray
    }
}

extension Dictionary: LCDictionaryConvertible {
    public var lcType: LCType {
        return lcDictionary
    }

    public var lcDictionary: LCDictionary {
        let elements = try! map { (key, value) -> (String, LCType) in
            guard let key = key as? String else {
                throw LCError(code: .InvalidType, reason: "Key is not a string.", userInfo: nil)
            }
            guard let value = value as? LCTypeConvertible else {
                throw LCError(code: .InvalidType, reason: "Value is not LCType-convertible.", userInfo: nil)
            }
            return (key, value.lcType)
        }
        let value = [String: LCType](elements: elements)

        return LCDictionary(value)
    }
}

extension NSDictionary: LCDictionaryConvertible {
    public var lcType: LCType {
        return lcDictionary
    }

    public var lcDictionary: LCDictionary {
        return (self as Dictionary).lcDictionary
    }
}

extension NSData: LCDataConvertible {
    public var lcType: LCType {
        return lcData
    }

    public var lcData: LCData {
        return LCData(self)
    }
}

extension NSDate: LCDateConvertible {
    public var lcType: LCType {
        return lcDate
    }

    public var lcDate: LCDate {
        return LCDate(self)
    }
}

extension LCNull: LCTypeConvertible, LCNullConvertible {
    public var lcType: LCType {
        return self
    }

    public var lcNull: LCNull {
        return self
    }
}

extension LCNumber: LCTypeConvertible, LCNumberConvertible {
    public var lcType: LCType {
        return self
    }

    public var lcNumber: LCNumber {
        return self
    }
}

extension LCBool: LCTypeConvertible, LCBoolConvertible {
    public var lcType: LCType {
        return self
    }

    public var lcBool: LCBool {
        return self
    }
}

extension LCString: LCTypeConvertible, LCStringConvertible {
    public var lcType: LCType {
        return self
    }

    public var lcString: LCString {
        return self
    }
}

extension LCArray: LCTypeConvertible, LCArrayConvertible {
    public var lcType: LCType {
        return self
    }

    public var lcArray: LCArray {
        return self
    }
}

extension LCDictionary: LCTypeConvertible, LCDictionaryConvertible {
    public var lcType: LCType {
        return self
    }

    public var lcDictionary: LCDictionary {
        return self
    }
}

extension LCObject: LCTypeConvertible {
    public var lcType: LCType {
        return self
    }
}

extension LCRelation: LCTypeConvertible {
    public var lcType: LCType {
        return self
    }
}

extension LCGeoPoint: LCTypeConvertible {
    public var lcType: LCType {
        return self
    }
}

extension LCData: LCTypeConvertible, LCDataConvertible {
    public var lcType: LCType {
        return self
    }

    public var lcData: LCData {
        return self
    }
}

extension LCDate: LCTypeConvertible, LCDateConvertible {
    public var lcType: LCType {
        return self
    }

    public var lcDate: LCDate {
        return self
    }
}