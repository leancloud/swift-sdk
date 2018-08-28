//
//  Application.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/8/28.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud application.

 An `LCApplication` object is an abstract of remote LeanCloud application.

 It is a context of application-specific settings and objects.
 */
public final class LCApplication {

    /**
     Application region.
     */
    enum Region {

        case cn
        case us

    }

    /**
     Application log level.

     We assume that log levels are ordered.
     */
    public enum LogLevel: Int, Comparable {

        case off
        case debug
        case all

        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }

    }

    /// Application ID.
    public private(set) var id: String!

    /// Application key.
    public private(set) var key: String!

    /// Application region.
    var region: Region {
        return id.hasSuffix("-MdYXbMMI") ? .us : .cn
    }

    /// Application log level.
    public var logLevel: LogLevel = .off

    /**
     Default application.

     You must call method `set(id:key:region:)` to initialize it when application did finish launch.
     */
    public static let `default` = LCApplication()

    private init() {
        type(of: self).initialization
    }

    private static let initialization: Void = {
        ObjectProfiler.registerClasses()
    }()

    /**
     Initialize application by application information.

     - parameter id:    Application ID.
     - parameter key:   Application key.
     */
    public func set(id: String, key: String) {
        self.id = id
        self.key = key
    }

}
