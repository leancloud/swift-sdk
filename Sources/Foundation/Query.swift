//
//  Query.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/19/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/// Query
public class LCQuery: NSObject, NSCopying, NSCoding {
    
    /// The application this query belong to.
    public let application: LCApplication
    
    /// The class name of the object.
    public let objectClassName: String
    
    /// The limit on the number of objects to return.
    public var limit: Int?
    
    /// The number of objects to skip before returning.
    public var skip: Int?
    
    /// The query result whether include ACL.
    public var includeACL: Bool?
    
    /// If this property is a non-nil value, query will always use it as where condition, default is `nil`.
    public var whereString: String?
    
    /// The ordered keys.
    public var orderedKeys: String?
    
    /// The included keys.
    public var includedKeys: Set<String> = []
    
    /// The selected keys.
    public var selectedKeys: Set<String> = []
    
    var equalityTable: [String: LCValue] = [:]
    var constraintDictionary: [String: Any] = [:]
    var extraParameters: [String: Any]?
    
    var lconValue: [String: Any] {
        var dictionary = self.lconValueWithoutWhere
        if let lconWhere = self.lconWhere {
            dictionary["where"] = lconWhere
        }
        return dictionary
    }
    
    private var lconValueWithoutWhere: [String: Any] {
        var dictionary: [String: Any] = [:]
        dictionary["className"] = self.objectClassName
        if !self.includedKeys.isEmpty {
            dictionary["include"] = self.includedKeys.joined(separator: ",")
        }
        if !self.selectedKeys.isEmpty {
            dictionary["keys"] = self.selectedKeys.joined(separator: ",")
        }
        if let orderedKeys = self.orderedKeys {
            dictionary["order"] = orderedKeys
        }
        if let limit = self.limit {
            dictionary["limit"] = limit
        }
        if let skip = self.skip {
            dictionary["skip"] = skip
        }
        if let includeACL = self.includeACL,
           includeACL {
            dictionary["returnACL"] = "true"
        }
        if let extraParameters = self.extraParameters {
            for (key, value) in extraParameters {
                dictionary[key] = value
            }
        }
        return dictionary
    }
    
    var lconWhere: Any? {
        if !self.constraintDictionary.isEmpty {
            return ObjectProfiler.shared.lconValue(self.constraintDictionary)
        } else {
            return nil
        }
    }
    
    var endpoint: String {
        return self.application.httpClient
            .getClassEndpoint(
                className: self.objectClassName)
    }
    
    /// Initialization.
    /// - Parameters:
    ///   - application: The application this query belong to, default is `LCApplication.default`.
    ///   - className: The name of the class which will be queried.
    public init(
        application: LCApplication = .default,
        className: String)
    {
        self.application = application
        self.objectClassName = className
    }
    
    public func copy(with zone: NSZone?) -> Any {
        let query = LCQuery(
            application: self.application,
            className: self.objectClassName)
        query.limit = self.limit
        query.skip = self.skip
        query.includeACL = self.includeACL
        query.whereString = self.whereString
        query.includedKeys = self.includedKeys
        query.selectedKeys = self.selectedKeys
        query.equalityTable = self.equalityTable
        query.orderedKeys = self.orderedKeys
        query.constraintDictionary = self.constraintDictionary
        query.extraParameters = self.extraParameters
        return query
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard let objectClassName = aDecoder.decodeObject(forKey: "objectClassName") as? String else {
            return nil
        }
        self.objectClassName = objectClassName
        if let applicationID = aDecoder.decodeObject(forKey: "applicationID") as? String,
           let registeredApplication = LCApplication.registry[applicationID] {
            self.application = registeredApplication
        } else {
            self.application = .default
        }
        self.limit = aDecoder.decodeObject(forKey: "limit") as? Int
        self.skip = aDecoder.decodeObject(forKey: "skip") as? Int
        self.includeACL = aDecoder.decodeObject(forKey: "skip") as? Bool
        self.whereString = aDecoder.decodeObject(forKey: "whereString") as? String
        self.includedKeys = aDecoder.decodeObject(forKey: "includedKeys") as? Set<String> ?? []
        self.selectedKeys = aDecoder.decodeObject(forKey: "selectedKeys") as? Set<String> ?? []
        self.equalityTable = aDecoder.decodeObject(forKey: "equalityTable") as? [String: LCValue] ?? [:]
        self.orderedKeys = aDecoder.decodeObject(forKey: "orderedKeys") as? String
        self.constraintDictionary = aDecoder.decodeObject(forKey: "constraintDictionary") as? [String: Any] ?? [:]
        self.extraParameters = aDecoder.decodeObject(forKey: "extraParameters") as? [String: Any]
    }
    
    public func encode(with aCoder: NSCoder) {
        let applicationID: String = self.application.id
        aCoder.encode(applicationID, forKey: "applicationID")
        aCoder.encode(self.objectClassName, forKey: "objectClassName")
        if let limit = self.limit {
            aCoder.encode(limit, forKey: "limit")
        }
        if let skip = self.skip {
            aCoder.encode(skip, forKey: "skip")
        }
        if let includeACL = self.includeACL {
            aCoder.encode(includeACL, forKey: "includeACL")
        }
        if let whereString = self.whereString {
            aCoder.encode(whereString, forKey: "whereString")
        }
        aCoder.encode(self.includedKeys, forKey: "includedKeys")
        aCoder.encode(self.selectedKeys, forKey: "selectedKeys")
        aCoder.encode(self.equalityTable, forKey: "equalityTable")
        if let orderedKeys = self.orderedKeys {
            aCoder.encode(orderedKeys, forKey: "orderedKeys")
        }
        aCoder.encode(self.constraintDictionary, forKey: "constraintDictionary")
        if let extraParameters = self.extraParameters {
            aCoder.encode(extraParameters, forKey: "extraParameters")
        }
    }
    
    /// Constraint for key.
    public enum Constraint {
        /* Key */
        
        /// The value of the key contains all metadata;
        /// Supporting key path by concatenating multiple keys with `.`.
        case included
        /// Only the value of the key will return, prefixing the key with `-` means only the value of the key will not return;
        /// Supporting key path by concatenating multiple keys with `.`.
        case selected
        /// Whether the field exist.
        case existed
        /// Whether the field not exist.
        case notExisted
        
        /* Equality */
        
        /// See `$eq` in MongoDB.
        case equalTo(LCValueConvertible)
        /// See `$ne` in MongoDB.
        case notEqualTo(LCValueConvertible)
        /// See `$lt` in MongoDB.
        case lessThan(LCValueConvertible)
        /// See `$lte` in MongoDB.
        case lessThanOrEqualTo(LCValueConvertible)
        /// See `$gt` in MongoDB.
        case greaterThan(LCValueConvertible)
        /// See `$gte` in MongoDB.
        case greaterThanOrEqualTo(LCValueConvertible)
        
        /* Array */
        
        /// See `$in` in MongoDB.
        case containedIn(LCArrayConvertible)
        /// See `$nin` in MongoDB.
        case notContainedIn(LCArrayConvertible)
        /// See `$all` in MongoDB.
        case containedAllIn(LCArrayConvertible)
        /// See `$size` in MongoDB.
        case equalToSize(Int)
        
        /* GeoPoint */
        
        /// See `$nearSphere`, `$minDistance` and `$maxDistance` in MongoDB.
        case locatedNear(LCGeoPoint, minimal: LCGeoPoint.Distance?, maximal: LCGeoPoint.Distance?)
        /// See `$geoWithin` and `$box` in MongoDB.
        case locatedWithin(southwest: LCGeoPoint, northeast: LCGeoPoint)
        
        /* Query */
        
        /// The value of the key match the query.
        case matchedQuery(LCQuery)
        /// The value of the key not match the query.
        case notMatchedQuery(LCQuery)
        /// The value of the key match the query and the key of the value will be `selected`.
        case matchedQueryAndKey(query: LCQuery, key: String)
        /// The value of the key match the query and the key of the value will not be `selected`.
        case notMatchedQueryAndKey(query: LCQuery, key: String)
        
        /* String */
        
        /// See `$regex` and `$options` in MongoDB.
        case matchedRegularExpression(String, option: String?)
        /// The string of the key contains the string.
        case matchedSubstring(String)
        /// The string of the key has the prefix.
        case prefixedBy(String)
        /// The string of the key has the suffix.
        case suffixedBy(String)
        
        /* Relation */
        
        /// Relation
        case relatedTo(LCObject)
        
        /* Order */
        
        /// Ascending
        case ascending
        /// Descending
        case descending
    }
    
    /// Add a constraint for key.
    /// - Parameters:
    ///   - key: The key will be constrained.
    ///   - constraint: See `Constraint`.
    public func whereKey(_ key: String, _ constraint: Constraint) {
        do {
            try self.where(key, constraint)
        } catch {
            Logger.shared.error(error)
        }
    }
    
    /// Add a constraint for key.
    /// - Parameters:
    ///   - key: The key will be constrained.
    ///   - constraint: See `Constraint`.
    /// - Throws: `LCError`
    public func `where`(_ key: String, _ constraint: Constraint) throws {
        var dictionary: [String: Any]?
        switch constraint {
        /* Key */
        case .included:
            self.includedKeys.insert(key)
        case .selected:
            self.selectedKeys.insert(key)
        case .existed:
            dictionary = ["$exists": true]
        case .notExisted:
            dictionary = ["$exists": false]
        /* Equality */
        case let .equalTo(value):
            self.equalityTable[key] = value.lcValue
            self.constraintDictionary["$and"] = self.equalityTable.map { [$0: $1] }
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
        /* Array */
        case let .containedIn(array):
            dictionary = ["$in": array.lcArray]
        case let .notContainedIn(array):
            dictionary = ["$nin": array.lcArray]
        case let .containedAllIn(array):
            dictionary = ["$all": array.lcArray]
        case let .equalToSize(size):
            dictionary = ["$size": size]
        /* GeoPoint */
        case let .locatedNear(center, minimal, maximal):
            dictionary = ["$nearSphere": center]
            if let min = minimal {
                dictionary?["$minDistanceIn\(min.unit.rawValue)"] = min.value
            }
            if let max = maximal {
                dictionary?["$maxDistanceIn\(max.unit.rawValue)"] = max.value
            }
        case let .locatedWithin(southwest, northeast):
            dictionary = [
                "$within": [
                    "$box": [southwest, northeast]
                ]
            ]
        /* Query */
        case let .matchedQuery(query):
            try self.validateApplication(query)
            dictionary = ["$inQuery": query]
        case let .notMatchedQuery(query):
            try self.validateApplication(query)
            dictionary = ["$notInQuery": query]
        case let .matchedQueryAndKey(query, key):
            try self.validateApplication(query)
            dictionary = [
                "$select": [
                    "query": query,
                    "key": key
                ]
            ]
        case let .notMatchedQueryAndKey(query, key):
            try self.validateApplication(query)
            dictionary = [
                "$dontSelect": [
                    "query": query,
                    "key": key
                ]
            ]
        /* String */
        case let .matchedRegularExpression(regex, option):
            dictionary = [
                "$regex": regex,
                "$options": (option ?? "")
            ]
        case let .matchedSubstring(string):
            dictionary = ["$regex": "\(string.regularEscapedString)"]
        case let .prefixedBy(string):
            dictionary = ["$regex": "^\(string.regularEscapedString)"]
        case let .suffixedBy(string):
            dictionary = ["$regex": "\(string.regularEscapedString)$"]
        /* Relation */
        case let .relatedTo(object):
            self.constraintDictionary["$relatedTo"] = [
                "object": object,
                "key": key
            ]
        /* Order */
        case .ascending:
            self.appendOrderedKey(key)
        case .descending:
            self.appendOrderedKey("-\(key)")
        }
        if let dictionary = dictionary {
            self.constraintDictionary[key] = dictionary
        }
    }
    
    private func appendOrderedKey(_ key: String) {
        if let keys = self.orderedKeys {
            self.orderedKeys = "\(keys),\(key)"
        } else {
            self.orderedKeys = key
        }
    }
    
    private func validateApplication(_ query: LCQuery) throws {
        guard self.application === query.application else {
            throw LCError(
                code: .inconsistency,
                reason: "`self.application` !== `query.application`, they should be the same instance.")
        }
    }
    
    private func validateClassName(_ query: LCQuery) throws {
        guard self.objectClassName == query.objectClassName else {
            throw LCError(
                code: .inconsistency,
                reason: "`self.objectClassName` != `query.objectClassName`, they should be equal.")
        }
    }
    
    private static func validateApplicationAndClassName(_ queries: [LCQuery]) throws {
        guard let first = queries.first else {
            return
        }
        for item in queries {
            try first.validateApplication(item)
            try first.validateClassName(item)
        }
    }
    
    private static func combine(
        queries: [LCQuery],
        operation: String) throws -> LCQuery
    {
        try self.validateApplicationAndClassName(queries)
        guard let first = queries.first else {
            throw LCError(
                code: .inconsistency,
                reason: "`queries` is empty.")
        }
        let query = LCQuery(
            application: first.application,
            className: first.objectClassName)
        query.constraintDictionary[operation] = queries.map { $0.constraintDictionary }
        return query
    }
    
    /// Performs a logical AND operation on an array of one or more expressions of query.
    /// - Parameter queries: An array of one or more expressions of query.
    /// - Throws: `LCError`
    /// - Returns: A new `LCQuery`.
    public class func and(_ queries: [LCQuery]) throws -> LCQuery {
        return try self.combine(queries: queries, operation: "$and")
    }
    
    /// Performs a logical AND operation on self and the query.
    /// - Parameter query: The query.
    /// - Throws: `LCError`
    /// - Returns: A new `LCQuery`.
    public func and(_ query: LCQuery) throws -> LCQuery {
        return try LCQuery.and([self, query])
    }
    
    /// Performs a logical OR operation on an array of one or more expressions of query.
    /// - Parameter queries: An array of one or more expressions of query.
    /// - Throws: `LCError`
    /// - Returns: A new `LCQuery`.
    public class func or(_ queries: [LCQuery]) throws -> LCQuery {
        return try self.combine(queries: queries, operation: "$or")
    }
    
    /// Performs a logical OR operation on self and the query.
    /// - Parameter query: The query.
    /// - Throws: `LCError`
    /// - Returns: A new `LCQuery`.
    public func or(_ query: LCQuery) throws -> LCQuery {
        return try LCQuery.or([self, query])
    }
    
    func lconWhereString() throws -> String? {
        var string: String?
        if let whereString = self.whereString {
            string = whereString
        } else if let lconWhere = self.lconWhere,
                  let whereString = try Utility.jsonString(lconWhere) {
            string = whereString
        }
        return string
    }
    
    private func parameters() throws -> [String: Any] {
        var parameters = self.lconValueWithoutWhere
        if let whereString = try self.lconWhereString() {
            parameters["where"] = whereString
        }
        return parameters
    }
    
    private func processResults<T: LCObject>(
        _ results: [Any],
        className: String?) throws -> [T]
    {
        let className = className ?? self.objectClassName
        return try results.map { dictionary in
            guard let object = ObjectProfiler.shared.object(
                    application: self.application,
                    className: className) as? T else {
                throw LCError(
                    code: .malformedData,
                    userInfo: [
                        "className": className,
                        "data": dictionary,
                    ])
            }
            if let dictionary = dictionary as? [String: Any] {
                ObjectProfiler.shared.updateObject(object, dictionary)
            }
            return object
        }
    }
    
    private func storeResponse(response: LCResponse) {
        guard response.isSuccess,
              let urlCache = self.application.httpClient.urlCache,
              let urlRequest = response.response.request,
              let urlResponse = response.response.response,
              let data = response.response.data else {
            return
        }
        urlCache.storeCachedResponse(
            CachedURLResponse(
                response: urlResponse,
                data: data),
            for: urlRequest)
    }
    
    /// The constants used to specify interaction with the cached responses.
    public enum CachePolicy {
        /// Always query from the network.
        case onlyNetwork
        /// Always query from the local cache.
        case onlyCache
        /// Firstly query from the network, if the result is failed, then query from the local cache.
        case networkElseCache
    }
    
    // MARK: Find
    
    /// Query objects synchronously.
    /// - Parameter cachePolicy: See `CachePolicy`, default is `CachePolicy.onlyNetwork`.
    /// - Returns: The result of query.
    public func find<T: LCObject>(cachePolicy: CachePolicy = .onlyNetwork) -> LCQueryResult<T> {
        return expect { fulfill in
            self._find(cachePolicy: cachePolicy) { (result) in
                fulfill(result)
            }
        }
    }
    
    /// Query objects asynchronously.
    /// - Parameters:
    ///   - cachePolicy: See `CachePolicy`, default is `CachePolicy.onlyNetwork`.
    ///   - completionQueue: The queue where the `completion` be called, default is `DispatchQueue.main`.
    ///   - completion: The result callback of query.
    /// - Returns: `LCRequest`
    @discardableResult
    public func find<T: LCObject>(
        cachePolicy: CachePolicy = .onlyNetwork,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCQueryResult<T>) -> Void) -> LCRequest
    {
        return self._find(cachePolicy: cachePolicy) { result in
            completionQueue.async {
                completion(result)
            }
        }
    }
    
    @discardableResult
    private func _find<T: LCObject>(
        parameters: [String: Any]? = nil,
        cachePolicy: CachePolicy,
        completion: @escaping (LCQueryResult<T>) -> Void) -> LCRequest
    {
        let httpClient: HTTPClient = self.application.httpClient
        let requestParameters: [String: Any]
        if let parameters = parameters {
            requestParameters = parameters
        } else {
            do {
                requestParameters = try self.parameters()
            } catch {
                return httpClient.request(
                    error: LCError(error: error),
                    completionHandler: completion)
            }
        }
        return httpClient.request(
            .get, self.endpoint,
            parameters: requestParameters,
            cachePolicy: cachePolicy)
        { response in
            self.storeResponse(response: response)
            if let error = LCError(response: response) {
                completion(.failure(error: error))
            } else {
                do {
                    let objects: [T] = try self.processResults(
                        response.results,
                        className: response["className"])
                    completion(.success(objects: objects))
                } catch {
                    let err = LCError(error: error)
                    completion(.failure(error: err))
                }
            }
        }
    }
    
    // MARK: Get First
    
    /// Get first object synchronously.
    /// - Parameter cachePolicy: See `CachePolicy`, default is `CachePolicy.onlyNetwork`.
    /// - Returns: The result of query.
    public func getFirst<T: LCObject>(cachePolicy: CachePolicy = .onlyNetwork) -> LCValueResult<T> {
        return expect { fulfill in
            self._getFirst(cachePolicy: cachePolicy) { result in
                fulfill(result)
            }
        }
    }
    
    /// Get first object asynchronously.
    /// - Parameters:
    ///   - cachePolicy: See `CachePolicy`, default is `CachePolicy.onlyNetwork`.
    ///   - completionQueue: The queue where the `completion` be called, default is `DispatchQueue.main`.
    ///   - completion: The result callback of query.
    /// - Returns: `LCRequest`
    @discardableResult
    public func getFirst<T: LCObject>(
        cachePolicy: CachePolicy = .onlyNetwork,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCValueResult<T>) -> Void) -> LCRequest
    {
        return self._getFirst(cachePolicy: cachePolicy) { result in
            completionQueue.async {
                completion(result)
            }
        }
    }
    
    @discardableResult
    private func _getFirst<T: LCObject>(
        cachePolicy: CachePolicy,
        completion: @escaping (LCValueResult<T>) -> Void) -> LCRequest
    {
        let httpClient: HTTPClient = self.application.httpClient
        var parameters: [String: Any]
        do {
            parameters = try self.parameters()
        } catch {
            return httpClient.request(
                error: LCError(error: error),
                completionHandler: completion)
        }
        parameters["limit"] = 1
        return self._find(
            parameters: parameters,
            cachePolicy: cachePolicy)
        { (result: LCQueryResult<T>) in
            switch result {
            case .success(let objects):
                if let object = objects.first {
                    completion(.success(object: object))
                } else {
                    let error = LCError(
                        code: .objectNotFound,
                        reason: "Object not found.")
                    completion(.failure(error: error))
                }
            case .failure(let error):
                completion(.failure(error: error))
            }
        }
    }
    
    // MARK: Get
    
    /// Get object by ID synchronously.
    /// - Parameters:
    ///   - objectId: The ID of the object.
    ///   - cachePolicy: See `CachePolicy`, default is `CachePolicy.onlyNetwork`.
    /// - Returns: The result of query.
    public func get<T: LCObject>(
        _ objectId: LCStringConvertible,
        cachePolicy: CachePolicy = .onlyNetwork) -> LCValueResult<T>
    {
        return expect { fulfill in
            self._get(
                objectId: objectId,
                cachePolicy: cachePolicy)
            { result in
                fulfill(result)
            }
        }
    }
    
    /// Get object by ID asynchronously.
    /// - Parameters:
    ///   - objectId: The ID of the object.
    ///   - cachePolicy: See `CachePolicy`, default is `CachePolicy.onlyNetwork`.
    ///   - completionQueue: The queue where the `completion` be called, default is `DispatchQueue.main`.
    ///   - completion: The result callback of query.
    /// - Returns: `LCRequest`
    @discardableResult
    public func get<T: LCObject>(
        _ objectId: LCStringConvertible,
        cachePolicy: CachePolicy = .onlyNetwork,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCValueResult<T>) -> Void) -> LCRequest
    {
        return self._get(
            objectId: objectId,
            cachePolicy: cachePolicy)
        { result in
            completionQueue.async {
                completion(result)
            }
        }
    }
    
    @discardableResult
    private func _get<T: LCObject>(
        objectId: LCStringConvertible,
        cachePolicy: CachePolicy,
        completion: @escaping (LCValueResult<T>) -> Void) -> LCRequest
    {
        let query = self.copy() as! LCQuery
        query.whereKey("objectId", .equalTo(objectId))
        return query._find(cachePolicy: cachePolicy) { (result: LCQueryResult<T>) in
            switch result {
            case .success(let objects):
                if let object = objects.first {
                    completion(.success(object: object))
                } else {
                    let error = LCError(
                        code: .objectNotFound,
                        reason: "Object not found.")
                    completion(.failure(error: error))
                }
            case .failure(let error):
                completion(.failure(error: error))
            }
        }
    }
    
    // MARK: Count
    
    /// Count objects synchronously.
    /// - Parameter cachePolicy: See `CachePolicy`, default is `CachePolicy.onlyNetwork`.
    /// - Returns: The result of query.
    public func count(cachePolicy: CachePolicy = .onlyNetwork) -> LCCountResult {
        return expect { fulfill in
            self._count(cachePolicy: cachePolicy) { result in
                fulfill(result)
            }
        }
    }
    
    /// Count objects asynchronously.
    /// - Parameters:
    ///   - cachePolicy: See `CachePolicy`, default is `CachePolicy.onlyNetwork`.
    ///   - completionQueue: The queue where the `completion` be called, default is `DispatchQueue.main`.
    ///   - completion: The result callback of query.
    /// - Returns: `LCRequest`
    @discardableResult
    public func count(
        cachePolicy: CachePolicy = .onlyNetwork,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCCountResult) -> Void) -> LCRequest
    {
        return self._count(cachePolicy: cachePolicy) { result in
            completionQueue.async {
                completion(result)
            }
        }
    }
    
    @discardableResult
    private func _count(
        cachePolicy: CachePolicy,
        completion: @escaping (LCCountResult) -> Void) -> LCRequest
    {
        let httpClient: HTTPClient = self.application.httpClient
        var parameters: [String: Any]
        do {
            parameters = try self.parameters()
        } catch {
            return httpClient.request(
                error: LCError(error: error),
                completionHandler: completion)
        }
        parameters["count"] = 1
        parameters["limit"] = 0
        return httpClient.request(
            .get, self.endpoint,
            parameters: parameters,
            cachePolicy: cachePolicy)
        { response in
            self.storeResponse(response: response)
            completion(LCCountResult(response: response))
        }
    }
}
