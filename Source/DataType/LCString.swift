//
//  LCString.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud string type.

 It is a wrapper of String type, used to store a string value.
 */
public class LCString: LCType {
    public private(set) var value: String?

    public required init() {
        super.init()
    }

    public convenience init(_ value: String) {
        self.init()
        self.value = value
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCString
        copy.value = self.value
        return copy
    }
}