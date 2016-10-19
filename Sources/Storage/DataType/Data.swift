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
public final class LCData: NSObject, LCValue, LCValueExtension {
    public fileprivate(set) var value: Data = Data()

    var base64EncodedString: String {
        return value.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
    }

    static func dataFromString(_ string: String) -> Data? {
        return Data(base64Encoded: string, options: NSData.Base64DecodingOptions(rawValue: 0))
    }

    public override init() {
        super.init()
    }

    public convenience init(_ data: Data) {
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
        guard case dataType = RESTClient.DataType.bytes else {
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
        value = (aDecoder.decodeObject(forKey: "value") as? Data) ?? Data()
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(value, forKey: "value")
    }

    public func copy(with zone: NSZone?) -> Any {
        return LCData((value as NSData).copy() as! Data)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? LCData {
            return object === self || object.value == value
        } else {
            return false
        }
    }

    public var jsonValue: AnyObject {
        return [
            "__type": "Bytes",
            "base64": base64EncodedString
        ] as AnyObject
    }

    public var jsonString: String {
        return ObjectProfiler.getJSONString(self)
    }

    public var rawValue: LCValueConvertible {
        return value
    }

    var lconValue: AnyObject? {
        return jsonValue
    }

    static func instance() -> LCValue {
        return self.init()
    }

    func forEachChild(_ body: (_ child: LCValue) -> Void) {
        /* Nothing to do. */
    }

    func add(_ other: LCValue) throws -> LCValue {
        throw LCError(code: .invalidType, reason: "Object cannot be added.")
    }

    func concatenate(_ other: LCValue, unique: Bool) throws -> LCValue {
        throw LCError(code: .invalidType, reason: "Object cannot be concatenated.")
    }

    func differ(_ other: LCValue) throws -> LCValue {
        throw LCError(code: .invalidType, reason: "Object cannot be differed.")
    }
}
