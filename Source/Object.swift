//
//  Object.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

public class Object: NSObject {
    var latestData = NSMutableDictionary()
    var stableData = NSMutableDictionary()

    /**
     Register all subclasses.
     */
    static func registerSubclasses() {
        let subclasses = Runtime.subclasses(Object.self)

        for subclass in subclasses {
            ObjectProfiler.synthesizeProperties(subclass)
        }
    }

    func objectForKey(key:String) -> AnyObject? {
        return latestData[key]
    }

    func setObject(object: AnyObject?, forKey key:String) {
        latestData[key] = object
    }
}