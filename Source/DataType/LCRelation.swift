//
//  LCRelation.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/24/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

public final class LCRelation: LCType {
    typealias Element = LCObject

    var value: [Element]?

    override var JSONValue: AnyObject {
        return value ?? []
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        return self
    }

    override func forEachChild(body: (child: LCType) -> Void) {
        value?.forEach { body(child: $0) }
    }

    /**
     Append an element.

     - parameter element: The element to be appended.
     */
    func append(element: Element) {
        self.value = self.value + [element]
    }

    /**
     Remove an element from list.

     - parameter element: The element to be removed.
     */
    func remove(element: Element) {
        self.value = self.value - [element]
    }
}