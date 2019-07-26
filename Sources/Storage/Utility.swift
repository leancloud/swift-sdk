//
//  Utility.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/25/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import IOKit
#endif

class Utility {
    static func uuid() -> String {
        let uuid = NSUUID().uuidString
        return (uuid as NSString).replacingOccurrences(of: "-", with: "").lowercased()
    }

    static func jsonString(_ object: Any) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object, options: JSONSerialization.WritingOptions(rawValue: 0))
        return String(data: data, encoding: String.Encoding.utf8)!
    }

    static let mainQueue = DispatchQueue.main

    /**
     Asynchronize a task into specified dispatch queue.

     - parameter task:       The task to be asynchronized.
     - parameter queue:      The dispatch queue into which the task will be enqueued.
     - parameter completion: The completion closure to be called on main thread after task executed.
     */
    static func asynchronize<Result>(_ task: @escaping () -> Result, _ queue: DispatchQueue, _ completion: @escaping (Result) -> Void) {
        queue.async {
            let result = task()
            mainQueue.async {
                completion(result)
            }
        }
    }
    
    static var UDID: String {
        var udid: String?
        #if os(iOS) || os(tvOS)
        if let identifierForVendor: String = UIDevice.current.identifierForVendor?.uuidString {
            udid = identifierForVendor
        }
        #elseif os(macOS)
        let platformExpert: io_service_t = IOServiceGetMatchingService(
            kIOMasterPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        if let serialNumber: String = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformSerialNumberKey as CFString,
            kCFAllocatorDefault,
            0).takeRetainedValue() as? String
        {
            udid = serialNumber
        }
        IOObjectRelease(platformExpert)
        #endif
        return (udid ?? UUID().uuidString).lowercased()
    }
}

protocol InternalSynchronizing {
    
    var mutex: NSLock { get }
    
}

extension InternalSynchronizing {
    
    func sync(_ autoClosure: @autoclosure () -> Void) {
        sync { autoClosure() }
    }
    
    func sync(_ closure: () -> Void) {
        self.mutex.lock()
        defer {
            self.mutex.unlock()
        }
        closure()
    }
    
}
