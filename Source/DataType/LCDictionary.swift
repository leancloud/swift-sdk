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
public final class LCDictionary: LCType, SequenceType, DictionaryLiteralConvertible {
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

    class override func instance() -> LCType? {
        return self.init([:])
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCDictionary
        copy.value = value
        return copy
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

    public func generate() -> DictionaryGenerator<String, LCType> {
        return value.generate()
    }

    // MARK: Iteration

    override func forEachChild(body: (child: LCType) -> Void) {
        forEach { (_, value) in body(child: value) }
    }
}