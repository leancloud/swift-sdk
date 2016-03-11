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

     1. Save all leaf newborn objects in one batch request.
     2. Repeat step 1 until all descendant newborn objects saved.
     3. Then, save object and all descendant dirty objects in one batch request.

     The newborn object is object which has no object id.
     The dirty object is object which has object id and was changed.
     */
    public func save() {
        /* Stub method */
    }
}