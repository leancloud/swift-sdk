//
//  ObjectUpdater.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/31/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 Object updater.

 This class can be used to create, update and delete object.
 */
class ObjectUpdater {
    /// HTTP Client
    let httpClient: HTTPClient

    var application: LCApplication {
        return httpClient.application
    }

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    /**
     Get batch requests from a set of objects.

     - parameter objects: A set of objects.

     - returns: An array of batch requests.
     */
    private func batchRequests(_ objects: Set<LCObject>) -> [BatchRequest] {
        var requests: [BatchRequest] = []
        let toposort = ObjectProfiler.toposort(objects)

        toposort.forEach { object in
            requests.append(contentsOf: BatchRequestBuilder.buildRequests(object))
        }

        return requests
    }

    typealias BatchResponse = [String: [String: AnyObject]]

    /**
     Update objects with response of batch request.

     - parameter objects:  A set of object to update.
     - parameter response: The response of batch request.
     */
    func updateObjects(_ objects: Set<LCObject>, _ response: LCResponse) {
        let value = response.value

        guard let dictionary = value as? BatchResponse else {
            return
        }

        dictionary.forEach { (key, value) in
            let filtered = objects.filter { object in
                key == object.objectId?.value || key == object.internalId
            }

            filtered.forEach { object in
                ObjectProfiler.updateObject(object, value, application: application)
            }
        }
    }

    /**
     Send a list of batch requests synchronously.

     - parameter requests: A list of batch requests.
     - returns: The response of request.
     */
    private func sendBatchRequests(_ requests: [BatchRequest], _ objects: Set<LCObject>) -> LCResponse {
        let parameters = [
            "requests": requests.map { request in request.jsonValue() }
        ]

        let response = httpClient.request(.post, "batch/save", parameters: parameters as [String: AnyObject])

        if response.isSuccess {
            updateObjects(objects, response)

            objects.forEach { object in
                object.resetOperation()
            }
        }

        return response
    }

    /**
     Validate that all objects should have object ID.

     - parameter objects: A set of objects to validate.
     */
    private func validateObjectId(_ objects: Set<LCObject>) throws {
        try objects.forEach { object in
            if object.objectId == nil {
                throw LCError(code: .notFound, reason: "Object ID not found.", userInfo: nil)
            }
        }
    }

    /**
     Save independent objects in one batch request synchronously.

     - parameter objects: A set of independent objects to save.

     - returns: The response of request.
     */
    private func saveIndependentObjects(_ objects: Set<LCObject>) -> LCResponse {
        var family: Set<LCObject> = []

        objects.forEach { object in
            family.formUnion(ObjectProfiler.family(object))
        }

        let requests = batchRequests(family)
        let response = sendBatchRequests(requests, family)

        /* Validate object ID here to avoid infinite loop when save newborn orphans. */
        if response.isSuccess {
            try! validateObjectId(family)
        }

        return response
    }

    /**
     Save all descendant newborn orphans.

     The detail save process is described as follows:

     1. Save deepest newborn orphan objects in one batch request.
     2. Repeat step 1 until all descendant newborn objects saved.

     - parameter object: The ancestor object.
     - returns: The response of request.
     */
    private func saveNewbornOrphans(_ object: LCObject) -> LCResponse {
        var response = LCResponse()

        repeat {
            let objects = ObjectProfiler.deepestNewbornOrphans(object)

            guard !objects.isEmpty else { break }

            response = saveIndependentObjects(objects)
        } while response.isSuccess
        
        return response
    }

    /**
     Save object and its all descendant objects synchronously.

     The detail save process is described as follows:

     1. Save all descendant newborn orphan objects.
     2. Save root object and all descendant dirty objects in one batch request.

     Definition:

     - Newborn orphan object: object which has no object id and its parent is not an object.
     - Dirty object: object which has object id and was changed (has operations).

     The reason to apply above steps is that:

     We can construct a batch request when newborn object directly attachs on another object.
     However, we cannot construct a batch request for orphan object.

     - parameter object: The root object to be saved.

     - returns: The response of request.
     */
    func save(_ object: LCObject) -> LCResponse {
        object.validateBeforeSaving()

        var response = saveNewbornOrphans(object)

        guard response.isSuccess else { return response }

        /* Now, all newborn orphan objects should saved. We can save the object family safely. */

        let family = ObjectProfiler.family(object)

        let requests = batchRequests(family)

        response = sendBatchRequests(requests, family)

        return response
    }

    /**
     Delete object synchronously.

     - returns: The response of request.
     */
    func delete(_ object: LCObject) -> LCResponse {
        guard let endpoint = HTTPClient.eigenEndpoint(object) else {
            return LCResponse(LCError(code: .notFound, reason: "Object not found."))
        }

        return httpClient.request(.delete, endpoint, parameters: nil)
    }

    /*
     Separate objects by application.
     */
    private static func separate(objects: [LCObject], iterator: (LCApplication, [LCObject]) -> Void) {
        var map: [ObjectIdentifier: NSMutableOrderedSet] = [:]

        objects.forEach { object in
            let key = ObjectIdentifier(object.application)

            if let set = map[key] {
                set.add(object)
            } else {
                map[key] = NSMutableOrderedSet(object: object)
            }
        }

        map.forEach { (_, set) in
            guard
                let objects = set.array as? [LCObject],
                let object = objects.first
            else {
                return
            }

            iterator(object.application, objects)
        }
    }

    /**
     Delete a batch of objects in one request synchronously.

     - parameter objects: An array of objects to be deleted.

     - returns: The response of deletion request.
     */
    static func delete<T: LCObject>(_ objects: [T]) -> LCResponse {
        if objects.isEmpty {
            return LCResponse()
        }

        var subresponses: [LCResponse] = []

        separate(objects: objects) { (application, objects) in
            let requests = objects.map { object in
                BatchRequest(object: object, method: .delete).jsonValue()
            }

            let httpClient = HTTPClient(application: application)
            let parameters = ["requests": requests as AnyObject]
            let response = httpClient.request(.post, "batch", parameters: parameters)

            subresponses.append(response)
        }

        let response = LCResponse(subresponses)

        return response
    }

    /**
     Handle fetched result.

     - parameter result:  The result returned from server.
     - parameter objects: The objects to be fetched.

     - returns: The error response, or nil if error not found.
     */
    static func handleFetchedResult(_ result: AnyObject?, _ objects: [LCObject], _ application: LCApplication) -> LCResponse? {
        let dictionary = (result as? [String: AnyObject]) ?? [:]

        guard let objectId = dictionary["objectId"] as? String else {
            return LCResponse(LCError(code: .objectNotFound, reason: "Object not found."))
        }

        let matched = objects.filter { object in
            objectId == object.objectId?.value
        }

        matched.forEach { object in
            ObjectProfiler.updateObject(object, dictionary, application: application)
            object.resetOperation()
        }

        return nil
    }

    /**
     Handle fetched response.

     - parameter response: The response of fetch request.
     - parameter objects:  The objects to be fetched.

     - returns: The handled response.
     */
    static func handleFetchedResponse(_ response: LCResponse, _ objects: [LCObject], _ application: LCApplication) -> LCResponse {
        guard response.isSuccess else {
            return response
        }
        guard let results = response.value as? [[String: AnyObject]] else {
            return LCResponse(LCError(code: .objectNotFound, reason: "Object not found."))
        }

        var response = response

        for result in results {
            if let errorResponse = handleFetchedResult(result["success"], objects, application) {
                response = errorResponse
            }
        }

        return response
    }

    /**
     Fetch multiple objects in one request synchronously.

     - parameter objects: An array of objects to be fetched.

     - returns: The response of fetching request.
     */
    static func fetch(_ objects: [LCObject]) -> LCResponse {
        if objects.isEmpty {
            return LCResponse()
        }

        /* If any object has no object ID, return not found error. */
        for object in objects {
            guard object.hasObjectId else {
                return LCResponse(LCError(code: .notFound, reason: "Object ID not found."))
            }
        }

        var subresponses: [LCResponse] = []

        separate(objects: objects) { (application, objects) in
            let requests = objects.map { object in
                BatchRequest(object: object, method: .get).jsonValue()
            }

            let httpClient = HTTPClient(application: application)
            let parameters = ["requests": requests as AnyObject]
            let originalResponse = httpClient.request(.post, "batch", parameters: parameters)
            let response = handleFetchedResponse(originalResponse, objects, application)

            subresponses.append(response)
        }

        let response = LCResponse(subresponses)

        return response
    }

    /**
     Fetch object synchronously.

     - returns: The response of request.
     */
    func fetch(_ object: LCObject) -> LCResponse {
        guard let endpoint = HTTPClient.eigenEndpoint(object) else {
            return LCResponse(LCError(code: .notFound, reason: "Object not found."))
        }

        let response = httpClient.request(.get, endpoint, parameters: nil)

        guard response.isSuccess else {
            return response
        }

        let dictionary = (response.value as? [String: AnyObject]) ?? [:]

        guard dictionary["objectId"] != nil else {
            return LCResponse(LCError(code: .objectNotFound, reason: "Object not found."))
        }

        ObjectProfiler.updateObject(object, dictionary, application: application)

        object.resetOperation()

        return response
    }
}
