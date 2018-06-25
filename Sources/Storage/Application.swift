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

    }

    /**
     Application log level.

     We assume that log levels are ordered.
     */
    public enum LogLevel: Int, Comparable {

        case off
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

}
