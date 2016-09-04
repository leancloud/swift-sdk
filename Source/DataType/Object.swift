//
//  Object.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud object type.

 It's a compound type used to unite other types.
 It can be extended into subclass while adding some other properties to form a new type.
 Each object is correspond to a record in data storage.
 */
public class LCObject: NSObject, LCValue, LCValueExtension, SequenceType {
    /// Access control lists.
    public dynamic var ACL: LCACL?

    /// Object identifier.
    public private(set) dynamic var objectId: LCString?

    public private(set) dynamic var createdAt: LCDate?
    public private(set) dynamic var updatedAt: LCDate?

    /**
     The table of all properties.
     */
    var propertyTable: LCDictionary = [:]

    var hasObjectId: Bool {
        return objectId != nil
    }

    var actualClassName: String {
        let className = self["className"] as? LCString
        return (className?.value) ?? self.dynamicType.objectClassName()
    }

    /// The temp in-memory object identifier.
    var internalId = Utility.uuid()

    /// Operation hub.
    /// Used to manage update operations.
    var operationHub: OperationHub!

    /// Whether object has data to upload or not.
    var hasDataToUpload: Bool {
        return hasObjectId ? (!operationHub.isEmpty) : true
    }

    public override required init() {
        super.init()
        operationHub = OperationHub(self)
    }

    public convenience init(objectId: LCStringConvertible) {
        self.init()
        propertyTable["objectId"] = objectId.lcString
    }

    public convenience init(className: LCStringConvertible) {
        self.init()
        propertyTable["className"] = className.lcString
    }

    public convenience init(className: LCStringConvertible, objectId: LCStringConvertible) {
        self.init()
        propertyTable["className"] = className.lcString
        propertyTable["objectId"]  = objectId.lcString
    }

    convenience init(dictionary: LCDictionaryConvertible) {
        self.init()
        self.propertyTable = dictionary.lcDictionary
    }

    public required init?(coder aDecoder: NSCoder) {
        propertyTable = (aDecoder.decodeObjectForKey("propertyTable") as? LCDictionary) ?? [:]
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(propertyTable, forKey: "propertyTable")
    }

    public func copyWithZone(zone: NSZone) -> AnyObject {
        return self
    }

    public override func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if another?.objectId != nil && objectId != nil {
            return another?.objectId == objectId
        } else {
            return false
        }
    }

    public override func valueForKey(key: String) -> AnyObject? {
        guard let value = get(key) else {
            return super.valueForKey(key)
        }

        return value
    }

    public func generate() -> DictionaryGenerator<String, LCValue> {
        return propertyTable.generate()
    }

    public var JSONValue: AnyObject {
        var result = propertyTable.JSONValue as! [String: AnyObject]

        result["__type"]    = "Object"
        result["className"] = actualClassName

        return result
    }

    public var JSONString: String {
        return ObjectProfiler.getJSONString(self)
    }

    var LCONValue: AnyObject? {
        guard let objectId = objectId else {
            return nil
        }

        return [
            "__type"    : "Pointer",
            "className" : actualClassName,
            "objectId"  : objectId.value
        ]
    }

    static func instance() -> LCValue {
        return self.init()
    }

    func forEachChild(body: (child: LCValue) -> Void) {
        propertyTable.forEachChild(body)
    }

    func add(other: LCValue) throws -> LCValue {
        throw LCError(code: .InvalidType, reason: "Object cannot be added.")
    }

    func concatenate(other: LCValue, unique: Bool) throws -> LCValue {
        throw LCError(code: .InvalidType, reason: "Object cannot be concatenated.")
    }

    func differ(other: LCValue) throws -> LCValue {
        throw LCError(code: .InvalidType, reason: "Object cannot be differed.")
    }

    /// The dispatch queue for network request task.
    static let backgroundQueue = dispatch_queue_create("LeanCloud.Object", DISPATCH_QUEUE_CONCURRENT)

    /**
     Set class name of current type.

     The default implementation returns the class name without root module.

     - returns: The class name of current type.
     */
    public class func objectClassName() -> String {
        let className = String(UTF8String: class_getName(self))!

        /* Strip root namespace to cope with application package name's change. */
        if let index = className.characters.indexOf(".") {
            return className.substringFromIndex(index.successor())
        } else {
            return className
        }
    }

    /**
     Register current object class manually.
     */
    public static func register() {
        ObjectProfiler.registerClass(self)
    }

    /**
     Load a property for key.

     If the property value for key is already existed and type is mismatched, it will throw an exception.

     - parameter key: The key to load.

     - returns: The property value.
     */
    func getProperty<Value: LCValue>(key: String) throws -> Value? {
        let value = propertyTable[key]

        if let value = value {
            guard value is Value else {
                let reason = String(format: "No such a property with name \"%@\" and type \"%s\".", key, class_getName(Value.self))
                throw LCError(code: .InvalidType, reason: reason, userInfo: nil)
            }
        }

        return value as? Value
    }

    /**
     Load a property for key.

     If the property value for key is not existed, it will initialize the property.
     If the property value for key is already existed and type is mismatched, it will throw an exception.

     - parameter key: The key to load.

     - returns: The property value.
     */
    func loadProperty<Value: LCValue>(key: String) throws -> Value {
        if let value: Value = try getProperty(key) {
            return value
        }

        let value = (Value.self as AnyClass).instance() as! Value
        propertyTable[key] = value

        return value
    }

    /**
     Update property with operation.

     - parameter operation: The operation used to update property.
     */
    func updateProperty(operation: Operation) {
        let key   = operation.key
        let name  = operation.name
        let value = operation.value

        self.willChangeValueForKey(key)

        switch name {
        case .Set:
            propertyTable[key] = value
        case .Delete:
            propertyTable[key] = nil
        case .Increment:
            let amount   = (value as! LCNumber).value
            let property = try! loadProperty(key) as LCNumber

            property.addInPlace(amount)
        case .Add:
            let elements = (value as! LCArray).value
            let property = try! loadProperty(key) as LCArray

            property.concatenateInPlace(elements, unique: false)
        case .AddUnique:
            let elements = (value as! LCArray).value
            let property = try! loadProperty(key) as LCArray

            property.concatenateInPlace(elements, unique: true)
        case .Remove:
            let elements = (value as! LCArray).value
            let property = try! getProperty(key) as LCArray?

            property?.differInPlace(elements)
        case .AddRelation:
            let elements = (value as! LCArray).value as! [LCRelation.Element]
            let relation = try! loadProperty(key) as LCRelation

            relation.appendElements(elements)
        case .RemoveRelation:
            let relation: LCRelation? = try! getProperty(key)
            let elements = (value as! LCArray).value as! [LCRelation.Element]

            relation?.removeElements(elements)
        }

        self.didChangeValueForKey(key)
    }

    /**
     Add an operation.

     - parameter name:  The operation name.
     - parameter key:   The operation key.
     - parameter value: The operation value.
     */
    func addOperation(name: Operation.Name, _ key: String, _ value: LCValue? = nil) {
        let operation = Operation(name: name, key: key, value: value)

        updateProperty(operation)
        operationHub.reduce(operation)
    }

    /**
     Transform value for key.

     - parameter key:   The key for which the value should be transformed.
     - parameter value: The value to be transformed.

     - returns: The transformed value for key.
     */
    func transformValue(key: String, _ value: LCValue?) -> LCValue? {
        guard let value = value else {
            return nil
        }

        switch key {
        case "ACL":
            return LCACL(JSONValue: value.JSONValue)
        case "createdAt", "updatedAt":
            return LCDate(JSONValue: value.JSONValue)
        default:
            return value
        }
    }

    /**
     Update a property.

     - parameter key:   The property key to be updated.
     - parameter value: The property value.
     */
    func update(key: String, _ value: LCValue?) {
        self.willChangeValueForKey(key)
        propertyTable[key] = transformValue(key, value)
        self.didChangeValueForKey(key)
    }

    /**
     Get and set value via subscript syntax.
     */
    public subscript(key: String) -> LCValue? {
        get { return get(key) }
        set { set(key, value: newValue) }
    }

    /**
     Get value for key.

     - parameter key: The key for which to get the value.

     - returns: The value for key.
     */
    public func get(key: String) -> LCValue? {
        return propertyTable[key]
    }

    /**
     Set value for key.

     - parameter key:   The key for which to set the value.
     - parameter value: The new value.
     */
    func set(key: String, value: LCValue?) {
        if let value = value {
            addOperation(.Set, key, value)
        } else {
            addOperation(.Delete, key)
        }
    }

    /**
     Set value for key.

     - parameter key:   The key for which to set the value.
     - parameter value: The new value.
     */
    public func set(key: String, value: LCValueConvertible?) {
        set(key, value: value?.lcValue)
    }

    /**
     Set object for key.

     - parameter key:    The key for which to set the object.
     - parameter object: The new object.
     */
    @available(*, deprecated, message="Use 'set(_:value:)' method instead.")
    public func set(key: String, object: AnyObject?) {
        if let object = object {
            set(key, value: try! ObjectProfiler.object(JSONValue: object))
        } else {
            unset(key)
        }
    }

    /**
     Unset value for key.

     - parameter key: The key for which to unset.
     */
    public func unset(key: String) {
        addOperation(.Delete, key, nil)
    }

    /**
     Increase a number by amount.

     - parameter key:    The key of number which you want to increase.
     - parameter amount: The amount to increase.
     */
    public func increase(key: String, by: LCNumberConvertible) {
        addOperation(.Increment, key, by.lcNumber)
    }

    /**
     Append an element into an array.

     - parameter key:     The key of array into which you want to append the element.
     - parameter element: The element to append.
     */
    public func append(key: String, element: LCValueConvertible) {
        addOperation(.Add, key, LCArray([element.lcValue]))
    }

    /**
     Append one or more elements into an array.

     - parameter key:      The key of array into which you want to append the elements.
     - parameter elements: The array of elements to append.
     */
    public func append(key: String, elements: LCArrayConvertible) {
        addOperation(.Add, key, elements.lcArray)
    }

    /**
     Append an element into an array with unique option.

     - parameter key:     The key of array into which you want to append the element.
     - parameter element: The element to append.
     - parameter unique:  Whether append element by unique or not.
                          If true, element will not be appended if it had already existed in array;
                          otherwise, element will always be appended.
     */
    public func append(key: String, element: LCValueConvertible, unique: Bool) {
        addOperation(unique ? .AddUnique : .Add, key, LCArray([element.lcValue]))
    }

    /**
     Append one or more elements into an array with unique option.

     - seealso: `append(key: String, element: LCValue, unique: Bool)`

     - parameter key:      The key of array into which you want to append the element.
     - parameter elements: The array of elements to append.
     - parameter unique:   Whether append element by unique or not.
     */
    public func append(key: String, elements: LCArrayConvertible, unique: Bool) {
        addOperation(unique ? .AddUnique : .Add, key, elements.lcArray)
    }

    /**
     Remove an element from an array.

     - parameter key:     The key of array from which you want to remove the element.
     - parameter element: The element to remove.
     */
    public func remove(key: String, element: LCValueConvertible) {
        addOperation(.Remove, key, LCArray([element.lcValue]))
    }

    /**
     Remove one or more elements from an array.

     - parameter key:      The key of array from which you want to remove the element.
     - parameter elements: The array of elements to remove.
     */
    public func remove(key: String, elements: LCArrayConvertible) {
        addOperation(.Remove, key, elements.lcArray)
    }

    /**
     Get relation object for key.

     - parameter key: The key where relationship based on.

     - returns: The relation for key.
     */
    public func relationForKey(key: String) -> LCRelation {
        return LCRelation(key: key, parent: self)
    }

    /**
     Insert an object into a relation.

     - parameter key:    The key of relation into which you want to insert the object.
     - parameter object: The object to insert.
     */
    public func insertRelation(key: String, object: LCObject) {
        addOperation(.AddRelation, key, LCArray([object]))
    }

    /**
     Remove an object from a relation.

     - parameter key:    The key of relation from which you want to remove the object.
     - parameter object: The object to remove.
     */
    public func removeRelation(key: String, object: LCObject) {
        addOperation(.RemoveRelation, key, LCArray([object]))
    }

    /**
     Validate object before saving.

     Subclass can override this method to add custom validation logic.
     */
    func validateBeforeSaving() {
        /* Validate circular reference. */
        ObjectProfiler.validateCircularReference(self)
    }

    /**
     Reset operations, make object unmodified.
     */
    func resetOperation() {
        self.operationHub.reset()
    }

    /**
     Asynchronize task into background queue.

     - parameter task:       The task to be performed.
     - parameter completion: The completion closure to be called on main thread after task finished.
     */
    func asynchronize<Result>(task: () -> Result, completion: (Result) -> Void) {
        LCObject.asynchronize(task, completion: completion)
    }

    /**
     Asynchronize task into background queue.

     - parameter task:       The task to be performed.
     - parameter completion: The completion closure to be called on main thread after task finished.
     */
    static func asynchronize<Result>(task: () -> Result, completion: (Result) -> Void) {
        Utility.asynchronize(task, backgroundQueue, completion)
    }

    /**
     Save object and its all descendant objects synchronously.

     - returns: The result of saving request.
     */
    public func save() -> LCBooleanResult {
        return LCBooleanResult(response: ObjectUpdater.save(self))
    }

    /**
     Save object and its all descendant objects asynchronously.

     - parameter completion: The completion callback closure.
     */
    public func save(completion: (LCBooleanResult) -> Void) {
        asynchronize({ self.save() }) { result in
            completion(result)
        }
    }

    /**
     Delete a batch of objects in one request synchronously.

     - parameter objects: An array of objects to be deleted.

     - returns: The result of deletion request.
     */
    public static func delete(objects: [LCObject]) -> LCBooleanResult {
        return LCBooleanResult(response: ObjectUpdater.delete(objects))
    }

    /**
     Delete a batch of objects in one request asynchronously.

     - parameter completion: The completion callback closure.
     */
    public static func delete(objects: [LCObject], completion: (LCBooleanResult) -> Void) {
        asynchronize({ delete(objects) }) { result in
            completion(result)
        }
    }

    /**
     Delete current object synchronously.

     - returns: The result of deletion request.
     */
    public func delete() -> LCBooleanResult {
        return LCBooleanResult(response: ObjectUpdater.delete(self))
    }

    /**
     Delete current object asynchronously.

     - parameter completion: The completion callback closure.
     */
    public func delete(completion: (LCBooleanResult) -> Void) {
        asynchronize({ self.delete() }) { result in
            completion(result)
        }
    }

    /**
     Fetch a batch of objects in one request synchronously.

     - parameter objects: An array of objects to be fetched.

     - returns: The result of fetching request.
     */
    public static func fetch(objects: [LCObject]) -> LCBooleanResult {
        return LCBooleanResult(response: ObjectUpdater.fetch(objects))
    }

    /**
     Fetch a batch of objects in one request asynchronously.

     - parameter completion: The completion callback closure.
     */
    public static func fetch(objects: [LCObject], completion: (LCBooleanResult) -> Void) {
        asynchronize({ fetch(objects) }) { result in
            completion(result)
        }
    }

    /**
     Fetch object from server synchronously.

     - returns: The result of fetching request.
     */
    public func fetch() -> LCBooleanResult {
        return LCBooleanResult(response: ObjectUpdater.fetch(self))
    }

    /**
     Fetch object from server asynchronously.

     - parameter completion: The completion callback closure.
     */
    public func fetch(completion: (LCBooleanResult) -> Void) {
        asynchronize({ self.fetch() }) { result in
            completion(result)
        }
    }
}