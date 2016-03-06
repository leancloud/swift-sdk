//
//  LCDictionary.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud dictionary type.

 It is a wrapper of NSDictionary type, used to store a dictionary value.
 */
public class LCDictionary: LCType {
    public private(set) var value: NSDictionary?

    public required init() {
        super.init()
    }

    public convenience init(_ value: NSDictionary) {
        self.init()
        self.value = value
    }
}