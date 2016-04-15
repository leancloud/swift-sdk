//
//  LCDate.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/1/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud date type.

 This type used to represent a point in UTC time.
 */
public final class LCDate: LCType {
    public private(set) var value: NSDate = NSDate()

    static let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSS'Z'"
        formatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        return formatter
    }()

    var ISOString: String {
        return LCDate.dateFormatter.stringFromDate(value)
    }

    override var JSONValue: AnyObject? {
        return [
            "__type": "Date",
            "iso": ISOString
        ]
    }

    public required init() {
        super.init()
    }

    public convenience init(_ date: NSDate) {
        self.init()
        value = date
    }

    convenience init(ISOString: String?) {
        self.init()

        if let ISOString = ISOString {
            if let date = LCDate.dateFormatter.dateFromString(ISOString) {
                value = date
            }
        }
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCDate
        copy.value = value
        return copy
    }

    public override func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if let another = another as? LCDate {
            return another.value.isEqualToDate(value)
        } else {
            return false
        }
    }
}