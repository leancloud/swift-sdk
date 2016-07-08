//
//  ObjectProfiler.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

class ObjectProfiler {
    /// Registered object class table indexed by class name.
    static var objectClassTable: [String: LCObject.Type] = [:]

    /**
     Property list table indexed by synthesized class identifier number.

     - note: Any properties declared by superclass are not included in each property list.
     */
    static var propertyListTable: [UInt: [objc_property_t]] = [:]

    /**
     Register an object class.

     - parameter aClass: The object class to be registered.
     */
    static func registerClass(aClass: LCObject.Type) {
        synthesizeProperty(aClass)
        cache(objectClass: aClass)
    }

    /**
     Synthesize all non-computed properties for object class.

     - parameter aClass: The object class need to be synthesized.
     */
    static func synthesizeProperty(aClass: LCObject.Type) {
        let properties = synthesizableProperties(aClass)
        properties.forEach { synthesizeProperty($0, aClass) }
        cache(properties: properties, aClass)
    }

    /**
     Cache an object class.

     - parameter aClass: The class to be cached.
     */
    static func cache(objectClass objectClass: LCObject.Type) {
        objectClassTable[objectClass.objectClassName()] = objectClass
    }

    /**
     Cache a property list.

     - parameter properties: The property list to be cached.
     - parameter aClass:     The class of property list.
     */
    static func cache(properties properties: [objc_property_t], _ aClass: AnyClass) {
        propertyListTable[ObjectIdentifier(aClass).uintValue] = properties
    }

    /**
     Register object classes.

     This method will scan the loaded classes list at runtime to find out object classes.

     - note: When subclass and superclass have the same class name,
             subclass will be registered for the class name.
     */
    static func registerClasses() {
        var classes = [LCObject.self]
        let subclasses = Runtime.subclasses(LCObject.self) as! [LCObject.Type]

        classes.appendContentsOf(subclasses)

        /* Sort classes to make sure subclass will be registered after superclass. */
        classes = Runtime.toposort(classes: classes) as! [LCObject.Type]

        classes.forEach { registerClass($0) }
    }

    /**
     Find all synthesizable properties of object class.

     A synthesizable property must satisfy following conditions:

     * It is a non-computed property.
     * It is a LeanCloud data type property.

     - note: Any synthesizable properties declared by superclass are not included.

     - parameter aClass: The object class.

     - returns: An array of synthesizable properties.
     */
    static func synthesizableProperties(aClass: LCObject.Type) -> [objc_property_t] {
        return Runtime.nonComputedProperties(aClass).filter { hasLCType($0) }
    }

    /**
     Check whether a property has LeanCloud data type.

     - parameter property: Target property.

     - returns: true if property type has LeanCloud data type, false otherwise.
     */
    static func hasLCType(property: objc_property_t) -> Bool {
        return getLCType(property) != nil
    }

    /**
     Get concrete LCType subclass of property.

     - parameter property: The property to be inspected.

     - returns: Concrete LCType subclass, or nil if property type is not LCType.
     */
    static func getLCType(property: objc_property_t) -> LCType.Type? {
        let typeEncoding = Runtime.typeEncoding(property)

        guard typeEncoding.hasPrefix("@\"") else {
            return nil
        }

        let name = typeEncoding[typeEncoding.startIndex.advancedBy(2)..<typeEncoding.endIndex.advancedBy(-1)];

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
        let property = class_getProperty(object_getClass(object), propertyName)

        if property != nil {
            return getLCType(property)
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
        let setterName = "set\(getterName.firstUppercaseString):"

        class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.propertyGetter, IMP.self), "@@:")
        class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.propertySetter, IMP.self), "v@:@")
    }

    /**
     Get deepest descendant newborn orphan objects of an object recursively.

     - parameter object:  The root object.
     - parameter parent:  The parent object for each iteration.
     - parameter visited: The visited objects.
     - parameter output:  A set of deepest descendant newborn orphan objects.

     - returns: true if object has newborn orphan object, false otherwise.
     */
    static func deepestNewbornOrphans(object: LCType, parent: LCType?, inout output: Set<LCObject>) -> Bool {
        var hasNewbornOrphan = false

        switch object {
        case let object as LCObject:
            object.forEachChild { child in
                if deepestNewbornOrphans(child, parent: object, output: &output) {
                    hasNewbornOrphan = true
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
            object.forEachChild { child in
                if deepestNewbornOrphans(child, parent: object, output: &output) {
                    hasNewbornOrphan = true
                }
            }
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

        deepestNewbornOrphans(object, parent: nil, output: &output)
        output.remove(object)

        return output
    }

    /**
     Create toposort for a set of objects.

     - parameter objects: A set of objects need to be sorted.

     - returns: An array of objects ordered by toposort.
     */
    static func toposort(objects: Set<LCObject>) -> [LCObject] {
        var result: [LCObject] = []
        var visitStatusTable: [UInt: Int] = [:]
        toposortStart(objects, &result, &visitStatusTable)
        return result
    }

    private static func toposortStart(objects: Set<LCObject>, inout _ result: [LCObject], inout _ visitStatusTable: [UInt: Int]) {
        objects.forEach { toposortVisit($0, objects, &result, &visitStatusTable) }
    }

    private static func toposortVisit(value: LCType, _ objects: Set<LCObject>, inout _ result: [LCObject], inout _ visitStatusTable: [UInt: Int]) {
        guard value is LCObject else {
            value.forEachChild { child in
                toposortVisit(child, objects, &result, &visitStatusTable)
            }
            return
        }

        let object = value as! LCObject
        let key = ObjectIdentifier(object).uintValue

        switch visitStatusTable[key] ?? 0 {
        case 0: /* Unvisited */
            visitStatusTable[key] = 1
            object.forEachChild { child in
                toposortVisit(child, objects, &result, &visitStatusTable)
            }
            visitStatusTable[key] = 2

            if objects.contains(object) {
                result.append(object)
            }
        case 1: /* Visiting */
            Exception.raise(.Inconsistency, reason: "Circular reference.")
            break
        default: /* Visited */
            break
        }
    }

    /**
     Get all objects of an object family.

     This method presumes that there is no circle in object graph.

     - parameter object: The ancestor object.

     - returns: A set of objects in family.
     */
    static func family(object: LCObject) -> Set<LCObject> {
        var result: Set<LCObject> = []
        familyVisit(object, result: &result)
        return result
    }

    private static func familyVisit(value: LCType, inout result: Set<LCObject>) {
        value.forEachChild { child in
            familyVisit(child, result: &result)
        }

        if let object = value as? LCObject {
            result.insert(object)
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
            Exception.raise(.Inconsistency, reason: "Circular reference.")
            break
        default: /* Visited */
            break
        }
    }

    /**
     Check whether value is a boolean.

     - parameter JSONValue: The value to check.

     - returns: true if value is a boolean, false otherwise.
     */
    private static func isBoolean(JSONValue: AnyObject) -> Bool {
        switch String(JSONValue.dynamicType) {
        case "__NSCFBoolean", "Bool": return true
        default: return false
        }
    }

    /**
     Get object class by name.

     - parameter className: The name of object class.

     - returns: The class.
     */
    static func objectClass(className: String) -> LCObject.Type? {
        return ObjectProfiler.objectClassTable[className]
    }

    /**
     Create LCObject object for class name.

     - parameter className: The class name of LCObject type.

     - returns: An LCObject object for class name.
     */
    static func object(className className: String) -> LCObject {
        if let objectClass = objectClass(className) {
            return objectClass.init()
        } else {
            return LCObject(className: className)
        }
    }

    /**
     Convert a dictionary to an object with specified class name.

     - parameter dictionary: The source dictionary to be converted.
     - parameter className:  The object class name.

     - returns: An LCObject object.
     */
    static func object(dictionary dictionary: [String: AnyObject], className: String) -> LCObject {
        let result = object(className: className)
        let keyValues = dictionary.mapValue { object(JSONValue: $0) }

        keyValues.forEach { (key, value) in
            result.update(key, value)
        }

        return result
    }

    /**
     Convert a dictionary to an object of specified data type.

     - parameter dictionary: The source dictionary to be converted.
     - parameter dataType:   The data type.

     - returns: An LCType object, or nil if object can not be decoded.
     */
    static func object(dictionary dictionary: [String: AnyObject], dataType: RESTClient.DataType) -> LCType? {
        switch dataType {
        case .Object, .Pointer:
            let className = dictionary["className"] as! String

            return object(dictionary: dictionary, className: className)
        case .Relation:
            return LCRelation(dictionary: dictionary)
        case .GeoPoint:
            return LCGeoPoint(dictionary: dictionary)
        case .Bytes:
            return LCData(dictionary: dictionary)
        case .Date:
            return LCDate(dictionary: dictionary)
        }
    }

    /**
     Convert a dictionary to an LCType object.

     - parameter dictionary: The source dictionary to be converted.

     - returns: An LCType object.
     */
    private static func object(dictionary dictionary: [String: AnyObject]) -> LCType {
        var result: LCType!

        if let type = dictionary["__type"] as? String {
            if let dataType = RESTClient.DataType(rawValue: type) {
                result = object(dictionary: dictionary, dataType: dataType)
            }
        }

        if result == nil {
            result = LCDictionary(dictionary.mapValue { object(JSONValue: $0) })
        }

        return result
    }

    /**
     Convert JSON value to LCType object.

     - parameter JSONValue: The JSON value.

     - returns: An LCType object of the corresponding JSON value.
     */
    static func object(JSONValue JSONValue: AnyObject) -> LCType {
        switch JSONValue {
        case let string as String:
            return LCString(string)
        case let array as [AnyObject]:
            return LCArray(array.map { object(JSONValue: $0) })
        case let dictionary as [String: AnyObject]:
            return object(dictionary: dictionary)
        case let data as NSData:
            return LCData(data)
        case let date as NSDate:
            return LCDate(date)
        case is NSNull:
            return LCNull()
        case let object as LCType:
            return object
        default:
            if isBoolean(JSONValue) {
                return LCBool(JSONValue as! Bool)
            } else if let number = JSONValue as? Double {
                return LCNumber(number)
            }
            Exception.raise(.InvalidType, reason: "Unrecognized object.")
            return LCType()
        }
    }

    /**
     Convert an AnyObject object to JSON value.

     - parameter object: The object to be converted.

     - returns: The JSON value of object.
     */
    static func JSONValue(object: AnyObject) -> AnyObject {
        switch object {
        case let array as [AnyObject]:
            return array.map { JSONValue($0) }
        case let dictionary as [String: AnyObject]:
            return dictionary.mapValue { JSONValue($0) }
        case let object as LCType:
            return object.JSONValue!
        case let query as LCQuery:
            return query.JSONValue
        default:
            return object
        }
    }

    /**
     Find an error in JSON value.

     - parameter JSONValue: The JSON value from which to find the error.

     - returns: An error object, or nil if error not found.
     */
    static func error(JSONValue JSONValue: AnyObject?) -> LCError? {
        var result: LCError?

        switch JSONValue {
        case let array as [AnyObject]:
            for element in array {
                if let error = self.error(JSONValue: element) {
                    result = error
                    break
                }
            }
        case let dictionary as [String: AnyObject]:
            let code  = dictionary["code"]  as? Int
            let error = dictionary["error"] as? String

            if code != nil || error != nil {
                result = LCError(dictionary: dictionary)
            } else {
                for (_, value) in dictionary {
                    if let error = self.error(JSONValue: value) {
                        result = error
                        break
                    }
                }
            }
        default:
            break
        }

        return result
    }

    /**
     Update object with a dictionary.

     - parameter object:     The object to be updated.
     - parameter dictionary: A dictionary of key-value pairs.
     */
    static func updateObject(object: LCObject, _ dictionary: [String: AnyObject]) {
        dictionary.forEach { (key, value) in
            object.update(key, self.object(JSONValue: value))
        }
    }

    /**
     Get property name from a setter selector.

     - parameter selector: The setter selector.

     - returns: A property name correspond to the setter selector.
     */
    static func propertyName(setter: Selector) -> String {
        var propertyName = NSStringFromSelector(setter)

        propertyName = propertyName.substringFromIndex(propertyName.startIndex.advancedBy(3))
        propertyName = propertyName.substringToIndex(propertyName.endIndex.advancedBy(-1))

        return propertyName
    }

    /**
     Getter implementation of LeanCloud data type property.
     */
    static let propertyGetter: @convention(c) (LCObject!, Selector) -> LCType? = {
        (object: LCObject!, cmd: Selector) -> LCType? in
        return object.get(NSStringFromSelector(cmd))
    }

    /**
     Setter implementation of LeanCloud data type property.
     */
    static let propertySetter: @convention(c) (LCObject!, Selector, LCType?) -> Void = {
        (object: LCObject!, cmd: Selector, value: LCType?) -> Void in
        let key = ObjectProfiler.propertyName(cmd)

        if ObjectProfiler.getLCType(object: object, propertyName: key) == nil {
            object.set(key.firstLowercaseString, value: value)
        } else {
            object.set(key, value: value)
        }
    }
}