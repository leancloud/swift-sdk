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
    public private(set) var value: NSDictionary?

    public required init() {
        super.init()
    }

    public convenience init(_ value: NSDictionary) {
        self.init()
        self.value = value
    }

    public convenience required init(dictionaryLiteral elements: (String, AnyObject)...) {
        let value = NSMutableDictionary()

        elements.forEach { value[$0] = $1 }

        self.init(value)
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCDictionary

        if let value = self.value {
            copy.value = NSDictionary(dictionary: value as [NSObject : AnyObject], copyItems: false)
        }

        return copy
    }
}