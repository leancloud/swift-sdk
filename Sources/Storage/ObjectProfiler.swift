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
    static func registerClass(_ aClass: LCObject.Type) {
        synthesizeProperty(aClass)
        cache(objectClass: aClass)
    }

    /**
     Synthesize all non-computed properties for object class.

     - parameter aClass: The object class need to be synthesized.
     */
    static func synthesizeProperty(_ aClass: LCObject.Type) {
        let properties = synthesizableProperties(aClass)
        properties.forEach { synthesizeProperty($0, aClass) }
        cache(properties: properties, aClass)
    }

    /**
     Cache an object class.

     - parameter aClass: The class to be cached.
     */
    static func cache(objectClass: LCObject.Type) {
        objectClassTable[objectClass.objectClassName()] = objectClass
    }

    /**
     Cache a property list.

     - parameter properties: The property list to be cached.
     - parameter aClass:     The class of property list.
     */
    static func cache(properties: [objc_property_t], _ aClass: AnyClass) {
        propertyListTable[UInt(bitPattern: ObjectIdentifier(aClass))] = properties
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

        classes.append(contentsOf: subclasses)

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
    static func synthesizableProperties(_ aClass: LCObject.Type) -> [objc_property_t] {
        return Runtime.nonComputedProperties(aClass).filter { hasLCValue($0) }
    }

    /**
     Check whether a property has LeanCloud data type.

     - parameter property: Target property.

     - returns: true if property type has LeanCloud data type, false otherwise.
     */
    static func hasLCValue(_ property: objc_property_t) -> Bool {
        return getLCValue(property) != nil
    }

    /**
     Get concrete LCValue subclass of property.

     - parameter property: The property to be inspected.

     - returns: Concrete LCValue subclass, or nil if property type is not LCValue.
     */
    static func getLCValue(_ property: objc_property_t) -> LCValue.Type? {
        let typeEncoding = Runtime.typeEncoding(property)

        guard typeEncoding.hasPrefix("@\"") else {
            return nil
        }

        let name = typeEncoding[typeEncoding.characters.index(typeEncoding.startIndex, offsetBy: 2)..<typeEncoding.characters.index(typeEncoding.endIndex, offsetBy: -1)]

        if let subclass = objc_getClass(name) as? AnyClass {
            if let type = subclass as? LCValue.Type {
                return type
            }
        }

        return nil
    }

    /**
     Get concrete LCValue subclass of an object property.

     - parameter object:       Target object.
     - parameter propertyName: The name of property to be inspected.

     - returns: Concrete LCValue subclass, or nil if property type is not LCValue.
     */
    static func getLCValue(_ object: LCObject, _ propertyName: String) -> LCValue.Type? {
        let property = class_getProperty(object_getClass(object), propertyName)

        if property != nil {
            return getLCValue(property!)
        } else {
            return nil
        }
    }

    /**
     Check if object has a property of type LCValue for given name.

     - parameter object:       Target object.
     - parameter propertyName: The name of property to be inspected.

     - returns: true if object has a property of type LCValue for given name, false otherwise.
     */
    static func hasLCValue(_ object: LCObject, _ propertyName: String) -> Bool {
        return getLCValue(object, propertyName) != nil
    }

    /**
     Synthesize a single property for class.

     - parameter property: Property which to be synthesized.
     - parameter aClass:   Class of property.
     */
    static func synthesizeProperty(_ property: objc_property_t, _ aClass: AnyClass) {
        let getterName = Runtime.propertyName(property)
        let setterName = "set\(getterName.firstUppercaseString):"

        class_replaceMethod(aClass, Selector(getterName), unsafeBitCast(self.propertyGetter, to: IMP.self), "@@:")
        class_replaceMethod(aClass, Selector(setterName), unsafeBitCast(self.propertySetter, to: IMP.self), "v@:@")
    }

    /**
     Iterate all object properties of type LCValue.

     - parameter object: The object to be inspected.
     - parameter body:   The body for each iteration.
     */
    static func iterateProperties(_ object: LCObject, body: (String, objc_property_t) -> Void) {
        var visitedKeys: Set<String> = []
        var aClass: AnyClass? = object_getClass(object)

        repeat {
            guard aClass != nil else { return }

            let properties = propertyListTable[UInt(bitPattern: ObjectIdentifier(aClass!))]

            properties?.forEach { property in
                let key = Runtime.propertyName(property)

                if !visitedKeys.contains(key) {
                    visitedKeys.insert(key)
                    body(key, property)
                }
            }

            aClass = class_getSuperclass(aClass)
        } while aClass != LCObject.self
    }

    /**
     Get deepest descendant newborn orphan objects of an object recursively.

     - parameter object:  The root object.
     - parameter parent:  The parent object for each iteration.
     - parameter visited: The visited objects.
     - parameter output:  A set of deepest descendant newborn orphan objects.

     - returns: true if object has newborn orphan object, false otherwise.
     */
    static func deepestNewbornOrphans(_ object: LCValue, parent: LCValue?, output: inout Set<LCObject>) -> Bool {
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
            (object as! LCValueExtension).forEachChild { child in
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
    static func deepestNewbornOrphans(_ object: LCObject) -> Set<LCObject> {
        var output: Set<LCObject> = []

        _ = deepestNewbornOrphans(object, parent: nil, output: &output)
        output.remove(object)

        return output
    }

    /**
     Create toposort for a set of objects.

     - parameter objects: A set of objects need to be sorted.

     - returns: An array of objects ordered by toposort.
     */
    static func toposort(_ objects: Set<LCObject>) -> [LCObject] {
        var result: [LCObject] = []
        var visitStatusTable: [UInt: Int] = [:]
        toposortStart(objects, &result, &visitStatusTable)
        return result
    }

    fileprivate static func toposortStart(_ objects: Set<LCObject>, _ result: inout [LCObject], _ visitStatusTable: inout [UInt: Int]) {
        objects.forEach { try! toposortVisit($0, objects, &result, &visitStatusTable) }
    }

    fileprivate static func toposortVisit(_ value: LCValue, _ objects: Set<LCObject>, _ result: inout [LCObject], _ visitStatusTable: inout [UInt: Int]) throws {
        guard let object = value as? LCObject else {
            (value as! LCValueExtension).forEachChild { child in
                try! toposortVisit(child, objects, &result, &visitStatusTable)
            }
            return
        }

        let key = UInt(bitPattern: ObjectIdentifier(object))

        switch visitStatusTable[key] ?? 0 {
        case 0: /* Unvisited */
            visitStatusTable[key] = 1
            object.forEachChild { child in
                try! toposortVisit(child, objects, &result, &visitStatusTable)
            }
            visitStatusTable[key] = 2

            if objects.contains(object) {
                result.append(object)
            }
        case 1: /* Visiting */
            throw LCError(code: .inconsistency, reason: "Circular reference.", userInfo: nil)
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
    static func family(_ object: LCObject) -> Set<LCObject> {
        var result: Set<LCObject> = []
        familyVisit(object, result: &result)
        return result
    }

    fileprivate static func familyVisit(_ value: LCValue, result: inout Set<LCObject>) {
        (value as! LCValueExtension).forEachChild { child in
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
    static func validateCircularReference(_ object: LCObject) {
        var visitStatusTable: [UInt: Int] = [:]
        try! validateCircularReference(object, visitStatusTable: &visitStatusTable)
    }

    /**
     Validate circular reference in object graph iteratively.

     - parameter object: The object to validate.
     - parameter visitStatusTable: The object visit status table.
     */
    fileprivate static func validateCircularReference(_ object: LCValue, visitStatusTable: inout [UInt: Int]) throws {
        let key = UInt(bitPattern: ObjectIdentifier(object))

        switch visitStatusTable[key] ?? 0 {
        case 0: /* Unvisited */
            visitStatusTable[key] = 1
            (object as! LCValueExtension).forEachChild { (child) in
                try! validateCircularReference(child, visitStatusTable: &visitStatusTable)
            }
            visitStatusTable[key] = 2
        case 1: /* Visiting */
            throw LCError(code: .inconsistency, reason: "Circular reference.", userInfo: nil)
        default: /* Visited */
            break
        }
    }

    /**
     Check whether value is a boolean.

     - parameter jsonValue: The value to check.

     - returns: true if value is a boolean, false otherwise.
     */
    fileprivate static func isBoolean(_ jsonValue: AnyObject) -> Bool {
        switch String(describing: type(of: jsonValue)) {
        case "__NSCFBoolean", "Bool": return true
        default: return false
        }
    }

    /**
     Get object class by name.

     - parameter className: The name of object class.

     - returns: The class.
     */
    static func objectClass(_ className: String) -> LCObject.Type? {
        return ObjectProfiler.objectClassTable[className]
    }

    /**
     Create LCObject object for class name.

     - parameter className: The class name of LCObject type.

     - returns: An LCObject object for class name.
     */
    static func object(className: String) -> LCObject {
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
    static func object(dictionary: [String: AnyObject], className: String) -> LCObject {
        let result = object(className: className)
        let keyValues = dictionary.mapValue { try! object(jsonValue: $0) }

        keyValues.forEach { (key, value) in
            result.update(key, value)
        }

        return result
    }

    /**
     Convert a dictionary to an object of specified data type.

     - parameter dictionary: The source dictionary to be converted.
     - parameter dataType:   The data type.

     - returns: An LCValue object, or nil if object can not be decoded.
     */
    static func object(dictionary: [String: AnyObject], dataType: RESTClient.DataType) -> LCValue? {
        switch dataType {
        case .object, .pointer:
            let className = dictionary["className"] as! String

            return object(dictionary: dictionary, className: className)
        case .relation:
            return LCRelation(dictionary: dictionary)
        case .geoPoint:
            return LCGeoPoint(dictionary: dictionary)
        case .bytes:
            return LCData(dictionary: dictionary)
        case .date:
            return LCDate(dictionary: dictionary)
        }
    }

    /**
     Convert a dictionary to an LCValue object.

     - parameter dictionary: The source dictionary to be converted.

     - returns: An LCValue object.
     */
    fileprivate static func object(dictionary: [String: AnyObject]) -> LCValue {
        var result: LCValue!

        if let type = dictionary["__type"] as? String {
            if let dataType = RESTClient.DataType(rawValue: type) {
                result = object(dictionary: dictionary, dataType: dataType)
            }
        }

        if result == nil {
            result = LCDictionary(dictionary.mapValue { try! object(jsonValue: $0) })
        }

        return result
    }

    /**
     Convert JSON value to LCValue object.

     - parameter jsonValue: The JSON value.

     - returns: An LCValue object of the corresponding JSON value.
     */
    static func object(jsonValue: AnyObject) throws -> LCValue {
        switch jsonValue {
        /* Note: a bool is also a number, we must match it first. */
        case let bool where isBoolean(bool):
            return LCBool(bool as! Bool)
        case let number as NSNumber:
            return LCNumber(number.doubleValue)
        case let string as String:
            return LCString(string)
        case let array as [AnyObject]:
            return LCArray(array.map { try! object(jsonValue: $0) })
        case let dictionary as [String: AnyObject]:
            return object(dictionary: dictionary)
        case let data as Data:
            return LCData(data)
        case let date as Date:
            return LCDate(date)
        case is NSNull:
            return LCNull()
        case let object as LCValue:
            return object
        default:
            break
        }

        throw LCError(code: .invalidType, reason: "Unrecognized object.")
    }

    /**
     Convert an AnyObject object to JSON value.

     - parameter object: The object to be converted.

     - returns: The JSON value of object.
     */
    static func lconValue(_ object: AnyObject) -> AnyObject {
        switch object {
        case let array as [AnyObject]:
            return array.map { lconValue($0) } as AnyObject
        case let dictionary as [String: AnyObject]:
            return dictionary.mapValue { lconValue($0) } as AnyObject
        case let object as LCValue:
            return (object as! LCValueExtension).lconValue!
        case let query as LCQuery:
            return query.lconValue as AnyObject
        default:
            return object
        }
    }

    /**
     Find an error in JSON value.

     - parameter jsonValue: The JSON value from which to find the error.

     - returns: An error object, or nil if error not found.
     */
    static func error(jsonValue: AnyObject?) -> LCError? {
        var result: LCError?

        switch jsonValue {
        case let array as [AnyObject]:
            for element in array {
                if let error = self.error(jsonValue: element) {
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
                    if let error = self.error(jsonValue: value) {
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
    static func updateObject(_ object: LCObject, _ dictionary: [String: AnyObject]) {
        dictionary.forEach { (key, value) in
            object.update(key, try! self.object(jsonValue: value))
        }
    }

    /**
     Get property name from a setter selector.

     - parameter selector: The setter selector.

     - returns: A property name correspond to the setter selector.
     */
    static func propertyName(_ setter: Selector) -> String {
        var propertyName = NSStringFromSelector(setter)

        propertyName = propertyName.substring(from: propertyName.characters.index(propertyName.startIndex, offsetBy: 3))
        propertyName = propertyName.substring(to: propertyName.characters.index(propertyName.endIndex, offsetBy: -1))

        return propertyName
    }

    /**
     Get property value for given name from an object.

     - parameter object:       The object that owns the property.
     - parameter propertyName: The property name.

     - returns: The property value, or nil if such a property not found.
     */
    static func propertyValue(_ object: LCObject, _ propertyName: String) -> LCValue? {
        guard hasLCValue(object, propertyName) else { return nil }

        return Runtime.instanceVariableValue(object, propertyName) as? LCValue
    }

    static func getJSONString(_ object: LCValue) -> String {
        return getJSONString(object, depth: 0)
    }

    static func getJSONString(_ object: LCValue, depth: Int, indent: Int = 4) -> String {
        switch object {
        case is LCNull:
            return "null"
        case let number as LCNumber:
            return "\(number.value)"
        case let bool as LCBool:
            return "\(bool.value)"
        case let string as LCString:
            let value = string.value

            if depth > 0 {
                return "\"\(value.doubleQuoteEscapedString)\""
            } else {
                return value
            }
        case let array as LCArray:
            let value = array.value

            if value.isEmpty {
                return "[]"
            } else {
                let lastIndent = " " * (indent * depth)
                let bodyIndent = " " * (indent * (depth + 1))
                let body = value
                    .map { element in getJSONString(element, depth: depth + 1) }
                    .joined(separator: ",\n" + bodyIndent)

                return "[\n\(bodyIndent)\(body)\n\(lastIndent)]"
            }
        case let dictionary as LCDictionary:
            let value = dictionary.value

            if value.isEmpty {
                return "{}"
            } else {
                let lastIndent = " " * (indent * depth)
                let bodyIndent = " " * (indent * (depth + 1))
                let body = value
                    .map    { (key, value)  in (key, getJSONString(value, depth: depth + 1)) }
                    .sorted { (left, right) in left.0 < right.0 }
                    .map    { (key, value)  in "\"\(key.doubleQuoteEscapedString)\" : \(value)" }
                    .joined(separator: ",\n" + bodyIndent)

                return "{\n\(bodyIndent)\(body)\n\(lastIndent)}"
            }
        case let object as LCObject:
            let dictionary = object.dictionary.copy() as! LCDictionary

            dictionary["__type"]    = LCString("Object")
            dictionary["className"] = LCString(object.actualClassName)

            return getJSONString(dictionary, depth: depth)
        case _ where object is LCRelation ||
                     object is LCGeoPoint ||
                     object is LCData     ||
                     object is LCDate     ||
                     object is LCACL:

            let jsonValue  = object.jsonValue
            let dictionary = LCDictionary(unsafeObject: jsonValue as! [String : AnyObject])

            return getJSONString(dictionary, depth: depth)
        default:
            return object.description
        }
    }

    /**
     Getter implementation of LeanCloud data type property.
     */
    static let propertyGetter: @convention(c) (LCObject, Selector) -> AnyObject? = {
        (object: LCObject, cmd: Selector) -> AnyObject? in
        let key = NSStringFromSelector(cmd)
        return object.get(key)
    }

    /**
     Setter implementation of LeanCloud data type property.
     */
    static let propertySetter: @convention(c) (LCObject, Selector, AnyObject?) -> Void = {
        (object: LCObject, cmd: Selector, value: AnyObject?) -> Void in
        let key = ObjectProfiler.propertyName(cmd)
        let value = value as? LCValue

        if ObjectProfiler.getLCValue(object, key) == nil {
            object.set(key.firstLowercaseString, value: value)
        } else {
            object.set(key, value: value)
        }
    }
}
