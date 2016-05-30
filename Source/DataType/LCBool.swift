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

 It is a wrapper of Swift.Bool type, used to store a boolean value.
 */
public final class LCBool: LCType, NSCoding, BooleanLiteralConvertible {
    public private(set) var value: Bool = false

    override var JSONValue: AnyObject? {
        return value
    }

    public override init() {
        super.init()
    }

    public convenience init(_ value: Bool) {
        self.init()
        self.value = value
    }

    public convenience required init(booleanLiteral value: BooleanLiteralType) {
        self.init(Bool(value))
    }

    public required init?(coder aDecoder: NSCoder) {
        value = aDecoder.decodeBoolForKey("value")
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeBool(value, forKey: "value")
    }

    class override func instance() -> LCType? {
        return self.init()
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        return LCBool(value)
    }

    public override func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if let another = another as? LCBool {
            return another.value == value
        } else {
            return false
        }
    }
}