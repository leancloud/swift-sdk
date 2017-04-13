//
//  Runtime.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

class Runtime {
    /**
     Check whether a class is subclass of another class.

     - parameter subclass:   Inspected subclass.
     - parameter superclass: Superclass which to compare with.

     - returns: true or false.
     */
    static func isSubclass(_ subclass: AnyClass!, superclass: AnyClass!) -> Bool {
        guard let superclass = superclass else {
            return false
        }

        var eachSubclass: AnyClass! = subclass

        while let eachSuperclass = class_getSuperclass(eachSubclass) {
            /* Use ObjectIdentifier instead of `===` to make identity test.
               Because some types cannot respond to `===`, like WKObject in WebKit framework. */
            if ObjectIdentifier(eachSuperclass) == ObjectIdentifier(superclass) {
                return true
            }
            eachSubclass = eachSuperclass
        }

        return false
    }

    /**
     Get all subclasses of a base class.

     - parameter baseclass: A base class.

     - returns: All subclasses of given base class.
     */
    static func subclasses(_ baseclass: AnyClass!) -> [AnyClass] {
        var result = [AnyClass]()

        guard let baseclass = baseclass else {
            return result
        }

        let count = objc_getClassList(nil, 0)

        guard count > 0 else {
            return result
        }

        let classes = AutoreleasingUnsafeMutablePointer<AnyClass?>(UnsafeMutablePointer<UInt8>.allocate(capacity: MemoryLayout<AnyClass>.size * Int(count)))

        for i in 0..<Int(objc_getClassList(classes, count)) {
            guard let someclass = classes[i] else {
                continue
            }

            if isSubclass(someclass, superclass: baseclass) {
                result.append(someclass)
            }
        }

        return result
    }

    /**
     Create toposort for classes.

     Superclass will be placed before subclass.

     - parameter classes: An array of classes.

     - returns: The toposort of classes.
     */
    static func toposort(classes: [AnyClass]) -> [AnyClass] {
        var result: [AnyClass] = []
        var visitStatusTable: [UInt: Int] = [:]

        toposortStart(classes: classes, &result, &visitStatusTable)

        return result
    }

    fileprivate static func toposortStart(classes: [AnyClass], _ result: inout [AnyClass], _ visitStatusTable: inout [UInt: Int]) {
        classes.forEach { aClass in
            try! toposortVisit(aClass: aClass, classes, &result, &visitStatusTable)
        }
    }

    fileprivate static func toposortVisit(aClass: AnyClass, _ classes: [AnyClass], _ result: inout [AnyClass], _ visitStatusTable: inout [UInt: Int]) throws {
        let key = UInt(bitPattern: ObjectIdentifier(aClass))

        switch visitStatusTable[key] ?? 0 {
        case 0: /* Unvisited */
            visitStatusTable[key] = 1

            var eachSubclass: AnyClass! = aClass

            while let eachSuperclass = class_getSuperclass(eachSubclass) {
                try! toposortVisit(aClass: eachSuperclass, classes, &result, &visitStatusTable)
                eachSubclass = eachSuperclass
            }

            visitStatusTable[key] = 2

            if classes.contains(where: { $0 === aClass }) {
                result.append(aClass)
            }
        case 1: /* Visiting */
            throw LCError(code: .inconsistency, reason: "Circular reference.", userInfo: nil)
        default: /* Visited */
            break
        }
    }

    /**
     Get all properties of a class.

     - parameter aClass: Target class.

     - returns: An array of all properties of the given class.
     */
    static func properties(_ aClass: AnyClass) -> [objc_property_t] {
        var result = [objc_property_t]()

        var count: UInt32 = 0

        guard let properties = class_copyPropertyList(aClass, &count) else {
            return result
        }

        for i in 0..<Int(count) {
            if let property = properties[i] {
                result.append(property)
            }
        }

        return result
    }

    /**
     Get all non-computed properties of a class.

     - parameter aClass: Inpected class.

     - returns: An array of all non-computed properties of the given class.
     */
    static func nonComputedProperties(_ aClass: AnyClass) -> [objc_property_t] {
        let properties = self.properties(aClass)

        return properties.filter { (property) -> Bool in
            property_copyAttributeValue(property, "V") != nil
        }
    }

    /**
     Get property type encoding.

     - parameter property: Inspected property.
     */
    static func typeEncoding(_ property: objc_property_t) -> String {
        return String(validatingUTF8: property_copyAttributeValue(property, "T"))!
    }

    /**
     Get property name.

     - parameter property: Inspected property.
     */
    static func propertyName(_ property: objc_property_t) -> String {
        return String(validatingUTF8: property_getName(property))!
    }

    /**
     Get property's backing instance variable from a class.

     - parameter aClass:       The class from where you want to get.
     - parameter propertyName: The property name.

     - returns: Instance variable correspond to the property name.
     */
    static func instanceVariable(_ aClass: AnyClass, _ propertyName: String) -> Ivar? {
        let property = class_getProperty(aClass, propertyName)

        if property != nil {
            return class_getInstanceVariable(aClass, property_copyAttributeValue(property, "V"))
        } else {
            return nil
        }
    }

    /**
     Get instance variable value from an object.

     - parameter object:       The object from where you want to get.
     - parameter propertyName: The property name.

     - returns: Value of instance variable correspond to the property name.
     */
    static func instanceVariableValue(_ object: AnyObject, _ propertyName: String) -> AnyObject? {
        let instanceVariable = self.instanceVariable(object_getClass(object), propertyName)

        if instanceVariable != nil {
            return object_getIvar(object, instanceVariable) as AnyObject?
        } else {
            return nil
        }
    }

    /**
     Set instance variable value of a property.

     - parameter object:       The object.
     - parameter propertyName: Property name on which you want to set.
     - parameter value:        New property value.
     */
    static func setInstanceVariable(_ object: AnyObject, _ propertyName: String, _ value: AnyObject?) {
        object_setIvar(object, instanceVariable(object_getClass(object), propertyName), retainedObject(value))
    }

    /**
     Get retained object.

     - parameter object: The object which you want to retain.

     - returns: An retained object.
     */
    static func retainedObject<T: AnyObject>(_ object: T?) -> T? {
        return object != nil ? Unmanaged.passRetained(object!).takeUnretainedValue() : nil
    }
}
