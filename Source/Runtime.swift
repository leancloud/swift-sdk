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
    static func isSubclass(subclass: AnyClass?, superclass: AnyClass?) -> Bool {
        if subclass == nil {
            return false
        }

        if class_getSuperclass(subclass) == superclass {
            return true
        }

        return isSubclass(class_getSuperclass(subclass), superclass: superclass)
    }

    /**
     Get all subclasses of a base class.

     - parameter baseclass: A base class.

     - returns: All subclasses of given base class.
     */
    static func subclasses(baseclass: AnyClass?) -> [AnyClass] {
        var result = [AnyClass]()

        let count = objc_getClassList(nil, 0)

        guard count > 0 else {
            return result
        }

        let classes = AutoreleasingUnsafeMutablePointer<AnyClass?>(malloc(sizeof(AnyClass) * Int(count)));

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
     Get all properties of a class.

     - parameter aClass: Target class.

     - returns: An array of all properties of the given class.
     */
    static func properties(aClass: AnyClass) -> [objc_property_t] {
        var result = [objc_property_t]()

        var count: UInt32 = 0
        let properties: UnsafeMutablePointer<objc_property_t> = class_copyPropertyList(aClass, &count)

        for i in 0..<Int(count) {
            result.append(properties[i])
        }

        return result
    }

    /**
     Get all non-computed properties of a class.

     - parameter aClass: Inpected class.

     - returns: An array of all non-computed properties of the given class.
     */
    static func nonComputedProperties(aClass: AnyClass) -> [objc_property_t] {
        let properties = self.properties(aClass)

        return properties.filter({ (property) -> Bool in
            property_copyAttributeValue(property, "V") != nil
        })
    }

    /**
     Get property type string.

     - parameter property: Inspected property.
     */
    static func propertyType(property: objc_property_t) -> String {
        return String(UTF8String: property_copyAttributeValue(property, "T"))!
    }

    /**
     Get property name.

     - parameter property: Inspected property.
     */
    static func propertyName(property: objc_property_t) -> String {
        return String(UTF8String: property_getName(property))!
    }
}