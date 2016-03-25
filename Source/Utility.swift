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
}