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
    public private(set) var objectId: String?

    var hasObjectId: Bool {
        return objectId != nil
    }

    /// The temp in-memory object identifier.
    var internalId = Utility.uuid()

    /// Operation hub.
    /// Used to manage object operations.
    var operationHub: OperationHub!

    /// Action dispatch queue.
    var actionDispatchQueue = dispatch_queue_create("LeanCloud.Object.Action", DISPATCH_QUEUE_SERIAL)

    override var JSONValue: AnyObject? {
        if let objectId = objectId {
            return [
                "__type": "Pointer",
                "className": self.dynamicType.className(),
                "objectId": objectId
            ]
        }

        return nil
    }

    public required init() {
        super.init()
        operationHub = OperationHub(self)
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
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
    func addOperation(name: Operation.Name, _ key: String, _ value: LCType?) {
        enqueueAction {
            self.operationHub.append(name, key, value)
        }
    }

    /**
     Update a property to given value.

     - parameter key:   The name of property which you want to update.
     - parameter value: The new value.
     */
    public func update(key: String, _ value: LCType) {
        addOperation(.Set, key, value)
    }

    /**
     Delete a property.

     - parameter key: The name of property which you want to delete.
     */
    public func delete(key key: String) {
        addOperation(.Delete, key, nil)
    }

    /**
     Increase a property by amount.

     - parameter key:    The name of property on which you want to increase.
     - parameter amount: The amount to increase.
     */
    public func increase(key: String, _ amount: LCNumber) {
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
     Save object and its all descendant objects synchronously.

     - returns: The response of saving request.
     */
    public func save() -> Response {
        var response: Response!

        enqueueAction { [unowned self] in
            response = ObjectUpdater.save(self)
        }

        return response
    }
}