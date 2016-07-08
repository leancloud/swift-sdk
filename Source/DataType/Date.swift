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
public final class LCDate: LCType, NSCoding {
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

    public override init() {
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

    init?(JSONValue: AnyObject?) {
        var value: NSDate?

        switch JSONValue {
        case let ISOString as String:
            value = LCDate.dateFromString(ISOString)
        case let dictionary as [String: AnyObject]:
            if let date = LCDate(dictionary: dictionary) {
                value = date.value
            }
        case let date as LCDate:
            value = date.value
        default:
            break
        }

        guard let someValue = value else {
            return nil
        }

        value = someValue
    }

    public required init?(coder aDecoder: NSCoder) {
        value = (aDecoder.decodeObjectForKey("value") as? NSDate) ?? NSDate()
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(value, forKey: "value")
    }

    class override func instance() -> LCType? {
        return self.init()
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        return LCDate(value.copy() as! NSDate)
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