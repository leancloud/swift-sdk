//
//  LCArray.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud array type.

 It is a wrapper of Array type, used to store an array value.
 */
public class LCArray: LCType {
    public private(set) var value = [AnyObject]()

    public required init() {
        super.init()
    }

    public convenience init(_ value: [AnyObject]) {
        self.init()
        self.value = value
    }

    public func append(object: AnyObject) {
        value.append(object)
        updateParent { (object, key) -> Void in
            object.addOperation(.Add, key, LCArray([object]))
        }
    }

    // MARK: Arithmetic

    override func add(another: LCType?) -> LCType? {
        if let some = another as? LCArray {
            return LCArray(self.value.appendContentsOf(some.value))
        } else {
            /* TODO: throw an exception that one type cannot be appended to another type. */
            return nil
        }
    }
}