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
public class LCQuery: NSObject, NSCopying, NSCoding {
    public let application: LCApplication
    
    /// Object class name.
    public let objectClassName: String

    /// The limit on the number of objects to return.
    public var limit: Int?

    /// The number of objects to skip before returning.
    public var skip: Int?
    
    /// The query result whether include ACL.
    public var includeACL: Bool?

    /// Included keys.
    private var includedKeys: Set<String> = []

    /// Selected keys.
    private var selectedKeys: Set<String> = []

    /// Equality table.
    private var equalityTable: [String: LCValue] = [:]

    /// Equality key-value pairs.
    private var equalityPairs: [[String: LCValue]] {
        return equalityTable.map { [$0: $1] }
    }

    /// Ordered keys.
    private var orderedKeys: String?

    /// Dictionary of constraints indexed by key.
    /// Note that it may contains LCValue or Query value.
    var constraintDictionary: [String: Any] = [:]

    /// Extra parameters for query request.
    var extraParameters: [String: Any]?

    /// LCON representation of query.
    var lconValue: [String: Any] {
        var dictionary: [String: Any] = [:]

        dictionary["className"] = objectClassName

        if !constraintDictionary.isEmpty {
            dictionary["where"] = ObjectProfiler.shared.lconValue(constraintDictionary)
        }
        if !includedKeys.isEmpty {
            dictionary["include"] = includedKeys.joined(separator: ",")
        }
        if !selectedKeys.isEmpty {
            dictionary["keys"] = selectedKeys.joined(separator: ",")
        }
        if let orderedKeys = orderedKeys {
            dictionary["order"] = orderedKeys
        }
        if let limit = limit {
            dictionary["limit"] = limit
        }
        if let skip = skip {
            dictionary["skip"] = skip
        }
        if let includeACL = self.includeACL, includeACL {
            dictionary["returnACL"] = "true"
        }

        if let extraParameters = extraParameters {
            extraParameters.forEach { (key, value) in
                dictionary[key] = value
            }
        }

        return dictionary
    }

    /// Parameters for query request.
    private var parameters: [String: Any] {
        var parameters = lconValue
        do {
            if let object = parameters["where"],
                let jsonString = try Utility.jsonString(object) {
                parameters["where"] = jsonString
            }
        } catch {
            Logger.shared.error(error)
        }
        return parameters
    }

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
        return self.application.httpClient.getClassEndpoint(className: objectClassName)
    }

    /**
     Construct query with class name.

     - parameter objectClassName: The class name to query.
     */
    public init(
        application: LCApplication = LCApplication.default,
        className: String)
    {
        self.application = application
        self.objectClassName = className
    }

    public func copy(with zone: NSZone?) -> Any {
        let query = LCQuery(application: self.application, className: objectClassName)

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
        if let applicationID = aDecoder.decodeObject(forKey: "applicationID") as? String,
            let registeredApplication = LCApplication.registry[applicationID] {
            self.application = registeredApplication
        } else {
            self.application = LCApplication.default
        }
        objectClassName = aDecoder.decodeObject(forKey: "objectClassName") as! String
        includedKeys    = aDecoder.decodeObject(forKey: "includedKeys") as! Set<String>
        selectedKeys    = aDecoder.decodeObject(forKey: "selectedKeys") as! Set<String>
        equalityTable   = aDecoder.decodeObject(forKey: "equalityTable") as! [String: LCValue]
        constraintDictionary = aDecoder.decodeObject(forKey: "constraintDictionary") as! [String: Any]
        extraParameters = aDecoder.decodeObject(forKey: "extraParameters") as? [String: Any]
        limit = aDecoder.decodeObject(forKey: "limit") as? Int
        skip  = aDecoder.decodeObject(forKey: "skip") as? Int
    }

    public func encode(with aCoder: NSCoder) {
        let applicationID: String = self.application.id
        aCoder.encode(applicationID, forKey: "applicationID")
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
        // because self.where will never throw error, so use try!
        try! self.where(key, constraint)
    }
    
    func `where`(_ key: String, _ constraint: Constraint) throws {
        var dictionary: [String: Any]?

        switch constraint {
        /* Key matching. */
        case .included:
            includedKeys.insert(key)
        case .selected:
            selectedKeys.insert(key)
        case .existed:
            dictionary = ["$exists": true]
        case .notExisted:
            dictionary = ["$exists": false]

        /* Equality matching. */
        case let .equalTo(value):
            equalityTable[key] = value.lcValue
            constraintDictionary["$and"] = equalityPairs
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
            dictionary = ["$size": size]

        /* Geography point matching. */
        case let .locatedNear(center, minimal, maximal):
            var value: [String: Any] = ["$nearSphere": center]
            if let min = minimal { value["$minDistanceIn\(min.unit.rawValue)"] = min.value }
            if let max = maximal { value["$maxDistanceIn\(max.unit.rawValue)"] = max.value }
            dictionary = value
        case let .locatedWithin(southwest, northeast):
            dictionary = ["$within": ["$box": [southwest, northeast]]]

        /* Query matching. */
        case let .matchedQuery(query):
            dictionary = ["$inQuery": query]
        case let .notMatchedQuery(query):
            dictionary = ["$notInQuery": query]
        case let .matchedQueryAndKey(query, key):
            dictionary = ["$select": ["query": query, "key": key]]
        case let .notMatchedQueryAndKey(query, key):
            dictionary = ["$dontSelect": ["query": query, "key": key]]

        /* String matching. */
        case let .matchedRegularExpression(regex, option):
            dictionary = ["$regex": regex, "$options": option ?? ""]
        case let .matchedSubstring(string):
            dictionary = ["$regex": "\(string.regularEscapedString)"]
        case let .prefixedBy(string):
            dictionary = ["$regex": "^\(string.regularEscapedString)"]
        case let .suffixedBy(string):
            dictionary = ["$regex": "\(string.regularEscapedString)$"]

        case let .relatedTo(object):
            constraintDictionary["$relatedTo"] = ["object": object, "key": key]

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
    func validateApplicationAndClassName(_ query: LCQuery) throws {
        guard query.application === self.application else {
            throw LCError(code: .inconsistency, reason: "Different application.")
        }
        guard query.objectClassName == objectClassName else {
            throw LCError(code: .inconsistency, reason: "Different class names.")
        }
    }

    /**
     Get logic AND of another query.

     Note that it only combine constraints of two queries, the limit and skip option will be discarded.

     - parameter query: The another query.

     - returns: The logic AND of two queries.
     */
    public func and(_ query: LCQuery) throws -> LCQuery {
        try validateApplicationAndClassName(query)

        let result = LCQuery(application: self.application, className: objectClassName)

        result.constraintDictionary["$and"] = [self.constraintDictionary, query.constraintDictionary]

        return result
    }

    /**
     Get logic OR of another query.

     Note that it only combine constraints of two queries, the limit and skip option will be discarded.

     - parameter query: The another query.

     - returns: The logic OR of two queries.
     */
    public func or(_ query: LCQuery) throws -> LCQuery {
        try validateApplicationAndClassName(query)

        let result = LCQuery(application: self.application, className: objectClassName)

        result.constraintDictionary["$or"] = [self.constraintDictionary, query.constraintDictionary]

        return result
    }

    /**
     Append ordered key to ordered keys string.

     - parameter orderedKey: The ordered key with optional '-' prefixed.
     */
    func appendOrderedKey(_ orderedKey: String) {
        if let orderedKeys: String = self.orderedKeys {
            self.orderedKeys = "\(orderedKeys),\(orderedKey)"
        } else {
            self.orderedKeys = orderedKey
        }
    }

    /**
     Add a constraint for key.

     - parameter key:        The key on which the constraint to be added.
     - parameter dictionary: The constraint dictionary for key.
     */
    func addConstraint(_ key: String, _ dictionary: [String: Any]) {
        constraintDictionary[key] = dictionary
    }

    /**
     Transform JSON results to objects.

     - parameter results: The results return by query.

     - returns: An array of LCObject objects.
     */
    func processResults<T: LCObject>(_ results: [Any], className: String?) -> [T] {
        return results.map { dictionary in
            let object = ObjectProfiler.shared.object(
                application: self.application,
                className: className ?? self.objectClassName) as! T

            if let dictionary = dictionary as? [String: Any] {
                ObjectProfiler.shared.updateObject(object, dictionary)
            }

            return object
        }
    }
    
    func storeResponse(response: LCResponse) {
        guard response.error == nil,
            let urlCache = self.application.httpClient.urlCache,
            let urlRequest = response.response.request,
            let httpResponse = response.response.response,
            let data = response.response.data else {
                return
        }
        urlCache.storeCachedResponse(
            CachedURLResponse(
                response: httpResponse,
                data: data),
            for: urlRequest)
    }
    
    /// The constants used to specify interaction with the cached responses.
    public enum CachePolicy {
        case onlyNetwork
        case onlyCache
        case networkElseCache
    }
    
    /// Query objects synchronously.
    /// - Parameter cachePolicy: The request’s cache policy, default is `onlyNetwork`.
    public func find<T>(cachePolicy: CachePolicy = .onlyNetwork) -> LCQueryResult<T> {
        return expect { fulfill in
            self.find(cachePolicy: cachePolicy, completionInBackground: { result in
                fulfill(result)
            })
        }
    }
    
    /// Query objects asynchronously.
    /// - Parameter cachePolicy: The request’s cache policy, default is `onlyNetwork`.
    /// - Parameter completion: The completion callback closure.
    @discardableResult
    public func find<T>(
        cachePolicy: CachePolicy = .onlyNetwork,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCQueryResult<T>) -> Void)
        -> LCRequest
    {
        return find(cachePolicy: cachePolicy, completionInBackground: { result in
            completionQueue.async {
                completion(result)
            }
        })
    }

    @discardableResult
    private func find<T>(
        cachePolicy: CachePolicy,
        completionInBackground completion: @escaping (LCQueryResult<T>) -> Void)
        -> LCRequest
    {
        return self.application.httpClient.request(.get, endpoint, parameters: parameters, cachePolicy: cachePolicy) { response in
            self.storeResponse(response: response)
            if let error = LCError(response: response) {
                completion(.failure(error: error))
            } else {
                let className: String? = response["className"]
                let objects: [T] = self.processResults(response.results, className: className)
                completion(.success(objects: objects))
            }
        }
    }
    
    /// Get first object of query synchronously.
    /// All query conditions other than `limit` will take effect for current request.
    /// - Parameter cachePolicy: The request’s cache policy, default is `onlyNetwork`.
    public func getFirst<T: LCObject>(cachePolicy: CachePolicy = .onlyNetwork) -> LCValueResult<T> {
        return expect { fulfill in
            self.getFirst(cachePolicy: cachePolicy, completionInBackground: { result in
                fulfill(result)
            })
        }
    }
    
    /// Get first object of query asynchronously.
    /// All query conditions other than `limit` will take effect for current request.
    /// - Parameter cachePolicy: The request’s cache policy, default is `onlyNetwork`.
    /// - Parameter completion: The completion callback closure.
    @discardableResult
    public func getFirst<T: LCObject>(
        cachePolicy: CachePolicy = .onlyNetwork,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCValueResult<T>) -> Void)
        -> LCRequest
    {
        return getFirst(cachePolicy: cachePolicy, completionInBackground: { result in
            completionQueue.async {
                completion(result)
            }
        })
    }

    @discardableResult
    private func getFirst<T: LCObject>(
        cachePolicy: CachePolicy,
        completionInBackground completion: @escaping (LCValueResult<T>) -> Void)
        -> LCRequest
    {
        let query = copy() as! LCQuery

        query.limit = 1

        return query.find(cachePolicy: cachePolicy, completionInBackground: { (result: LCQueryResult<T>) in
            switch result {
            case let .success(objects):
                if let object = objects.first {
                    completion(.success(object: object))
                } else {
                    let error = LCError(code: .objectNotFound, reason: "Object not found.")
                    completion(.failure(error: error))
                }
            case let .failure(error):
                completion(.failure(error: error))
            }
        })
    }
    
    /// Get object by object ID synchronously.
    /// - Parameter objectId: The object ID.
    /// - Parameter cachePolicy: The request’s cache policy, default is `onlyNetwork`.
    public func get<T: LCObject>(
        _ objectId: LCStringConvertible,
        cachePolicy: CachePolicy = .onlyNetwork)
        -> LCValueResult<T>
    {
        return expect { fulfill in
            self.get(objectId: objectId, cachePolicy: cachePolicy, completionInBackground: { result in
                fulfill(result)
            })
        }
    }
    
    /// Get object by object ID asynchronously.
    /// - Parameter objectId: The object ID.
    /// - Parameter cachePolicy: The request’s cache policy, default is `onlyNetwork`.
    /// - Parameter completion: The completion callback closure.
    @discardableResult
    public func get<T: LCObject>(
        _ objectId: LCStringConvertible,
        cachePolicy: CachePolicy = .onlyNetwork,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCValueResult<T>) -> Void)
        -> LCRequest
    {
        return get(objectId: objectId, cachePolicy: cachePolicy, completionInBackground: { result in
            completionQueue.async {
                completion(result)
            }
        })
    }

    @discardableResult
    private func get<T: LCObject>(
        objectId: LCStringConvertible,
        cachePolicy: CachePolicy,
        completionInBackground completion: @escaping (LCValueResult<T>) -> Void)
        -> LCRequest
    {
        let query = copy() as! LCQuery

        query.whereKey("objectId", .equalTo(objectId))

        let request = query.getFirst(cachePolicy: cachePolicy, completionInBackground: completion)

        return request
    }
    
    /// Count objects synchronously.
    /// - Parameter cachePolicy: The request’s cache policy, default is `onlyNetwork`.
    public func count(cachePolicy: CachePolicy = .onlyNetwork) -> LCCountResult {
        return expect { fulfill in
            self.count(cachePolicy: cachePolicy, completionInBackground: { result in
                fulfill(result)
            })
        }
    }
    
    /// Count objects asynchronously.
    /// - Parameter cachePolicy: The request’s cache policy, default is `onlyNetwork`.
    /// - Parameter completion: The completion callback closure.
    @discardableResult
    public func count(
        cachePolicy: CachePolicy = .onlyNetwork,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCCountResult) -> Void)
        -> LCRequest
    {
        return count(cachePolicy: cachePolicy, completionInBackground: { result in
            completionQueue.async {
                completion(result)
            }
        })
    }

    @discardableResult
    private func count(
        cachePolicy: CachePolicy,
        completionInBackground completion: @escaping (LCCountResult) -> Void)
        -> LCRequest
    {
        var parameters = self.parameters

        parameters["count"] = 1
        parameters["limit"] = 0

        return self.application.httpClient.request(.get, endpoint, parameters: parameters, cachePolicy: cachePolicy) { response in
            self.storeResponse(response: response)
            completion(LCCountResult(response: response))
        }
    }
}
