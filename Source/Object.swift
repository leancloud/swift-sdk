//
//  Object.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

public class Object: NSObject {
    /// Stable data of object.
    /// Used to store values that have commited.
    lazy var stableData = NSMutableDictionary()

    /// Latest data of object.
    /// Used to store values that haven't committed yet.
    lazy var latestData = NSMutableDictionary()

    /// Operation hub.
    /// Used to manage object operations.
    lazy var operationHub = OperationHub()

    /**
     Get object for key.

     - parameter key: Specified key.

     - returns: Object for key.
     */
    func objectForKey(key:String) -> AnyObject? {
        return latestData[key]
    }

    /**
     Set object for key.

     - parameter object: New object.
     - parameter key:    Specified key.
     */
    func setObject(object: AnyObject?, forKey key:String) {
        latestData[key] = object
        self.addOperation(.Set, key, object)
    }

    /**
     Add an operation.

     - parameter name:  Operation name.
     - parameter key:   Key on which to perform.
     - parameter value: Value to be assigned.
     */
    func addOperation(name: Operation.Name, _ key: String, _ value: AnyObject?) {
        self.operationHub.append(name, key, value)
    }

    /**
     Save object.
     */
    public func save() {
        /* Stub method */
    }
}