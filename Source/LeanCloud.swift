//
//  LeanCloud.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

public let Version = "0.0.1.beta"

/**
 Initialize LeanCloud SDK.

 - parameter applicationID:  Application ID.
 - parameter applicationKey: Application key.
 */
public func initialize(applicationID applicationID: String, applicationKey: String) {
    let configure = Configuration.sharedInstance

    configure.applicationID  = applicationID
    configure.applicationKey = applicationKey

    ObjectProfiler.registerClasses()
}

/**
 Set service region.

 - parameter serviceRegion: The service region.
 */
public func setServiceRegion(serviceRegion: LCServiceRegion) {
    Configuration.sharedInstance.serviceRegion = serviceRegion
}