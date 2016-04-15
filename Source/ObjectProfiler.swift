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
     Register all subclasses.
     */
    static func registerSubclasses() {
        Runtime.subclasses(LCObject.self).forEach { synthesizeProperties($0) }
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
        return Runtime.nonComputedProperties(aClass).filter { isLCType(property: $0) }
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

     - returns: Concrete LCType subclass, or nil if property type is not LCType.
     */
    static func getLCType(property property: objc_property_t) -> LCType.Type? {
        let propertyType = Runtime.propertyType(property)

        guard propertyType.hasPrefix("@\"") else {
            return nil
        }

        let name = propertyType[propertyType.startIndex.advancedBy(2)..<propertyType.endIndex.advancedBy(-1)];

        if let subclass = objc_getClass(name) as? AnyClass {
            if Runtime.isSubclass(subclass, superclass: LCType.self) {
                return subclass as? LCType.Type
            }
        }

        return nil
    }

    /**
     Get concrete LCType subclass of an object property.

     - parameter object:       Target object.
     - parameter propertyName: The name of property to be inspected.

     - returns: Concrete LCType subclass, or nil if property type is not LCType.
     */
    static func getLCType(object object: LCObject, propertyName: String) -> LCType.Type? {
        return getLCType(property: class_getProperty(object_getClass(object), propertyName))
    }

    /**
     Check whether an object has a LCType property for given name.

     - parameter object:       The object.
     - parameter propertyName: The property name.

     - returns: true if object has such a property, false otherwise.
     */
    static func hasProperty(object: LCObject, propertyName: String) -> Bool {
        return getLCType(object: object, propertyName: propertyName) != nil
    }

    /**
     Synthesize a single property for class.

     - parameter property: Property which to be synthesized.
     - parameter aClass:   Class of property.
     */
    static func synthesizeProperty(property: objc_property_t, _ aClass: AnyClass) {
        let getterName = Runtime.propertyName(property)
        let setterName = "set\(getterName.capitalizedString):"

        let firstLetter = String(getterName.characters.first)

        /* The property name must be lowercase prefixed, or synthesization will be ambiguous. */
        if firstLetter.lowercaseString != firstLetter {
            /* TODO: throw an exception. */
        }

        class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.propertySetter, IMP.self), "v@:@")
    }

    /**
     Iterate properties of object.

     - parameter object: The object which you want to iterate.
     - parameter block:  A callback block for each property name and property value.
     */
    static func iterateProperties(object: LCObject, block: (String, LCType?) -> ()) {
        let properties = ObjectProfiler.synthesizableProperties(object_getClass(object))

        properties.forEach { (property) in
            let propertyName  = Runtime.propertyName(property)
            let propertyValue = Runtime.instanceVariableValue(object, propertyName) as? LCType

            block(propertyName, propertyValue)
        }
    }

    /**
     Validate that whether the given type matches object's property type.

     - parameter object:       The object.
     - parameter propertyName: The property name.
     - parameter type:         The type which you want to validate.
     */
    static func validateType(object: LCObject, propertyName: String, type: LCType.Type) {
        let propertyType = getLCType(object: object, propertyName: propertyName)

        guard type == propertyType || Runtime.isSubclass(type, superclass: propertyType) else {
            /* TODO: throw an exception that types are mismatched. */
            return
        }
    }

    /**
     Validate that whether the given value matches object's property type.

     - parameter object:       The object.
     - parameter propertyName: The property name.
     - parameter value:        The value which you want to validate.
     */
    static func validateType(object: LCObject, propertyName: String, value: LCType) {
        validateType(object, propertyName: propertyName, type: object_getClass(value) as! LCType.Type)
    }

    /**
     Update value of an object property.

     - parameter object:        The object which you want to update.
     - parameter propertyName:  The property name which you want to update.
     - parameter propertyValue: The new property value.
     */
    static func updateProperty(object: LCObject, _ propertyName: String, _ propertyValue: LCType?) {
        if let propertyValue = propertyValue {
            validateType(object, propertyName: propertyName, value: propertyValue)
            Runtime.setInstanceVariable(object, propertyName, Runtime.retainedObject(propertyValue))
        } else {
            Runtime.setInstanceVariable(object, propertyName, nil)
        }
    }

    /**
     Get property value of object.

     - parameter object:       The object.
     - parameter propertyName: The property name.
     - parameter type:         The type which the property should be.

     - returns: The property value.
     */
    static func getPropertyValue<T: LCType>(object: LCObject, _ propertyName: String, _ type: T.Type) -> T? {
        validateType(object, propertyName: propertyName, type: type)

        return Runtime.instanceVariableValue(object, propertyName) as? T
    }

    /**
     Load property value of object with initialization if needed.

     - parameter object:       The object.
     - parameter propertyName: The property name.
     - parameter type:         The type which the property should be.

     - returns: The property value.
     */
    static func loadPropertyValue<T: LCType>(object: LCObject, _ propertyName: String, _ type: T.Type) -> T {
        validateType(object, propertyName: propertyName, type: type)

        if let propertyValue = getPropertyValue(object, propertyName, T.self) {
            return propertyValue
        } else {
            let property = class_getProperty(object_getClass(object), propertyName)

            let propertyClass = ObjectProfiler.getLCType(property: property) as! T.Type
            let propertyValue = propertyClass.init()

            Runtime.setInstanceVariable(object, propertyName, Runtime.retainedObject(propertyValue))

            return propertyValue
        }
    }

    /**
     Get deepest descendant newborn orphan objects of an object recursively.

     - parameter object:  The root object.
     - parameter parent:  The parent object for each iteration.
     - parameter visited: The visited objects.
     - parameter output:  A set of deepest descendant newborn orphan objects.

     - returns: true if object has newborn orphan object, false otherwise.
     */
    static func deepestNewbornOrphans(object: LCType, parent: LCType?, inout visited: Set<LCObject>, inout output: Set<LCObject>) -> Bool {
        var hasNewbornOrphan = false

        switch object {
        case let list as LCArray:
            list.forEach {
                if deepestNewbornOrphans($0, parent: list, visited: &visited, output: &output) {
                    hasNewbornOrphan = true
                }
            }
        case let dictionary as LCDictionary:
            dictionary.forEach {
                if deepestNewbornOrphans($1, parent: dictionary, visited: &visited, output: &output) {
                    hasNewbornOrphan = true
                }
            }
        case let object as LCObject:
            if visited.contains(object) {
                /* TODO: Throw an exception that objects are twisted together. */
            } else {
                visited.insert(object)
            }

            iterateProperties(object) { (_, value) in
                if let value = value {
                    if deepestNewbornOrphans(value, parent: object, visited: &visited, output: &output) {
                        hasNewbornOrphan = true
                    }
                }
            }

            /* Check if object is a newborn orphan.
               If parent is not an LCObject, we think that it is an orphan. */
            if !object.hasObjectId && !(parent is LCObject) {
                if !hasNewbornOrphan {
                    output.insert(object)
                }

                hasNewbornOrphan = true
            }
        default:
            break
        }

        return hasNewbornOrphan
    }

    /**
     Get deepest descendant newborn orphan objects.

     - parameter object: The root object.

     - returns: A set of deepest descendant newborn orphan objects.
     */
    static func deepestNewbornOrphans(object: LCObject) -> Set<LCObject> {
        var output: Set<LCObject> = []
        var visited: Set<LCObject> = []

        deepestNewbornOrphans(object, parent: nil, visited: &visited, output: &output)
        output.remove(object)

        return output
    }

    /**
     Iterate object and its descendant objects by DFS.

     - parameter object: The root object to iterate.
     - parameter depth:  The max iteration depth.
     - parameter body:   The closure to call for each iteration.
     */
    static func iterateObject(object: LCObject, depth: Int, body: (object: LCObject) -> Void) {
        iterateObject(object, depth: depth, currentDepth: 0, body: body)
        body(object: object)
    }

    /**
     Iterate descendant objects of an object by DFS.

     - parameter object:       The root object to iterate.
     - parameter depth:        The max iteration depth.
     - parameter currentDepth: The depth value of each iteration.
     - parameter body:         The closure to call for each iteration.
     */
    static func iterateObject(object: LCType, depth: Int, currentDepth: Int, body: (object: LCObject) -> Void) {
        object.forEachChild { (child) in
            if let object = child as? LCObject {
                if depth >= 0 && currentDepth >= depth {
                    return
                }
                iterateObject(object, depth: depth, currentDepth: currentDepth + 1, body: body)
                body(object: object)
            } else {
                iterateObject(child, depth: depth, currentDepth: currentDepth, body: body)
            }
        }
    }

    /**
     Validate circular reference in object graph.

     This method will check object and its all descendant objects.

     - parameter object: The object to validate.
     */
    static func validateCircularReference(object: LCObject) {
        var visitStatusTable: [UInt: Int] = [:]
        validateCircularReference(object, visitStatusTable: &visitStatusTable)
    }

    /**
     Validate circular reference in object graph iteratively.

     - parameter object: The object to validate.
     - parameter visitStatusTable: The object visit status table.
     */
    private static func validateCircularReference(object: LCType, inout visitStatusTable: [UInt: Int]) {
        let key = ObjectIdentifier(object).uintValue

        switch visitStatusTable[key] ?? 0 {
        case 0: /* Unvisited */
            visitStatusTable[key] = 1
            object.forEachChild { (child) in
                validateCircularReference(child, visitStatusTable: &visitStatusTable)
            }
            visitStatusTable[key] = 2
        case 1: /* Visiting */
            /* TODO: throw an exception that object has circular reference. */
            break
        default: /* Visited */
            break
        }
    }

    /**
     Get property name from a setter selector.

     - parameter selector: The setter selector.

     - returns: A property name correspond to the setter selector.
     */
    static func propertyName(selector: Selector) -> String {
        var capitalizedKey = selector.description

        capitalizedKey = capitalizedKey.substringFromIndex(capitalizedKey.startIndex.advancedBy(3))
        capitalizedKey = capitalizedKey.substringToIndex(capitalizedKey.endIndex.advancedBy(-1))

        let headString = capitalizedKey.substringToIndex(capitalizedKey.startIndex.advancedBy(1)).lowercaseString
        let tailString = capitalizedKey.substringFromIndex(capitalizedKey.startIndex.advancedBy(1))

        return "\(headString)\(tailString)"
    }

    /**
     Setter implementation of LeanCloud data type property.
     */
    static let propertySetter: @convention(c) (LCObject!, Selector, LCType?) -> Void = {
        (object: LCObject!, cmd: Selector, value: LCType?) -> Void in
        let propertyName = ObjectProfiler.propertyName(cmd)

        if value == nil {
            object.addOperation(.Delete, propertyName, nil)
        } else {
            object.addOperation(.Set, propertyName, value)
        }
    }
}