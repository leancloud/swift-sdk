//
//  ObjectProfiler.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

func keyFromSetter(selector: Selector) -> String {
    var capitalizedKey = selector.description

    capitalizedKey = capitalizedKey.substringFromIndex(capitalizedKey.startIndex.advancedBy(3))
    capitalizedKey = capitalizedKey.substringToIndex(capitalizedKey.endIndex.advancedBy(-1))

    let headString = capitalizedKey.substringToIndex(capitalizedKey.startIndex.advancedBy(1)).lowercaseString
    let tailString = capitalizedKey.substringFromIndex(capitalizedKey.startIndex.advancedBy(1))

    return "\(headString)\(tailString)"
}

class ObjectProfiler {
    /**
     Register all subclasses.
     */
    static func registerSubclasses() {
        let subclasses = Runtime.subclasses(LCObject.self)

        for subclass in subclasses {
            self.synthesizeProperties(subclass)
        }
    }

    /**
     Synthesize all non-computed properties for class.

     - parameter aClass: Target class.
     */
    static func synthesizeProperties(aClass: AnyClass) {
        let nonComputedProperties = Runtime.nonComputedProperties(aClass)

        for property in nonComputedProperties {
            self.synthesizeProperty(property, aClass)
        }
    }

    /**
     Synthesize a single property for class.

     - parameter property: Property which to be synthesized.
     - parameter aClass:   Class of property.
     */
    static func synthesizeProperty(property: objc_property_t, _ aClass: AnyClass) {
        let propertyType = Runtime.propertyType(property)
        let propertyName = Runtime.propertyName(property)
        let getterName   = propertyName
        let setterName   = "set\(propertyName.capitalizedString):"

        switch propertyType[propertyType.startIndex] {
        case "c": /* Int8 */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_char, IMP.self), "c@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_char, IMP.self), "v@:c")
        case "i": /* Int32 */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_int, IMP.self), "i@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_int, IMP.self), "v@:i")
        case "s": /* Int16 */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_short, IMP.self), "s@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_short, IMP.self), "v@:s")
        case "l": /* Int64 or Int32 based on platform */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_long, IMP.self), "l@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_long, IMP.self), "v@:l")
        case "q": /* Int64 */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_long_long, IMP.self), "q@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_long_long, IMP.self), "v@:q")
        case "C": /* UInt8 */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_unsigned_char, IMP.self), "C@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_unsigned_char, IMP.self), "v@:C")
        case "I": /* UInt32 */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_unsigned_int, IMP.self), "I@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_unsigned_int, IMP.self), "v@:I")
        case "S": /* UInt16 */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_unsigned_short, IMP.self), "S@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_unsigned_short, IMP.self), "v@:S")
        case "L": /* Int64 or Int32 based on platform */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_unsigned_long, IMP.self), "L@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_unsigned_long, IMP.self), "v@:L")
        case "Q": /* UInt64 */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_unsigned_long_long, IMP.self), "Q@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_unsigned_long_long, IMP.self), "v@:Q")
        case "f": /* Float */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_float, IMP.self), "f@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_float, IMP.self), "v@:f")
        case "d": /* Double or Float64 */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_double, IMP.self), "d@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_double, IMP.self), "v@:d")
        case "B": /* Bool */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_bool, IMP.self), "B@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_bool, IMP.self), "v@:B")
        case "@": /* String, Array, Dictionary etc. */
            class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.get_object, IMP.self), "@@:")
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.set_object, IMP.self), "v@:@")
        default:
            let className    = String(UTF8String: class_getName(aClass))!
            let errorMessage = "Can not synthesize property \(className)#\(propertyName), type not supported."

            print(errorMessage)
        }
    }

    // Mark: Implementations for hooking

    static let get_char: @convention(c) (AnyObject!, Selector) -> CChar = {
        (self_: AnyObject!, cmd: Selector) -> CChar in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).charValue
    }

    static let set_char: @convention(c) (AnyObject!, Selector, CChar) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CChar) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(char: value), forKey:keyFromSetter(cmd))
    }

    static let get_int: @convention(c) (AnyObject!, Selector) -> CInt = {
        (self_: AnyObject!, cmd: Selector) -> CInt in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).intValue
    }

    static let set_int: @convention(c) (AnyObject!, Selector, CInt) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CInt) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(int: value), forKey:keyFromSetter(cmd))
    }

    static let get_short: @convention(c) (AnyObject!, Selector) -> CShort = {
        (self_: AnyObject!, cmd: Selector) -> CShort in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).shortValue
    }

    static let set_short: @convention(c) (AnyObject!, Selector, CShort) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CShort) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(short: value), forKey:keyFromSetter(cmd))
    }

    static let get_long: @convention(c) (AnyObject!, Selector) -> CLong = {
        (self_: AnyObject!, cmd: Selector) -> CLong in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).longValue
    }

    static let set_long: @convention(c) (AnyObject!, Selector, CLong) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CLong) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(long: value), forKey:keyFromSetter(cmd))
    }

    static let get_long_long: @convention(c) (AnyObject!, Selector) -> CLongLong = {
        (self_: AnyObject!, cmd: Selector) -> CLongLong in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).longLongValue
    }

    static let set_long_long: @convention(c) (AnyObject!, Selector, CLongLong) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CLongLong) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(longLong: value), forKey:keyFromSetter(cmd))
    }

    static let get_unsigned_char: @convention(c) (AnyObject!, Selector) -> CUnsignedChar = {
        (self_: AnyObject!, cmd: Selector) -> CUnsignedChar in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).unsignedCharValue
    }

    static let set_unsigned_char: @convention(c) (AnyObject!, Selector, CUnsignedChar) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CUnsignedChar) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(unsignedChar: value), forKey:keyFromSetter(cmd))
    }

    static let get_unsigned_int: @convention(c) (AnyObject!, Selector) -> CUnsignedInt = {
        (self_: AnyObject!, cmd: Selector) -> CUnsignedInt in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).unsignedIntValue
    }

    static let set_unsigned_int: @convention(c) (AnyObject!, Selector, CUnsignedInt) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CUnsignedInt) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(unsignedInt: value), forKey:keyFromSetter(cmd))
    }

    static let get_unsigned_short: @convention(c) (AnyObject!, Selector) -> CUnsignedShort = {
        (self_: AnyObject!, cmd: Selector) -> CUnsignedShort in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).unsignedShortValue
    }

    static let set_unsigned_short: @convention(c) (AnyObject!, Selector, CUnsignedShort) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CUnsignedShort) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(unsignedShort: value), forKey:keyFromSetter(cmd))
    }

    static let get_unsigned_long: @convention(c) (AnyObject!, Selector) -> CUnsignedLong = {
        (self_: AnyObject!, cmd: Selector) -> CUnsignedLong in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).unsignedLongValue
    }

    static let set_unsigned_long: @convention(c) (AnyObject!, Selector, CUnsignedLong) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CUnsignedLong) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(unsignedLong: value), forKey:keyFromSetter(cmd))
    }

    static let get_unsigned_long_long: @convention(c) (AnyObject!, Selector) -> CUnsignedLongLong = {
        (self_: AnyObject!, cmd: Selector) -> CUnsignedLongLong in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).unsignedLongLongValue
    }

    static let set_unsigned_long_long: @convention(c) (AnyObject!, Selector, CUnsignedLongLong) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CUnsignedLongLong) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(unsignedLongLong: value), forKey:keyFromSetter(cmd))
    }

    static let get_float: @convention(c) (AnyObject!, Selector) -> CFloat = {
        (self_: AnyObject!, cmd: Selector) -> CFloat in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).floatValue
    }

    static let set_float: @convention(c) (AnyObject!, Selector, CFloat) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CFloat) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(float: value), forKey:keyFromSetter(cmd))
    }

    static let get_double: @convention(c) (AnyObject!, Selector) -> CDouble = {
        (self_: AnyObject!, cmd: Selector) -> CDouble in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).doubleValue
    }

    static let set_double: @convention(c) (AnyObject!, Selector, CDouble) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CDouble) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(double: value), forKey:keyFromSetter(cmd))
    }

    static let get_bool: @convention(c) (AnyObject!, Selector) -> CBool = {
        (self_: AnyObject!, cmd: Selector) -> CBool in
        let object = self_ as! LCObject
        return (object.objectForKey(cmd.description) as! NSNumber).boolValue
    }

    static let set_bool: @convention(c) (AnyObject!, Selector, CBool) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CBool) -> Void in
        let object = self_ as! LCObject
        object.setObject(NSNumber(bool: value), forKey:keyFromSetter(cmd))
    }

    static let get_object: @convention(c) (AnyObject!, Selector) -> AnyObject? = {
        (self_: AnyObject!, cmd: Selector) -> AnyObject? in
        let object = self_ as! LCObject
        return object.objectForKey(cmd.description)
    }

    static let set_object: @convention(c) (AnyObject!, Selector, AnyObject?) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: AnyObject?) -> Void in
        let object = self_ as! LCObject
        object.setObject(value, forKey:keyFromSetter(cmd))
    }
}