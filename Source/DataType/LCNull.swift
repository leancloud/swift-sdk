//
//  LCNull.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud null type.

 A singleton object that represents null value.
 */
public class LCNull: LCType {
    public static let null = LCNull()

    override var JSONValue: AnyObject? {
        return NSNull()
    }

    private override init() {}
}