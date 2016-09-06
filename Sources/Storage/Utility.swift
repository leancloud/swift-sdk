//
//  Utility.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/25/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

class Utility {
    static func uuid() -> String {
        return NSUUID().UUIDString.stringByReplacingOccurrencesOfString("-", withString: "").lowercaseString
    }

    static func JSONString(object: AnyObject) -> String {
        let data = try! NSJSONSerialization.dataWithJSONObject(object, options: NSJSONWritingOptions(rawValue: 0))
        return String(data: data, encoding: NSUTF8StringEncoding)!
    }

    static let mainQueue = dispatch_get_main_queue()

    /**
     Asynchronize a task into specified dispatch queue.

     - parameter task:       The task to be asynchronized.
     - parameter queue:      The dispatch queue into which the task will be enqueued.
     - parameter completion: The completion closure to be called on main thread after task executed.
     */
    static func asynchronize<Result>(task: () -> Result, _ queue: dispatch_queue_t, _ completion: (Result) -> Void) {
        dispatch_async(queue) {
            let result = task()
            dispatch_async(mainQueue) {
                completion(result)
            }
        }
    }
}