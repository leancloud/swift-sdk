//
//  ApplicationOptions.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 31/08/2017.
//  Copyright © 2017 LeanCloud. All rights reserved.
//

import Foundation

public enum LCLogLevel : Int {
    case off
    case debug
    case all

    var isDebugEnabled : Bool {
        return self.rawValue >= LCLogLevel.debug.rawValue
    }
}

public final class LCApplicationOptions {

    open var logLevel : LCLogLevel = .off

}
