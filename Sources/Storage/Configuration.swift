//
//  Configuration.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/// Service region.
public enum LCServiceRegion {
    case cn, us
}

class Configuration {
    static let sharedInstance = Configuration()

    var applicationID:  String!
    var applicationKey: String!

    var serviceRegion: LCServiceRegion = .cn
}
