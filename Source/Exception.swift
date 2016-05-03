//
//  Exception.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 5/3/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

class Exception {
    enum Name: String {
        case InvalidType
        case Inconsistency
        case NotFound
    }

    static func raise(name: String, reason: String? = nil, userInfo: [NSObject: AnyObject]? = nil) {
        NSException(name: name, reason: reason, userInfo: userInfo).raise()
    }

    static func raise(name: Name, reason: String? = nil, userInfo: [NSObject: AnyObject]? = nil) {
        raise(name.rawValue, reason: reason, userInfo: userInfo)
    }
}