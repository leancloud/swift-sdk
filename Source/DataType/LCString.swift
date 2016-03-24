//
//  LCString.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud string type.

 It is a wrapper of Swift.String type, used to store a string value.
 */
public final class LCString: LCType, StringLiteralConvertible {
    public private(set) var value: String?

    override var JSONValue: AnyObject {
        return value ?? ""
    }

    public typealias UnicodeScalarLiteralType = Character
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType

    public required init() {
        super.init()
    }

    public convenience init(_ value: String) {
        self.init()
        self.value = value
    }

    public convenience required init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.init(String(value))
    }

    public convenience required init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.init(String(value))
    }

    public convenience required init(stringLiteral value: StringLiteralType) {
        self.init(String(value))
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCString
        copy.value = self.value
        return copy
    }

    override public func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if let another = another as? LCString {
            return another.value == value
        } else {
            return false
        }
    }
}