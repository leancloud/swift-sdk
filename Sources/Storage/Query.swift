//
//  Query.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/19/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 Query defines a query for objects.
 */
final public class LCQuery: NSObject, NSCopying, NSCoding {
    /// Object class name.
    public let objectClassName: String

    /// The limit on the number of objects to return.
    public var limit: Int?

    /// The number of objects to skip before returning.
    public var skip: Int?

    /// Included keys.
    fileprivate var includedKeys: Set<String> = []

    /// Selected keys.
    fileprivate var selectedKeys: Set<String> = []

    /// Equality table.
    fileprivate var equalityTable: [String: LCValue] = [:]

    /// Equality key-value pairs.
    fileprivate var equalityPairs: [[String: LCValue]] {
        return equalityTable.map { [$0: $1] }
    }

    /// Ordered keys.
    fileprivate var orderedKeys: String?

    /// Dictionary of constraints indexed by key.
    /// Note that it may contains LCValue or Query value.
    fileprivate var constraintDictionary: [String: AnyObject] = [:]

    /// Extra parameters for query request.
    var extraParameters: [String: AnyObject]?

    /// LCON representation of query.
    var lconValue: [String: AnyObject] {
        var dictionary: [String: AnyObject] = [:]

        dictionary["className"] = objectClassName as AnyObject?

        if !constraintDictionary.isEmpty {
            dictionary["where"] = ObjectProfiler.lconValue(constraintDictionary as AnyObject)
        }
        if !includedKeys.isEmpty {
            dictionary["include"] = includedKeys.joined(separator: ",") as AnyObject?
        }
        if !selectedKeys.isEmpty {
            dictionary["keys"] = selectedKeys.joined(separator: ",") as AnyObject?
        }
        if let orderedKeys = orderedKeys {
            dictionary["order"] = orderedKeys as AnyObject?
        }
        if let limit = limit {
            dictionary["limit"] = limit as AnyObject?
        }
        if let skip = skip {
            dictionary["skip"] = skip as AnyObject?
        }

        if let extraParameters = extraParameters {
            extraParameters.forEach { (key, value) in
                dictionary[key] = value
            }
        }

        return dictionary
    }

    /// Parameters for query request.
    fileprivate var parameters: [String: AnyObject] {
        var parameters = lconValue

        /* Encode where field to string. */
        if let object = parameters["where"] {
            parameters["where"] = Utility.jsonString(object) as AnyObject
        }

        return parameters
    }

    /// The dispatch queue for network request task.
    static let backgroundQueue = DispatchQueue(label: "LeanCloud.Query", attributes: .concurrent)

    /**
     Constraint for key.
     */
    public enum Constraint {
        case included
        case selected
        case existed
        case notExisted

        case equalTo(LCValueConvertible)
        case notEqualTo(LCValueConvertible)
        case lessThan(LCValueConvertible)
        case lessThanOrEqualTo(LCValueConvertible)
        case greaterThan(LCValueConvertible)
        case greaterThanOrEqualTo(LCValueConvertible)

        case containedIn(LCArrayConvertible)
        case notContainedIn(LCArrayConvertible)
        case containedAllIn(LCArrayConvertible)
        case equalToSize(Int)

        case locatedNear(LCGeoPoint, minimal: LCGeoPoint.Distance?, maximal: LCGeoPoint.Distance?)
        case locatedWithin(southwest: LCGeoPoint, northeast: LCGeoPoint)

        case matchedQuery(LCQuery)
        case notMatchedQuery(LCQuery)
        case matchedQueryAndKey(query: LCQuery, key: String)
        case notMatchedQueryAndKey(query: LCQuery, key: String)

        case matchedRegularExpression(String, option: String?)
        case matchedSubstring(String)
        case prefixedBy(String)
        case suffixedBy(String)

        case relatedTo(LCObject)

        case ascending
        case descending
    }

    var endpoint: String {
        return RESTClient.endpoint(objectClassName)
    }

    /**
     Construct query with class name.

     - parameter objectClassName: The class name to query.
     */
    public init(className: String) {
        self.objectClassName = className
    }

    public func copy(with zone: NSZone?) -> Any {
        let query = LCQuery(className: objectClassName)

        query.includedKeys  = includedKeys
        query.selectedKeys  = selectedKeys
        query.equalityTable = equalityTable
        query.constraintDictionary = constraintDictionary
        query.extraParameters = extraParameters
        query.limit = limit
        query.skip  = skip

        return query
    }

    public required init?(coder aDecoder: NSCoder) {
        objectClassName = aDecoder.decodeObject(forKey: "objectClassName") as! String
        includedKeys    = aDecoder.decodeObject(forKey: "includedKeys") as! Set<String>
        selectedKeys    = aDecoder.decodeObject(forKey: "selectedKeys") as! Set<String>
        equalityTable   = aDecoder.decodeObject(forKey: "equalityTable") as! [String: LCValue]
        constraintDictionary = aDecoder.decodeObject(forKey: "constraintDictionary") as! [String: AnyObject]
        extraParameters = aDecoder.decodeObject(forKey: "extraParameters") as? [String: AnyObject]
        limit = aDecoder.decodeObject(forKey: "limit") as? Int
        skip  = aDecoder.decodeObject(forKey: "skip") as? Int
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(objectClassName, forKey: "objectClassName")
        aCoder.encode(includedKeys, forKey: "includedKeys")
        aCoder.encode(selectedKeys, forKey: "selectedKeys")
        aCoder.encode(equalityTable, forKey: "equalityTable")
        aCoder.encode(constraintDictionary, forKey: "constraintDictionary")

        if let extraParameters = extraParameters {
            aCoder.encode(extraParameters, forKey: "extraParameters")
        }
        if let limit = limit {
            aCoder.encode(limit, forKey: "limit")
        }
        if let skip = skip {
            aCoder.encode(skip, forKey: "skip")
        }
    }

    /**
     Add constraint in query.

     - parameter constraint: The constraint.
     */
    public func whereKey(_ key: String, _ constraint: Constraint) {
        var dictionary: [String: AnyObject]?

        switch constraint {
        /* Key matching. */
        case .included:
            includedKeys.insert(key)
        case .selected:
            selectedKeys.insert(key)
        case .existed:
            dictionary = ["$exists": true as AnyObject]
        case .notExisted:
            dictionary = ["$exists": false as AnyObject]

        /* Equality matching. */
        case let .equalTo(value):
            equalityTable[key] = value.lcValue
            constraintDictionary["$and"] = equalityPairs as AnyObject?
        case let .notEqualTo(value):
            dictionary = ["$ne": value.lcValue]
        case let .lessThan(value):
            dictionary = ["$lt": value.lcValue]
        case let .lessThanOrEqualTo(value):
            dictionary = ["$lte": value.lcValue]
        case let .greaterThan(value):
            dictionary = ["$gt": value.lcValue]
        case let .greaterThanOrEqualTo(value):
            dictionary = ["$gte": value.lcValue]

        /* Array matching. */
        case let .containedIn(array):
            dictionary = ["$in": array.lcArray]
        case let .notContainedIn(array):
            dictionary = ["$nin": array.lcArray]
        case let .containedAllIn(array):
            dictionary = ["$all": array.lcArray]
        case let .equalToSize(size):
            dictionary = ["$size": size as AnyObject]

        /* Geography point matching. */
        case let .locatedNear(center, minimal, maximal):
            var value: [String: AnyObject] = ["$nearSphere": center]
            if let min = minimal { value["$minDistanceIn\(min.unit.rawValue)"] = min.value as AnyObject }
            if let max = maximal { value["$maxDistanceIn\(max.unit.rawValue)"] = max.value as AnyObject }
            dictionary = value
        case let .locatedWithin(southwest, northeast):
            dictionary = ["$within": ["$box": [southwest, northeast]] as AnyObject]

        /* Query matching. */
        case let .matchedQuery(query):
            dictionary = ["$inQuery": query]
        case let .notMatchedQuery(query):
            dictionary = ["$notInQuery": query]
        case let .matchedQueryAndKey(query, key):
            dictionary = ["$select": ["query": query, "key": key] as AnyObject]
        case let .notMatchedQueryAndKey(query, key):
            dictionary = ["$dontSelect": ["query": query, "key": key] as AnyObject]

        /* String matching. */
        case let .matchedRegularExpression(regex, option):
            dictionary = ["$regex": regex as AnyObject, "$options": option as AnyObject? ?? "" as AnyObject]
        case let .matchedSubstring(string):
            dictionary = ["$regex": "\(string.regularEscapedString)" as AnyObject]
        case let .prefixedBy(string):
            dictionary = ["$regex": "^\(string.regularEscapedString)" as AnyObject]
        case let .suffixedBy(string):
            dictionary = ["$regex": "\(string.regularEscapedString)$" as AnyObject]

        case let .relatedTo(object):
            constraintDictionary["$relatedTo"] = ["object": object, "key": key] as AnyObject

        case .ascending:
            appendOrderedKey(key)
        case .descending:
            appendOrderedKey("-\(key)")
        }

        if let dictionary = dictionary {
            addConstraint(key, dictionary)
        }
    }

    /**
     Validate query class name.

     - parameter query: The query to be validated.
     */
    func validateClassName(_ query: LCQuery) throws {
        guard query.objectClassName == objectClassName else {
            throw LCError(code: .inconsistency, reason: "Different class names.", userInfo: nil)
        }
    }

    /**
     Get logic AND of another query.

     Note that it only combine constraints of two queries, the limit and skip option will be discarded.

     - parameter query: The another query.

     - returns: The logic AND of two queries.
     */
    public func and(_ query: LCQuery) -> LCQuery {
        try! validateClassName(query)

        let result = LCQuery(className: objectClassName)

        result.constraintDictionary["$and"] = [self.constraintDictionary, query.constraintDictionary] as AnyObject

        return result
    }

    /**
     Get logic OR of another query.

     Note that it only combine constraints of two queries, the limit and skip option will be discarded.

     - parameter query: The another query.

     - returns: The logic OR of two queries.
     */
    public func or(_ query: LCQuery) -> LCQuery {
        try! validateClassName(query)

        let result = LCQuery(className: objectClassName)

        result.constraintDictionary["$or"] = [self.constraintDictionary, query.constraintDictionary] as AnyObject

        return result
    }

    /**
     Append ordered key to ordered keys string.

     - parameter orderedKey: The ordered key with optional '-' prefixed.
     */
    func appendOrderedKey(_ orderedKey: String) {
        orderedKeys = orderedKeys?.appending(orderedKey) ?? orderedKey
    }

    /**
     Add a constraint for key.

     - parameter key:        The key on which the constraint to be added.
     - parameter dictionary: The constraint dictionary for key.
     */
    func addConstraint(_ key: String, _ dictionary: [String: AnyObject]) {
        constraintDictionary[key] = dictionary as AnyObject?
    }

    /**
     Transform JSON results to objects.

     - parameter results: The results return by query.

     - returns: An array of LCObject objects.
     */
    func processResults<T: LCObject>(_ results: [AnyObject], className: String?) -> [T] {
        return results.map { dictionary in
            let object = ObjectProfiler.object(className: className ?? self.objectClassName) as! T

            if let dictionary = dictionary as? [String: AnyObject] {
                ObjectProfiler.updateObject(object, dictionary)
            }

            return object
        }
    }

    /**
     Asynchronize task into background queue.

     - parameter task:       The task to be performed.
     - parameter completion: The completion closure to be called on main thread after task finished.
     */
    static func asynchronize<Result>(_ task: @escaping () -> Result, completion: @escaping (Result) -> Void) {
        Utility.asynchronize(task, backgroundQueue, completion)
    }

    /**
     Query objects synchronously.

     - returns: The result of the query request.
     */
    public func find<T>() -> LCQueryResult<T> {
        let response = RESTClient.request(.get, endpoint, parameters: parameters)

        if let error = response.error {
            return .failure(error: error)
        } else {
            let className = response.value?["className"] as? String
            let objects: [T] = processResults(response.results, className: className)

            return .success(objects: objects)
        }
    }

    /**
     Query objects asynchronously.

     - parameter completion: The completion callback closure.
     */
    public func find<T>(_ completion: @escaping (LCQueryResult<T>) -> Void) {
        LCQuery.asynchronize({ self.find() }) { result in
            completion(result)
        }
    }

    /**
     Get first object of query synchronously.

     - note: All query conditions other than `limit` will take effect for current request.

     - returns: The object result of query.
     */
    public func getFirst<T: LCObject>() -> LCObjectResult<T> {
        let query = copy() as! LCQuery

        query.limit = 1

        let result: LCQueryResult<T> = query.find()

        switch result {
        case let .success(objects):
            guard let object = objects.first else {
                return .failure(error: LCError(code: .notFound, reason: "Object not found."))
            }

            return .success(object: object)
        case let .failure(error):
            return .failure(error: error)
        }
    }

    /**
     Get first object of query asynchronously.

     - parameter completion: The completion callback closure.
     */
    public func getFirst<T: LCObject>(_ completion: @escaping (LCObjectResult<T>) -> Void) {
        LCQuery.asynchronize({ self.getFirst() }) { result in
            completion(result)
        }
    }

    /**
     Get object by object ID synchronously.

     - parameter objectId: The object ID.

     - returns: The object result of query.
     */
    public func get<T: LCObject>(_ objectId: LCStringConvertible) -> LCObjectResult<T> {
        let query = copy() as! LCQuery

        query.whereKey("objectId", .equalTo(objectId.lcString))

        return query.getFirst()
    }

    /**
     Get object by object ID asynchronously.

     - parameter objectId:   The object ID.
     - parameter completion: The completion callback closure.
     */
    public func get<T: LCObject>(_ objectId: LCStringConvertible, completion: @escaping (LCObjectResult<T>) -> Void) {
        LCQuery.asynchronize({ self.get(objectId) }) { result in
            completion(result)
        }
    }

    /**
     Count objects synchronously.

     - returns: The result of the count request.
     */
    public func count() -> LCCountResult {
        var parameters = self.parameters

        parameters["count"] = 1 as AnyObject?
        parameters["limit"] = 0 as AnyObject?

        let response = RESTClient.request(.get, endpoint, parameters: parameters)
        let result = LCCountResult(response: response)

        return result
    }

    /**
     Count objects asynchronously.

     - parameter completion: The completion callback closure.
     */
    public func count(_ completion: @escaping (LCCountResult) -> Void) {
        LCQuery.asynchronize({ self.count() }) { result in
            completion(result)
        }
    }
}
