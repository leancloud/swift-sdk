//
//  Utility.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/25/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

func synchronized<T>(object: AnyObject, @noescape closure: () throws -> T) rethrows -> T {
    objc_sync_enter(object)
    defer { objc_sync_exit(object) }
    return try closure()
}

class Utility {
    static func uuid() -> String {
        return NSUUID().UUIDString.stringByReplacingOccurrencesOfString("-", withString: "").lowercaseString
    }

    static func JSONString(object: AnyObject) -> String {
        let data = try! NSJSONSerialization.dataWithJSONObject(object, options: NSJSONWritingOptions(rawValue: 0))
        return String(data: data, encoding: NSUTF8StringEncoding)!
    }
}