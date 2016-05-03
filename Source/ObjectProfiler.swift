//
//  ObjectProfiler.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

class ObjectProfiler {
    /// LCObject class table.
    /// A dictionary of LCObject classes indexed by name.
    static var objectClassTable: [String: LCObject.Type] = [:]

    /**
     Add an LCObject class.

     - parameter aClass: An LCObject class.
     */
    static func addObjectClass(aClass: LCObject.Type) {
        objectClassTable[aClass.className()] = aClass
    }

    /**
     Register LCObject and its subclasses.
     */
    static func registerClasses() {
        var classes = [LCObject.self]

        classes.appendContentsOf(Runtime.subclasses(LCObject.self) as! [LCObject.Type])
        classes.forEach { registerClass($0) }
    }

    static func registerClass(aClass: LCObject.Type) {
        synthesizeProperties(aClass)
        addObjectClass(aClass)
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

     - parameter property: The property to be inspected.

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
        let property = class_getProperty(object_getClass(object), propertyName)

        if property != nil {
            return getLCType(property: property)
        } else {
            return nil
        }
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
        let setterName = "set\(getterName.firstCapitalizedString):"

        let firstLetter = String(getterName[getterName.startIndex])

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
     Check whether a property matches the given type.

     - parameter object:       The object to be inspected.
     - parameter propertyName: The name of property which to be inspected.
     - parameter type:         The expected type.

     - returns: true if property matches the given type, false otherwise.
     */
    static func matchType(object: LCObject, propertyName: String, type: LCType.Type) -> Bool {
        let propertyType = getLCType(object: object, propertyName: propertyName)

        guard propertyType != nil else {
            return false
        }
        guard type == propertyType || Runtime.isSubclass(type, superclass: propertyType) else {
            return false
        }

        return true
    }

    /**
     Validate that whether the given type matches object's property type.

     - parameter object:       The object to be validated.
     - parameter propertyName: The name of property which to be validated.
     - parameter type:         The expected type.
     */
    static func validateType(object: LCObject, propertyName: String, type: LCType.Type) {
        guard matchType(object, propertyName: propertyName, type: type) else {
            /* TODO: throw an exception that types are mismatched. */
            return
        }
    }

    /**
     Update value of an object property.

     - parameter object:       The object which you want to update.
     - parameter propertyName: The property name which you want to update.
     - parameter value:        The new property value.
     */
    static func updateProperty(object: LCObject, _ propertyName: String, _ value: LCType?) {
        let propertyType = getLCType(object: object, propertyName: propertyName)

        /* If object has no such an LCType property, ignore. */
        guard propertyType != nil else {
            return
        }

        var finalValue: LCType?

        if let someValue = value {
            if matchType(object, propertyName: propertyName, type: someValue.dynamicType) {
                finalValue = Runtime.retainedObject(someValue)
            }
        }

        object.willChangeValueForKey(propertyName)
        Runtime.setInstanceVariable(object, propertyName, finalValue)
        object.didChangeValueForKey(propertyName)
    }

    /**
     Get property value of object.

     - parameter object:       The object.
     - parameter propertyName: The property name.
     - parameter type:         The type which the property should be.

     - returns: The property value.
     */
    static func getProperty<T: LCType>(object: LCObject, _ propertyName: String, _ type: T.Type) -> T? {
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
    static func loadProperty<T: LCType>(object: LCObject, _ propertyName: String, _ type: T.Type) -> T {
        let propertyValue = getProperty(object, propertyName, T.self)

        if let propertyValue = propertyValue {
            return propertyValue
        } else {
            let propertyClass = getLCType(object: object, propertyName: propertyName)!
            let propertyValue = propertyClass.instance() as! T

            updateProperty(object, propertyName, propertyValue)

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
    static func deepestNewbornOrphans(object: LCType, parent: LCType?, inout output: Set<LCObject>) -> Bool {
        var hasNewbornOrphan = false

        switch object {
        case let object as LCObject:
            iterateProperties(object) { (_, value) in
                if let value = value {
                    if deepestNewbornOrphans(value, parent: object, output: &output) {
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
            /* TODO: throw an exception that object has circular reference. */
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
            /* TODO: throw an exception that object has circular reference. */
            break
        default: /* Visited */
            break
        }
    }

    /**
     */
    private static func isBoolean(JSONValue: AnyObject) -> Bool {
        switch String(JSONValue.dynamicType) {
        case "__NSCFBoolean", "Bool": return true
        default: return false
        }
    }

    /**
     Map key values dictionary to object.

     - parameter keyValues: A dictionary of keys and values.
     - parameter object:    The target object.
     */
    static func mapKeyValues(keyValues: [String: LCType], _ object: LCObject) {
        keyValues.forEach { (key, value) in
            updateProperty(object, key, value)
        }
    }

    /**
     Get object class by name.

     - parameter className: The name of object class.

     - returns: The class.
     */
    static func objectClass(className: String) -> LCObject.Type {
        return ObjectProfiler.objectClassTable[className]!
    }

    /**
     Create LCObject object for class name.

     - parameter className: The class name of LCObject type.

     - returns: An LCObject object for class name.
     */
    static func object(className className: String) -> LCObject {
        return objectClass(className).instance() as! LCObject
    }

    /**
     Convert a dictionary to an object with specified class name.

     - parameter dictionary: The source dictionary to be converted.
     - parameter className:  The class name.

     - returns: An LCType object.
     */
    private static func object(dictionary dictionary: [String: AnyObject], className: String) -> LCType {
        let result = object(className: className)
        let keyValues = dictionary.mapValue { object(JSONValue: $0) }

        mapKeyValues(keyValues, result)

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
        case .File:
            return object(dictionary: dictionary, className: LCFile.className())
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
        case is NSNull:
            return LCNull.null
        case let object as LCType:
            return object
        default:
            if isBoolean(JSONValue) {
                return LCBool(JSONValue as! Bool)
            } else if let number = JSONValue as? Double {
                return LCNumber(number)
            }
            /* TODO: throw an exception that object can not be recognized. */
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
        case let query as Query:
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
    static func error(JSONValue JSONValue: AnyObject?) -> Error? {
        var result: Error?

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
                result = Error(dictionary: dictionary)
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
    static func updateObject(object: LCObject, _ dictionary: AnyObject) {
        guard var dictionary = dictionary as? [String: AnyObject] else {
            return
        }

        if let createdAt = dictionary["createdAt"] {
            updateProperty(object, "createdAt", LCDate(JSONValue: createdAt))
            dictionary.removeValueForKey("createdAt")
        }

        if let updatedAt = dictionary["updatedAt"] {
            updateProperty(object, "updatedAt", LCDate(JSONValue: updatedAt))
            dictionary.removeValueForKey("updatedAt")
        }

        let keyValues = dictionary.mapValue { self.object(JSONValue: $0) }

        mapKeyValues(keyValues, object)
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
        object.set(ObjectProfiler.propertyName(cmd), value: value)
    }
}