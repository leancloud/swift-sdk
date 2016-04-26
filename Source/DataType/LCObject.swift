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
public class LCObject: LCType {
    /// Object identifier.
    public private(set) dynamic var objectId: LCString?

    public private(set) dynamic var createdAt: LCDate?
    public private(set) dynamic var updatedAt: LCDate?

    var hasObjectId: Bool {
        return objectId != nil
    }

    var endpoint: String? {
        guard let objectId = objectId else {
            return nil
        }

        return "\(self.dynamicType.classEndpoint())/\(objectId.value)"
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

    /// Action dispatch queue.
    var actionDispatchQueue = dispatch_queue_create("LeanCloud.Object.Action", DISPATCH_QUEUE_SERIAL)

    override var JSONValue: AnyObject? {
        if let objectId = objectId {
            return [
                "__type": "Pointer",
                "className": self.dynamicType.className(),
                "objectId": objectId.value
            ]
        }

        return nil
    }

    /// Dictionary representation of object.
    var dictionary: LCDictionary {
        var dictionary: [String: LCType] = [:]

        ObjectProfiler.iterateProperties(self) { (key, value) in
            guard let value = value else { return }
            dictionary[key] = value
        }

        return LCDictionary(dictionary)
    }

    public override required init() {
        super.init()
        operationHub = OperationHub(self)
    }

    public convenience init(objectId: String) {
        self.init()
        self.objectId = LCString(objectId)
    }

    convenience init(dictionary: LCDictionary) {
        self.init()
        ObjectProfiler.updateObject(self, dictionary.value)
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

    override func forEachChild(body: (child: LCType) -> Void) {
        ObjectProfiler.iterateProperties(self) { (_, child) in
            if let child = child {
                body(child: child)
            }
        }
    }

    /**
     Set the name of current type.

     The default implementation returns the class name of current type.

     - returns: Name of current type.
     */
    public class func className() -> String {
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
     Set the REST endpoint of current type.

     The default implementation returns the "classes/{className}".

     - returns: REST endpoint of current type.
     */
    public class func classEndpoint() -> String {
        return "classes/\(className())"
    }

    /**
     Enqueue an action for serial execution.

     - parameter action: The action closure to enqueue.
     */
    func enqueueAction(action: () -> Void) {
        dispatch_sync(actionDispatchQueue, action)
    }

    /**
     Add an operation.

     - parameter name:  Operation name.
     - parameter key:   Key on which to perform.
     - parameter value: Value to be assigned.
     */
    func addOperation(name: Operation.Name, _ key: String, _ value: LCType? = nil) {
        enqueueAction {
            self.operationHub.append(name, key, value)
        }
    }

    /**
     Update a property to given value.

     - parameter key:   The name of property which you want to update.
     - parameter value: The new value.
     */
    public func set(key: String, value: LCType?) {
        if let value = value {
            ObjectProfiler.validateType(self, propertyName: key, type: value.dynamicType)
            addOperation(.Set, key, value)
        } else {
            addOperation(.Delete, key)
        }
    }

    /**
     Delete a property.

     - parameter key: The name of property which you want to delete.
     */
    public func unset(key: String) {
        addOperation(.Delete, key, nil)
    }

    /**
     Increase a property by amount.

     - parameter key:    The name of property on which you want to increase.
     - parameter amount: The amount to increase.
     */
    public func increase(key: String, amount: LCNumber) {
        addOperation(.Increment, key, amount)
    }

    /**
     Append an element to an array property.

     - parameter key:     The name of property into which you want to append the element.
     - parameter element: The element to append.
     */
    public func append(key: String, element: LCType) {
        addOperation(.Add, key, LCArray([element]))
    }

    /**
     Append an element to an array property with unique option.

     - parameter key:     The name of property into which you want to append the element.
     - parameter element: The element to append.
     - parameter unique:  Whether append element by unique or not.
                          If true, element will not be appended if it had already existed in array;
                          otherwise, element will always be appended.
     */
    public func append(key: String, element: LCType, unique: Bool) {
        addOperation(unique ? .AddUnique : .Add, key, LCArray([element]))
    }

    /**
     Remove an element from an array property.

     - parameter key:     The name of property from which you want to remove the element.
     - parameter element: The element to remove.
     */
    public func remove(key: String, element: LCType) {
        addOperation(.Remove, key, LCArray([element]))
    }

    /**
     Insert an object to a relation property.

     - parameter key:    The name of property into which you want to insert the object.
     - parameter object: The object to insert.
     */
    public func insertRelation(key: String, object: LCObject) {
        addOperation(.AddRelation, key, LCArray([object]))
    }

    /**
     Remove an object from a relation property.

     - parameter key:    The name of property from which you want to remove the object.
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
     Save object and its all descendant objects synchronously.

     - returns: The result of saving request.
     */
    public func save() -> BooleanResult {
        var result: BooleanResult!

        enqueueAction { [unowned self] in
            result = BooleanResult(response: ObjectUpdater.save(self))
        }

        return result
    }

    /**
     Delete current object synchronously.

     - returns: The result of deleting request.
     */
    public func delete() -> BooleanResult {
        var result: BooleanResult!

        enqueueAction { [unowned self] in
            result = BooleanResult(response: ObjectUpdater.delete(self))
        }

        return result
    }

    /**
     Delete a batch of objects in one request synchronously.

     - parameter objects: An array of objects to be deleted.

     - returns: The result of deletion request.
     */
    public static func deleteObjects(objects: [LCObject]) -> BooleanResult {
        var result: BooleanResult!

        guard !objects.isEmpty else { return result }

        let requests = Set<LCObject>(objects).map { object in
            BatchRequest(object: object, method: .DELETE).JSONValue()
        }

        let response = RESTClient.request(.POST, "batch", parameters: ["requests": requests])

        result = BooleanResult(response: response)

        return result
    }

    /**
     Fetch object from server synchronously.

     - returns: The result of fetching request.
     */
    public func fetch() -> BooleanResult {
        var result: BooleanResult!

        enqueueAction { [unowned self] in
            result = BooleanResult(response: ObjectUpdater.fetch(self))
        }

        return result
    }
}