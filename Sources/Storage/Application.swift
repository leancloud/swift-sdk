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
     Application identity.
     */
    public struct Identity {

        public let ID: String

        public let key: String

        public let region: Region

        public init(ID: String, key: String, region: Region) {
            self.ID = ID
            self.key = key
            self.region = region
        }

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

        public static func < (
            lhs: LCApplication.LogLevel,
            rhs: LCApplication.LogLevel) -> Bool
        {
            return lhs.rawValue < rhs.rawValue
        }

    }

    public static let shared = LCApplication()

    public var identity: Identity!

    public var logLevel: LogLevel = .off

    public init() {
        type(of: self).initialization
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
