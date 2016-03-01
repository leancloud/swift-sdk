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
        Runtime.subclasses(LCObject.self).forEach({ synthesizeProperties($0) })
    }

    /**
     Synthesize all non-computed properties for class.

     - parameter aClass: Target class.
     */
    static func synthesizeProperties(aClass: AnyClass) {
        synthesizableProperties(aClass).forEach { synthesizeProperty($0, aClass) }
    }

    /**
     Find all synthesizable properties of a class.

     A synthesizable property must satisfy following conditions:

     * It is a non-computed property.
     * It is a LeanCloud data type property.

     - parameter aClass: Target class.
     */
    static func synthesizableProperties(aClass: AnyClass) -> [objc_property_t] {
        return Runtime.nonComputedProperties(aClass).filter({ isLCType(property: $0) })
    }

    /**
     Check whether a property type is LeanCloud data type.

     - parameter property: Target property.

     - returns: true if property type is LeanCloud data type, false otherwise.
     */
    static func isLCType(property property: objc_property_t) -> Bool {
        return getLCType(property: property) != nil
    }

    /**
     Get concrete LCType subclass of property.

     - parameter property: Target property.

     - returns: Concreate LCType subclass, or nil if property type is not LCType.
     */
    static func getLCType(property property: objc_property_t) -> AnyClass? {
        let propertyType = Runtime.propertyType(property)

        guard propertyType.hasPrefix("@\"") else {
            return nil
        }

        let name = propertyType[Range(start: propertyType.startIndex.advancedBy(2), end: propertyType.endIndex.advancedBy(-1))];
        let subclass: AnyClass = objc_getClass(name) as! AnyClass

        if Runtime.isSubclass(subclass, superclass: LCType.self) {
            return subclass
        } else {
            return nil
        }
    }

    /**
     Synthesize a single property for class.

     - parameter property: Property which to be synthesized.
     - parameter aClass:   Class of property.
     */
    static func synthesizeProperty(property: objc_property_t, _ aClass: AnyClass) {
        let getterName = Runtime.propertyName(property)
        let setterName = "set\(getterName.capitalizedString):"

        class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.propertyGetter, IMP.self), "@@:")
        class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.propertySetter, IMP.self), "v@:@")
    }

    /**
     Initialize LeanCloud data type property of LCObject.

     - parameter object:       The object which you want to initialize.
     - parameter propertyName: The name of property.

     - returns: Initialized value.
     */
    static func initializeProperty(object: LCObject, _ propertyName: String) -> LCType {
        let property = class_getProperty(object_getClass(object), propertyName)

        let propertyClass = ObjectProfiler.getLCType(property: property) as! LCType.Type
        let propertyValue = Unmanaged.passRetained(propertyClass.init()).takeUnretainedValue()

        object_setIvar(object, Runtime.instanceVariable(object_getClass(object), propertyName), propertyValue)

        return propertyValue
    }

    /**
     Bind all unbound LCType properties of an object to object.

     This method iterates all LCType properties of an LCType object and adds reverse binding on these properties.

     - parameter object: Parent object.
     */
    static func bindParent(object: LCType) {
        synthesizableProperties(object_getClass(object)).forEach { (property) in
            let propertyName = Runtime.propertyName(property)

            if let propertyValue = Runtime.instanceVariableValue(object, propertyName) as? LCType {
                bindParent(object, propertyName, propertyValue)
            }
        }
    }

    /**
     Bind a property to an object.

     - parameter object:        The object where you want to bind.
     - parameter propertyName:  The property name which you want to bind.
     - parameter propertyValue: The property value.
     */
    static func bindParent(object: LCType, _ propertyName: String, _ propertyValue: LCType) {
        let parent = LCType.Parent(object: object, propertyName: propertyName)

        if let previousParent = propertyValue.parent {
            if previousParent != parent {
                /* TODO: throw an exception. */
            }
        } else {
            propertyValue.parent = parent
        }
    }

    /**
     Getter implementation of LeanCloud data type property.
     */
    static let propertyGetter: @convention(c) (LCObject!, Selector) -> LCType = {
        (object: LCObject!, cmd: Selector) -> LCType in
        let propertyName  = NSStringFromSelector(cmd)
        var propertyValue = Runtime.instanceVariableValue(object, propertyName) as? LCType

        if propertyValue == nil {
            propertyValue = ObjectProfiler.initializeProperty(object, propertyName)
        }

        ObjectProfiler.bindParent(object, propertyName, propertyValue!)

        return propertyValue!
    }

    /**
     Setter implementation of LeanCloud data type property.
     */
    static let propertySetter: @convention(c) (LCObject!, Selector, LCType?) -> Void = {
        (object: LCObject!, cmd: Selector, value: LCType?) -> Void in
        /* Stub method. */
    }
}