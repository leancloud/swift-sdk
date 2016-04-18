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
public final class LCRelation: LCType, SequenceType {
    public typealias Element = LCObject

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

    public func generate() -> IndexingGenerator<[Element]> {
        return value.generate()
    }

    override func forEachChild(body: (child: LCType) -> Void) {
        value.forEach { body(child: $0) }
    }

    /**
     Append elements.

     - parameter elements: The elements to be appended.
     */
    func appendElements(elements: [Element]) {
        /* TODO: validate that all elements should have valid class name. */
        value = value + elements
    }

    /**
     Remove elements.

     - parameter elements: The elements to be removed.
     */
    func removeElements(elements: [Element]) {
        value = value - elements
    }
}