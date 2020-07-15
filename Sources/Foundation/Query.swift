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
    
    private var includedKeys: Set<String> = []
    private var selectedKeys: Set<String> = []
    
    private var equalityTable: [String: LCValue] = [:]
    private var equalityPairs: [[String: LCValue]] {
        return self.equalityTable.map { [$0: $1] }
    }
    
    private var orderedKeys: String?
    
    var constraintDictionary: [String: Any] = [:]
    
    var extraParameters: [String: Any]?
    
    var lconValue: [String: Any] {
        var dictionary: [String: Any] = [:]
        dictionary["className"] = self.objectClassName
        if !self.constraintDictionary.isEmpty {
            dictionary["where"] = ObjectProfiler.shared.lconValue(self.constraintDictionary)
        }
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
            extraParameters.forEach { (key, value) in
                dictionary[key] = value
            }
        }
        return dictionary
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
        
        /* Value */
        
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
            throw LCError(
                code: .inconsistency,
                reason: "`application` !== `query.application`, they should be the same instance.")
        }
        guard query.objectClassName == objectClassName else {
            throw LCError(
                code: .inconsistency,
                reason: "`objectClassName` != `query.objectClassName`, they should be equal.")
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
    
    func parameters() throws -> [String: Any] {
        var parameters = self.lconValue
        if let whereObject = parameters["where"],
           let whereString = try Utility.jsonString(whereObject) {
            parameters["where"] = whereString
        }
        return parameters
    }
    
    func processResults<T: LCObject>(
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
    
    func storeResponse(response: LCResponse) {
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
        case onlyNetwork
        case onlyCache
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
        let httpClient: HTTPClient = self.application.httpClient
        var parameters: [String: Any]
        do {
            parameters = try self.parameters()
            if let objectId = objectId.stringValue {            
                parameters["where"] = try Utility.jsonString(["objectId": objectId])
            }
        } catch {
            return httpClient.request(
                error: LCError(error: error),
                completionHandler: completion)
        }
        return self._find(
            parameters: nil,
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
