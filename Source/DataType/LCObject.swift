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

    /// Stable data of object.
    /// Used to store values that have commited.
    lazy var stableData = NSMutableDictionary()

    /// Latest data of object.
    /// Used to store values that haven't committed yet.
    lazy var latestData = NSMutableDictionary()

    /// Operation hub.
    /// Used to manage object operations.
    lazy var operationHub: OperationHub = {
        return OperationHub(self)
    }()

    /**
     Get object for key.

     - parameter key: Specified key.

     - returns: Object for key.
     */
    func objectForKey(key: String) -> AnyObject? {
        return latestData[key]
    }

    /**
     Set object for key.

     - parameter object: New object.
     - parameter key:    Specified key.
     */
    func setObject(object: LCType?, forKey key: String) {
        latestData[key] = object
        self.addOperation(.Set, key, object)
    }

    /**
     Add an operation.

     - parameter name:  Operation name.
     - parameter key:   Key on which to perform.
     - parameter value: Value to be assigned.
     */
    func addOperation(name: Operation.Name, _ key: String, _ value: LCType?) {
        self.operationHub.append(name, key, value)
    }

    /**
     Save object and its all descendant objects synchronously.

     The detail save process is described as follows:

     1. Save deepest newborn orphan objects in one batch request.
     2. Repeat step 1 until all descendant newborn objects saved.
     3. Save root object and all descendant dirty objects in one batch request.

     Definition:

     - Newborn object: object which has no object id.
     - Orphan  object: object which exists in array or dictionary of another object.
     - Dirty   object: object which has object id and was changed (has operations).

     The reason to apply above steps is that:

     We can construct a batch request when newborn object directly attachs on another object.
     However, we cannot construct a batch request for orphan object.
     */
    public func save() {
        /* Stub method */
    }

    // MARK: Iteration

    override func forEachChild(body: (child: LCType) -> Void) {
        ObjectProfiler.iterateProperties(self) { (_, child) in
            if let child = child {
                body(child: child)
            }
        }
    }
}