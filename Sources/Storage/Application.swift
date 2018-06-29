//
//  Application.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/6/25.
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
    public enum Region {

        case cn
        case us

    }

    /**
     Application log level.

     We assume that log levels are ordered.
     */
    public enum LogLevel: Int, Comparable {

        case off
        case error
        case debug
        case all

        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }

    }

    public let ID: String

    public let key: String

    public let region: Region

    public var logLevel: LogLevel = .off

    /// Current authenticated user.
    public var currentUser: LCUser? = nil

    public static var `default`: LCApplication!

    public init(ID: String, key: String, region: Region) {
        type(of: self).initialization

        self.ID = ID
        self.key = key
        self.region = region
    }

    private static let initialization: Void = {
        ObjectProfiler.registerClasses()
    }()

    private static let currentKey = "CurrentLeanCloudApplication"

    public static var current: LCApplication? {
        let key = LCApplication.currentKey
        let threadDictionary = Thread.current.threadDictionary

        let application = threadDictionary[key] as? LCApplication

        return application
    }

    @discardableResult
    public func perform<T>(body: () throws -> T) rethrows -> T {
        let key = LCApplication.currentKey
        let threadDictionary = Thread.current.threadDictionary

        let original = threadDictionary[key]

        /* Recover to original application to support nested call. */
        defer {
            threadDictionary[key] = original
        }

        threadDictionary[key] = self

        let result = try body()

        return result
    }

}
