//
//  LCBool.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud boolean type.

 It is a wrapper of Bool type, used to store a bool value.
 */
public class LCBool: LCType, BooleanLiteralConvertible {
    public private(set) var value: Bool?

    public required init() {
        super.init()
    }

    public convenience init(_ value: Bool) {
        self.init()
        self.value = value
    }

    public convenience required init(booleanLiteral value: BooleanLiteralType) {
        self.init()
        self.value = Bool(value)
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCBool
        copy.value = self.value
        return copy
    }
}