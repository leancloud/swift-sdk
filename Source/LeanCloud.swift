//
//  LeanCloud.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 Initialize LeanCloud SDK.

 - parameter applicationID:  Application ID.
 - parameter applicationKey: Application key.
 */
public func initialize(applicationID applicationID: String, applicationKey: String) {
    let configure = Configuration.sharedInstance

    configure.applicationID  = applicationID
    configure.applicationKey = applicationKey

    ObjectProfiler.registerSubclasses()
}