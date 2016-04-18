//
//  LCRelation.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/24/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud relation type.

 This type can be used to make one-to-many relation between objects.
 */
public final class LCRelation: LCType {
    typealias Element = LCObject

    var className: String?

    var value: [Element] = []

    override var JSONValue: AnyObject? {
        return value.map { (element) in element.JSONValue! }
    }

    public required init() {
        super.init()
    }

    convenience init(className: String?) {
        self.init()
        self.className = className
    }

    init?(dictionary: [String: AnyObject]) {
        guard let type = dictionary["__type"] as? String else {
            return nil
        }
        guard let dataType = RESTClient.DataType(rawValue: type) else {
            return nil
        }
        guard case dataType = RESTClient.DataType.Relation else {
            return nil
        }

        className = dictionary["className"] as? String
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        return self
    }

    override func forEachChild(body: (child: LCType) -> Void) {
        value.forEach { body(child: $0) }
    }

    /**
     Append an element.

     - parameter element: The element to be appended.
     */
    func append(element: Element) {
        value = value + [element]
    }

    /**
     Remove an element from list.

     - parameter element: The element to be removed.
     */
    func remove(element: Element) {
        value = value - [element]
    }
}