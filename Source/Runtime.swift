//
//  Runtime.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

class Runtime {
    /**
     Check whether a class is subclass of another class.

     - parameter subclass:   inspected subclass.
     - parameter superclass: superclass which to compare with.

     - returns: true or false.
     */
    static func isSubclass(subclass: AnyClass?, superclass: AnyClass?) -> Bool {
        if subclass == nil {
            return false
        }

        if class_getSuperclass(subclass) == superclass {
            return true
        }

        return isSubclass(class_getSuperclass(subclass), superclass: superclass)
    }

    /**
     Get all subclasses of a base class.

     - parameter baseclass: A base class.

     - returns: All subclasses of given base class.
     */
    static func subclasses(baseclass: AnyClass?) -> [AnyClass] {
        var result = [AnyClass]()

        let count = objc_getClassList(nil, 0)

        guard count > 0 else {
            return result
        }

        let classes = AutoreleasingUnsafeMutablePointer<AnyClass?>(malloc(sizeof(AnyClass) * Int(count)));

        for i in 0..<Int(objc_getClassList(classes, count)) {
            guard let someclass = classes[i] else {
                continue
            }

            if isSubclass(someclass, superclass: baseclass) {
                result.append(someclass)
            }
        }

        return result
    }
}