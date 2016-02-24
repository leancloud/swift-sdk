//
//  ObjectProfiler.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

class ObjectProfiler {
    /**
     Synthesize all non-computed properties for class.

     - parameter aClass: Target class.
     */
    static func synthesizeProperties(aClass:AnyClass) {
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
        let setterName   = "set\(propertyName.capitalizedString):"

        switch propertyType[propertyType.startIndex] {
        case "c": /* Int8 */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_char, IMP.self), "v@:c")
        case "i": /* Int32 */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_int, IMP.self), "v@:i")
        case "s": /* Int16 */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_short, IMP.self), "v@:s")
        case "l": /* Int64 or Int32 based on platform */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_long, IMP.self), "v@:l")
        case "q": /* Int64 */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_long_long, IMP.self), "v@:q")
        case "C": /* UInt8 */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_unsigned_char, IMP.self), "v@:C")
        case "I": /* UInt32 */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_unsigned_int, IMP.self), "v@:I")
        case "S": /* UInt16 */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_unsigned_short, IMP.self), "v@:S")
        case "L": /* Int64 or Int32 based on platform */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_unsigned_long, IMP.self), "v@:L")
        case "Q": /* UInt64 */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_unsigned_long_long, IMP.self), "v@:Q")
        case "f": /* Float */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_float, IMP.self), "v@:f")
        case "d": /* Double or Float64 */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_double, IMP.self), "v@:d")
        case "B": /* Bool */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_bool, IMP.self), "v@:B")
        case "@": /* String, Array, Dictionary etc. */
            class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.imp_object, IMP.self), "v@:@")
        default:
            let className    = String(UTF8String: class_getName(aClass))!
            let errorMessage = "Can not synthesize property \(className)#\(propertyName), type not supported."

            print(errorMessage)
        }
    }

    // Mark: Implementations for hooking

    static let imp_char: @convention(c) (AnyObject!, Selector, CChar) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CChar) -> Void in
        let object = self_ as! Object
    }

    static let imp_int: @convention(c) (AnyObject!, Selector, CInt) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CInt) -> Void in
        let object = self_ as! Object
    }

    static let imp_short: @convention(c) (AnyObject!, Selector, CShort) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CShort) -> Void in
        let object = self_ as! Object
    }

    static let imp_long: @convention(c) (AnyObject!, Selector, CLong) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CLong) -> Void in
        let object = self_ as! Object
    }

    static let imp_long_long: @convention(c) (AnyObject!, Selector, CLongLong) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CLongLong) -> Void in
        let object = self_ as! Object
    }

    static let imp_unsigned_char: @convention(c) (AnyObject!, Selector, CUnsignedChar) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CUnsignedChar) -> Void in
        let object = self_ as! Object
    }

    static let imp_unsigned_int: @convention(c) (AnyObject!, Selector, CUnsignedInt) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CUnsignedInt) -> Void in
        let object = self_ as! Object
    }

    static let imp_unsigned_short: @convention(c) (AnyObject!, Selector, CUnsignedShort) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CUnsignedShort) -> Void in
        let object = self_ as! Object
    }

    static let imp_unsigned_long: @convention(c) (AnyObject!, Selector, CUnsignedLong) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CUnsignedLong) -> Void in
        let object = self_ as! Object
    }

    static let imp_unsigned_long_long: @convention(c) (AnyObject!, Selector, CUnsignedLongLong) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CUnsignedLongLong) -> Void in
        let object = self_ as! Object
    }

    static let imp_float: @convention(c) (AnyObject!, Selector, CFloat) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CFloat) -> Void in
        let object = self_ as! Object
    }

    static let imp_double: @convention(c) (AnyObject!, Selector, CDouble) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: CDouble) -> Void in
        let object = self_ as! Object
    }

    static let imp_bool: @convention(c) (AnyObject!, Selector, Bool) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: Bool) -> Void in
        let object = self_ as! Object
    }

    static let imp_object: @convention(c) (AnyObject!, Selector, AnyObject?) -> Void = {
        (self_: AnyObject!, cmd: Selector, value: AnyObject?) -> Void in
        let object = self_ as! Object
    }
}