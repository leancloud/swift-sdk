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

    static func dateFromString(string: String) -> NSDate? {
        return dateFormatter.dateFromString(string)
    }

    static func stringFromDate(date: NSDate) -> String {
        return dateFormatter.stringFromDate(date)
    }

    var ISOString: String {
        return LCDate.stringFromDate(value)
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

    init?(ISOString: String) {
        guard let date = LCDate.dateFromString(ISOString) else {
            return nil
        }

        value = date
    }

    init?(dictionary: [String: AnyObject]) {
        guard let type = dictionary["__type"] as? String else {
            return nil
        }
        guard let dataType = RESTClient.DataType(rawValue: type) else {
            return nil
        }
        guard case dataType = RESTClient.DataType.Date else {
            return nil
        }
        guard let ISOString = dictionary["iso"] as? String else {
            return nil
        }
        guard let date = LCDate.dateFromString(ISOString) else {
            return nil
        }

        value = date
    }

    init?(JSONValue: AnyObject) {
        var date: NSDate?

        if let ISOString = JSONValue as? String {
            date = LCDate.dateFromString(ISOString)
        } else if let dictionary = JSONValue as? [String: AnyObject] {
            if let object = LCDate(dictionary: dictionary) {
                date = object.value
            }
        }

        guard let someDate = date else {
            return nil
        }

        value = someDate
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