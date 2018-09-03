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
    typealias BatchResponse = [String: [String: AnyObject]]

    /**
     Update objects with response of batch request.

     - parameter objects:  A set of object to update.
     - parameter response: The response of batch request.
     */
    static func updateObjects(_ objects: Set<LCObject>, _ response: LCResponse) {
        let value = response.value

        guard let dictionary = value as? BatchResponse else {
            return
        }

        dictionary.forEach { (key, value) in
            let filtered = objects.filter { object in
                key == object.objectId?.value || key == object.internalId
            }

            filtered.forEach { object in
                ObjectProfiler.updateObject(object, value)
            }
        }
    }

    /**
     Get batch requests from a set of objects.

     - parameter objects: A set of objects.

     - returns: An array of batch requests.
     */
    private static func createSaveBatchRequests(objects: Set<LCObject>) throws -> [Any] {
        var requests: [BatchRequest] = []
        let toposort = try ObjectProfiler.toposort(objects)

        toposort.forEach { object in
            requests.append(contentsOf: BatchRequestBuilder.buildRequests(object))
        }

        let jsonRequests = try requests.map { request in
            try request.jsonValue()
        }

        return jsonRequests
    }

    /**
     Send a list of batch requests synchronously.

     - parameter requests: A list of batch requests.
     - returns: The response of request.
     */
    private static func saveInOneBatchRequest(_ objects: Set<LCObject>, completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        var requests: [Any]

        do {
            requests = try createSaveBatchRequests(objects: objects)
        } catch let error {
            return RESTClient.request(error: error, completionHandler: completion)
        }

        let parameters = ["requests": requests]

        let request = RESTClient.request(.post, "batch/save", parameters: parameters) { response in
            let result = LCBooleanResult(response: response)

            switch result {
            case .success:
                updateObjects(objects, response)

                objects.forEach { object in
                    object.resetOperation()
                }
            case .failure:
                break
            }

            completion(result)
        }

        return request
    }

    /**
     Save independent objects in one batch request synchronously.

     - parameter objects: An array of independent object.

     - returns: The response of request.
     */
    private static func saveIndependentObjects(_ objects: [LCObject], completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        let family = ObjectProfiler.family(objects)
        let request = saveInOneBatchRequest(family, completionInBackground: completion)

        return request
    }

    /**
     Save all descendant newborn orphans.

     The detail save process is described as follows:

     1. Save deepest newborn orphan objects in one batch request.
     2. Repeat step 1 until all descendant newborn objects saved.

     - parameter objects: An array of root object.
     - returns: The response of request.
     */
    private static func saveNewbornOrphans(_ objects: [LCObject], completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        let newbornOrphans = ObjectProfiler.deepestNewbornOrphans(objects)

        if newbornOrphans.isEmpty {
            return RESTClient.request(object: .success) { result in
                completion(result)
            }
        } else {
            let sequenceRequest = LCSequenceRequest(request: nil)

            let request = saveIndependentObjects(newbornOrphans, completionInBackground: { result in
                switch result {
                case .success:
                    let subsequentRequset = saveNewbornOrphans(objects, completionInBackground: completion)
                    sequenceRequest.setCurrentRequest(subsequentRequset)
                case .failure:
                    completion(result)
                }
            })

            sequenceRequest.setCurrentRequest(request)

            return sequenceRequest
        }
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

     - parameter objects: The objects to be saved.

     - returns: The response of request.
     */
    static func save(_ objects: [LCObject], completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        let objects = Array(Set(objects))

        do {
            try objects.forEach { object in
                try object.validateBeforeSaving()
            }

            try ObjectProfiler.validateCircularReference(objects)
        } catch let error {
            return RESTClient.request(
                error: error,
                completionHandler: completion)
        }

        let sequenceRequest = LCSequenceRequest(request: nil)

        let request = saveNewbornOrphans(objects, completionInBackground: { result in
            switch result {
            case .success:
                let family = ObjectProfiler.family(objects)
                let request = saveInOneBatchRequest(family, completionInBackground: completion)
                sequenceRequest.setCurrentRequest(request)
            case .failure:
                completion(result)
            }
        })

        sequenceRequest.setCurrentRequest(request)

        return sequenceRequest
    }

    /**
     Delete a batch of objects in one request synchronously.

     - parameter objects: An array of objects to be deleted.

     - returns: The response of deletion request.
     */
    static func delete(_ objects: [LCObject], completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        if objects.isEmpty {
            return RESTClient.request(object: .success) { result in
                completion(result)
            }
        } else {
            var requests: [Any]

            do {
                requests = try Set(objects).map { object in
                    try BatchRequest(object: object, method: .delete).jsonValue()
                }
            } catch let error {
                return RESTClient.request(error: error, completionHandler: completion)
            }

            let parameters = ["requests": requests]

            return RESTClient.request(.post, "batch", parameters: parameters) { response in
                completion(LCBooleanResult(response: response))
            }
        }
    }

    /**
     Handle object fetched result.

     - parameter result:  The result returned from server.
     - parameter objects: The objects to be fetched.

     - returns: A boolean result.
     */
    static func handleObjectFetchedResult(_ result: [String: Any], _ objects: [LCObject]) -> LCBooleanResult {
        guard
            let dictionary = result["success"] as? [String: Any],
            let objectId = dictionary["objectId"] as? String
        else {
            let error = LCError(code: .objectNotFound, reason: "Object not found.")
            return .failure(error: error)
        }

        let matchedObjects = objects.filter { object in
            objectId == object.objectId?.value
        }

        matchedObjects.forEach { object in
            ObjectProfiler.updateObject(object, dictionary as [String : AnyObject])
            object.resetOperation()
        }

        return .success
    }

    /**
     Handle fetched response.

     - parameter response: The response of fetch request.
     - parameter objects:  The objects to be fetched.

     - returns: An boolean result.
     */
    static func handleObjectFetchedResponse(_ response: LCResponse, _ objects: [LCObject]) -> LCBooleanResult {
        let result = LCBooleanResult(response: response)

        switch result {
        case .success:
            guard let array = response.value as? [[String: Any]] else {
                return .failure(error: LCError(code: .malformedData, reason: "Malformed response data."))
            }

            var result: LCBooleanResult = .success

            array.forEach { dictionary in
                switch handleObjectFetchedResult(dictionary, objects) {
                case .success:
                    break
                case .failure(let error):
                    result = .failure(error: error)
                }
            }

            return result
        case .failure:
            return result
        }
    }

    /**
     Fetch multiple objects in one request synchronously.

     - parameter objects: An array of objects to be fetched.

     - returns: The response of fetching request.
     */
    static func fetch(_ objects: [LCObject], completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        if objects.isEmpty {
            return RESTClient.request(object: .success) { result in
                completion(result)
            }
        } else {
            var requests: [Any]

            do {
                requests = try Set(objects).map { object in
                    try BatchRequest(object: object, method: .get).jsonValue()
                }
            } catch let error {
                return RESTClient.request(error: error, completionHandler: completion)
            }

            let parameters = ["requests": requests]

            return RESTClient.request(.post, "batch", parameters: parameters) { response in
                var result = LCBooleanResult(response: response)

                switch result {
                case .success:
                    result = handleObjectFetchedResponse(response, objects)
                case .failure:
                    break
                }

                completion(result)
            }
        }
    }
}
