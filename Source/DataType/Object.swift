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
public class LCObject: LCType, NSCoding, SequenceType {
    /// Access control lists.
    public dynamic var ACL: LCACL?

    /// Object identifier.
    public private(set) dynamic var objectId: LCString?
    public private(set) dynamic var className: LCString?

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
        return (className?.value) ?? self.dynamicType.objectClassName()
    }

    /// The temp in-memory object identifier.
    var internalId = Utility.uuid()

    /// Operation hub.
    /// Used to manage object operations.
    var operationHub: OperationHub!

    /// Whether object has data to upload or not.
    var hasDataToUpload: Bool {
        return hasObjectId ? (!operationHub.isEmpty) : true
    }

    override var JSONValue: AnyObject? {
        guard let objectId = objectId else {
            return nil
        }

        return [
            "__type": "Pointer",
            "className": actualClassName,
            "objectId": objectId.value
        ]
    }

    public override required init() {
        super.init()
        operationHub = OperationHub(self)
    }

    public convenience init(objectId: String) {
        self.init()
        propertyTable["objectId"] = LCString(objectId)
    }

    public convenience init(className: String) {
        self.init()
        propertyTable["className"] = LCString(className)
    }

    public convenience init(className: String, objectId: String) {
        self.init()
        propertyTable["className"] = LCString(className)
        propertyTable["objectId"]  = LCString(objectId)
    }

    convenience init(dictionary: LCDictionary) {
        self.init()
        self.propertyTable = dictionary
    }

    public required init?(coder aDecoder: NSCoder) {
        propertyTable = (aDecoder.decodeObjectForKey("propertyTable") as? LCDictionary) ?? [:]
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(propertyTable, forKey: "propertyTable")
    }

    class override func instance() -> LCType? {
        return self.init()
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

    public func generate() -> DictionaryGenerator<String, LCType> {
        return propertyTable.generate()
    }

    override func forEachChild(body: (child: LCType) -> Void) {
        propertyTable.forEachChild(body)
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
    func getProperty<Value: LCType>(key: String) -> Value? {
        let value = propertyTable[key]

        if let value = value {
            guard value is Value else {
                Exception.raise(.InvalidType, reason: String(format: "No such a property with name \"%@\" and type \"%s\".", key, class_getName(Value.self)))
                return nil
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
    func loadProperty<Value: LCType>(key: String) -> Value {
        if let value = getProperty(key) as? Value {
            return value
        }

        let value = Value.instance() as! Value
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
            let number: LCNumber = loadProperty(key)

            number.increase(value as! LCNumber)
        case .Add:
            let array: LCArray = loadProperty(key)
            let elements = (value as! LCArray).value

            array.appendElements(elements)
        case .AddUnique:
            let array: LCArray = loadProperty(key)
            let elements = (value as! LCArray).value

            array.appendElements(elements, unique: true)
        case .Remove:
            let array: LCArray? = getProperty(key)
            let elements = (value as! LCArray).value

            array?.removeElements(elements)
        case .AddRelation:
            let relation: LCRelation = loadProperty(key)
            let elements = (value as! LCArray).value as! [LCRelation.Element]

            relation.appendElements(elements)
        case .RemoveRelation:
            let relation: LCRelation? = getProperty(key)
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
    func addOperation(name: Operation.Name, _ key: String, _ value: LCType? = nil) {
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
    func transformValue(key: String, _ value: LCType?) -> LCType? {
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
    func update(key: String, _ value: LCType?) {
        self.willChangeValueForKey(key)
        propertyTable[key] = transformValue(key, value)
        self.didChangeValueForKey(key)
    }

    /**
     Get and set value via subscript syntax.
     */
    public subscript(key: String) -> LCType? {
        get { return get(key) }
        set { set(key, value: newValue) }
    }

    /**
     Get value for key.

     - parameter key: The key for which to get the value.

     - returns: The value for key.
     */
    public func get<Value: LCType>(key: String) -> Value? {
        return propertyTable[key] as? Value
    }

    /**
     Set value for key.

     - parameter key:   The key for which to set the value.
     - parameter value: The new value.
     */
    public func set(key: String, value: LCType?) {
        if let value = value {
            addOperation(.Set, key, value)
        } else {
            addOperation(.Delete, key)
        }
    }

    /**
     Set object for key.

     - parameter key:    The key for which to set the object.
     - parameter object: The new object.
     */
    public func set(key: String, object: AnyObject?) {
        if let object = object {
            set(key, value: ObjectProfiler.object(JSONValue: object))
        } else {
            set(key, value: nil)
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
    public func increase(key: String, by: LCNumber) {
        addOperation(.Increment, key, by)
    }

    /**
     Append an element into an array.

     - parameter key:     The key of array into which you want to append the element.
     - parameter element: The element to append.
     */
    public func append(key: String, element: LCType) {
        addOperation(.Add, key, LCArray([element]))
    }

    /**
     Append one or more elements into an array.

     - parameter key:      The key of array into which you want to append the elements.
     - parameter elements: The array of elements to append.
     */
    public func append(key: String, elements: [LCType]) {
        addOperation(.Add, key, LCArray(elements))
    }

    /**
     Append an element into an array with unique option.

     - parameter key:     The key of array into which you want to append the element.
     - parameter element: The element to append.
     - parameter unique:  Whether append element by unique or not.
                          If true, element will not be appended if it had already existed in array;
                          otherwise, element will always be appended.
     */
    public func append(key: String, element: LCType, unique: Bool) {
        addOperation(unique ? .AddUnique : .Add, key, LCArray([element]))
    }

    /**
     Append one or more elements into an array with unique option.

     - seealso: `append(key: String, element: LCType, unique: Bool)`

     - parameter key:      The key of array into which you want to append the element.
     - parameter elements: The array of elements to append.
     - parameter unique:   Whether append element by unique or not.
     */
    public func append(key: String, elements: [LCType], unique: Bool) {
        addOperation(unique ? .AddUnique : .Add, key, LCArray(elements))
    }

    /**
     Remove an element from an array.

     - parameter key:     The key of array from which you want to remove the element.
     - parameter element: The element to remove.
     */
    public func remove(key: String, element: LCType) {
        addOperation(.Remove, key, LCArray([element]))
    }

    /**
     Remove one or more elements from an array.

     - parameter key:      The key of array from which you want to remove the element.
     - parameter elements: The array of elements to remove.
     */
    public func remove(key: String, elements: [LCType]) {
        addOperation(.Remove, key, LCArray(elements))
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