//
//  LCData.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/1/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud data type.

 This type can be used to represent a byte buffers.
 */
public final class LCData: LCType {
    public private(set) var value: NSData = NSData()

    var base64String: String {
        return value.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    }

    override var JSONValue: AnyObject? {
        return [
            "__type": "Bytes",
            "base64": base64String
        ]
    }

    public required init() {
        super.init()
    }

    public convenience init(_ data: NSData) {
        self.init()
        value = data
    }

    convenience init(base64String: String?) {
        self.init()

        if let base64String = base64String {
            if let data = NSData(base64EncodedString: base64String, options: NSDataBase64DecodingOptions(rawValue: 0)) {
                value = data
            }
        }
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCData
        copy.value = value
        return copy
    }

    public override func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if let another = another as? LCData {
            return another.value.isEqualToData(value)
        } else {
            return false
        }
    }
}