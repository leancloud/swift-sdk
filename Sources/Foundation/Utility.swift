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
    static var compactUUID: String {
        return UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }
    
    static var UDID: String {
        var udid: String?
        #if os(iOS) || os(tvOS)
        if let identifierForVendor = UIDevice.current
            .identifierForVendor?.uuidString {
            udid = identifierForVendor
        }
        #elseif os(macOS)
        let platformExpert = IOServiceGetMatchingService(
            kIOMasterPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        if let serialNumber = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformSerialNumberKey as CFString,
            kCFAllocatorDefault,
            0).takeRetainedValue() as? String {
            udid = serialNumber
        }
        IOObjectRelease(platformExpert)
        #endif
        if let udid = udid {
            return udid.lowercased()
        } else {
            return Utility.compactUUID
        }
    }
    
    static func jsonString(
        _ object: Any?,
        encoding: String.Encoding = .utf8) throws -> String?
    {
        guard let object = object else {
            return nil
        }
        let data = try JSONSerialization.data(withJSONObject: object)
        return String(data: data, encoding: encoding)
    }
}

protocol InternalSynchronizing {
    
    var mutex: NSLock { get }
}

extension InternalSynchronizing {
    
    func sync<T>(_ closure: @autoclosure () throws -> T) rethrows -> T {
        return try self.sync(closure: closure)
    }
    
    func sync<T>(closure: () throws -> T) rethrows -> T {
        self.mutex.lock()
        defer {
            self.mutex.unlock()
        }
        return try closure()
    }
}
