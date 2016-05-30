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
public final class LCRelation: LCType, NSCoding, SequenceType {
    public typealias Element = LCObject

    var className: String?

    var value: [Element] = []

    override var JSONValue: AnyObject? {
        return value.map { (element) in element.JSONValue! }
    }

    private override init() {
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

    public required init?(coder aDecoder: NSCoder) {
        value = (aDecoder.decodeObjectForKey("value") as? [Element]) ?? []
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(value, forKey: "value")
    }

    class override func instance() -> LCType? {
        return self.init()
    }

    public func generate() -> IndexingGenerator<[Element]> {
        return value.generate()
    }

    override class func operationReducerType() -> OperationReducer.Type {
        return OperationReducer.Relation.self
    }

    override func forEachChild(body: (child: LCType) -> Void) {
        value.forEach { body(child: $0) }
    }

    func validateClassName(objects: [Element]) {
        guard !objects.isEmpty else { return }

        let className = self.className ?? objects.first!.actualClassName

        for object in objects {
            guard object.actualClassName == className else {
                Exception.raise(.InvalidType, reason: "Invalid class name.")
                return
            }
        }
    }

    /**
     Append elements.

     - parameter elements: The elements to be appended.
     */
    func appendElements(elements: [Element]) {
        validateClassName(elements)

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