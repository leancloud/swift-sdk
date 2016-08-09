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
public final class LCData: NSObject, LCType, LCTypeExtension {
    public private(set) var value: NSData = NSData()

    var base64EncodedString: String {
        return value.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    }

    static func dataFromString(string: String) -> NSData? {
        return NSData(base64EncodedString: string, options: NSDataBase64DecodingOptions(rawValue: 0))
    }

    public override init() {
        super.init()
    }

    public convenience init(_ data: NSData) {
        self.init()
        value = data
    }

    init?(base64EncodedString: String) {
        guard let data = LCData.dataFromString(base64EncodedString) else {
            return nil
        }

        value = data
    }

    init?(dictionary: [String: AnyObject]) {
        guard let type = dictionary["__type"] as? String else {
            return nil
        }
        guard let dataType = RESTClient.DataType(rawValue: type) else {
            return nil
        }
        guard case dataType = RESTClient.DataType.Bytes else {
            return nil
        }
        guard let base64EncodedString = dictionary["base64"] as? String else {
            return nil
        }
        guard let data = LCData.dataFromString(base64EncodedString) else {
            return nil
        }

        value = data
    }

    public required init?(coder aDecoder: NSCoder) {
        value = (aDecoder.decodeObjectForKey("value") as? NSData) ?? NSData()
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(value, forKey: "value")
    }

    public func copyWithZone(zone: NSZone) -> AnyObject {
        return LCData(value.copy() as! NSData)
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

    public var JSONValue: AnyObject {
        return [
            "__type": "Bytes",
            "base64": base64EncodedString
        ]
    }

    public var JSONString: String {
        return ObjectProfiler.getJSONString(self)
    }

    var LCONValue: AnyObject? {
        return JSONValue
    }

    static func instance() -> LCType {
        return self.init()
    }

    func forEachChild(body: (child: LCType) -> Void) {
        /* Nothing to do. */
    }

    func add(other: LCType) throws -> LCType {
        throw LCError(code: .InvalidType, reason: "Object cannot be added.")
    }

    func concatenate(other: LCType, unique: Bool) throws -> LCType {
        throw LCError(code: .InvalidType, reason: "Object cannot be concatenated.")
    }

    func differ(other: LCType) throws -> LCType {
        throw LCError(code: .InvalidType, reason: "Object cannot be differed.")
    }
}