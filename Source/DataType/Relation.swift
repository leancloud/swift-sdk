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

 This type can be used to make one-to-many relationship between objects.
 */
public final class LCRelation: LCType, NSCoding, SequenceType {
    public typealias Element = LCObject

    /// The key where relationship based on.
    var key: String?

    /// The parent of all children in relation.
    weak var parent: LCObject?

    /// The class name of children.
    var className: String?

    /// An array of children added locally.
    var value: [Element] = []

    override var JSONValue: AnyObject? {
        return value.map { (element) in element.JSONValue! }
    }

    internal override init() {
        super.init()
    }

    internal convenience init(key: String, parent: LCObject) {
        self.init()

        self.key    = key
        self.parent = parent
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
        value     = aDecoder.decodeObjectForKey("value") as! [Element]
        className = aDecoder.decodeObjectForKey("className") as? String
    }

    public func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(value, forKey: "value")

        if let className = className {
            aCoder.encodeObject(className, forKey: "className")
        }
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

    /**
     Insert a child into relation.

     - parameter child: The child that you want to insert.
     */
    public func insert(child: LCObject) {
        parent!.insertRelation(key!, object: child)
    }

    /**
     Remove a child from relation.

     - parameter child: The child that you want to remove.
     */
    public func remove(child: LCObject) {
        parent!.removeRelation(key!, object: child)
    }

    /**
     Get query of current relation.
     */
    public var query: LCQuery {
        var query: LCQuery!

        let key = self.key!
        let parent = self.parent!

        /* If class name already known, use it.
           Otherwise, use class name redirection. */
        if let className = className {
            query = LCQuery(className: className)
        } else {
            query = LCQuery(className: parent.actualClassName)
            query.extraParameters = [
                "redirectClassNameForKey": key
            ]
        }

        query.whereKey(key, .RelatedTo(object: parent))

        return query
    }
}