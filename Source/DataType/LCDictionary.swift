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

 It is a wrapper of NSDictionary type, used to store a dictionary value.
 */
public class LCDictionary: LCType, DictionaryLiteralConvertible {
    public private(set) var value: [String:LCType]?

    public required init() {
        super.init()
    }

    public convenience init(_ value: [String:LCType]) {
        self.init()
        self.value = value
    }

    public convenience required init(dictionaryLiteral elements: (String, LCType)...) {
        var value:[String:LCType] = [:]

        elements.forEach { value[$0] = $1 }

        self.init(value)
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCDictionary
        copy.value = value
        return copy
    }

    override public func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if let another = another as? LCDictionary {
            let lhs = value
            let rhs = another.value

            if lhs == nil && rhs == nil {
                return true
            } else if let lhs = lhs, rhs = rhs {
                return lhs == rhs
            } else {
                return false
            }
        } else {
            return false
        }
    }
}