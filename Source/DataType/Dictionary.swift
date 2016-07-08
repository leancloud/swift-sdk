//
//  LCDictionary.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud dictionary type.

 It is a wrapper of Swift.Dictionary type, used to store a dictionary value.
 */
public final class LCDictionary: LCType, NSCoding, SequenceType, DictionaryLiteralConvertible {
    public private(set) var value: [String: LCType] = [:]

    override var JSONValue: AnyObject? {
        return value.mapValue { value in value.JSONValue! }
    }

    public override init() {
        super.init()
    }

    public convenience init(_ value: [String: LCType]) {
        self.init()
        self.value = value
    }

    public convenience required init(dictionaryLiteral elements: (String, LCType)...) {
        self.init(Dictionary<String, LCType>(elements: elements))
    }

    public required init?(coder aDecoder: NSCoder) {
        value = (aDecoder.decodeObjectForKey("value") as? [String: LCType]) ?? [:]
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(value, forKey: "value")
    }

    class override func instance() -> LCType? {
        return self.init([:])
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        return LCDictionary(value)
    }

    public override func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if let another = another as? LCDictionary {
            return another.value == value
        } else {
            return false
        }
    }

    public subscript(key: String) -> LCType? {
        get { return value[key] }
        set { value[key] = newValue }
    }

    public func generate() -> DictionaryGenerator<String, LCType> {
        return value.generate()
    }

    // MARK: Iteration

    override func forEachChild(body: (child: LCType) -> Void) {
        forEach { (_, value) in body(child: value) }
    }
}