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

 A LeanCloud data type represents null value.

 - note: This type is not a singleton type, because Swift do not support singleton well currently.
 */
public class LCNull: LCType, NSCoding {
    override var JSONValue: AnyObject? {
        return NSNull()
    }

    public override init() {
        super.init()
    }

    public required init?(coder aDecoder: NSCoder) {
        /* Nothing to decode. */
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        /* Nothing to encode. */
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        return LCNull()
    }

    public override func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if another is LCNull {
            return true
        } else {
            return false
        }
    }
}