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
    typealias BatchResponse = [String: [String: Any]]

    /**
     Update objects with response of batch request.

     - parameter objects:  An array of object to update.
     - parameter response: The response of batch request.
     */
    static func updateObjects(_ objects: [LCObject], _ response: LCResponse) {
        let value = response.value

        guard let dictionary = value as? BatchResponse else {
            return
        }

        dictionary.forEach { (key, value) in
            let filtered = objects.filter { object in
                key == object.objectId?.value || key == object.internalId
            }

            filtered.forEach { object in
                ObjectProfiler.shared.updateObject(object, value)
            }
        }
    }

    /**
     Get batch requests for an array of objects.

     - parameter objects: An array of objects.

     - returns: An array of batch requests.
     */
    private static func createSaveBatchRequests(objects: [LCObject], parameters: [String: Any]?) throws -> [Any] {
        var requests: [BatchRequest] = []
        let toposort = try ObjectProfiler.shared.toposort(objects)

        try toposort.forEach { object in
            if !object.hasObjectId,
                let file = object as? LCFile {
                guard let remoteURL = file.url else {
                    throw LCError(
                        code: .notFound,
                        reason: "External URL not found.")
                }
                file.paddingInfo(remoteURL: remoteURL)
            }
            requests.append(contentsOf: try BatchRequestBuilder.buildRequests(object, parameters: parameters))
        }

        let jsonRequests = try requests.map { request in
            try request.jsonValue()
        }

        return jsonRequests
    }

    private static func saveInOneBatchRequest(
        _ objects: [LCObject],
        parameters: [String: Any]?,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let httpClient: HTTPClient = (objects.first?.application ?? .default).httpClient
        guard !objects.isEmpty else {
            return httpClient.request(object: .success, completionHandler: completion)
        }
        do {
            let requests = try createSaveBatchRequests(objects: objects, parameters: parameters)
            if requests.isEmpty {
                return httpClient.request(object: .success, completionHandler: completion)
            } else {
                return httpClient.request(
                    .post, "batch/save",
                    parameters: ["requests": requests])
                { response in
                    let result = LCBooleanResult(response: response)
                    if case .success = result {
                        self.updateObjects(objects, response)
                        objects.forEach { object in
                            object.discardChanges()
                            object.objectDidSave()
                        }
                    }
                    completion(result)
                }
            }
        } catch {
            return httpClient.request(error: error, completionHandler: completion)
        }
    }

    /**
     Save independent objects in one batch request synchronously.

     - parameter objects: An array of independent object.

     - returns: The response of request.
     */
    private static func saveIndependentObjects(_ objects: [LCObject], parameters: [String: Any]?, completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        do {
            let family = try ObjectProfiler.shared.family(objects)
            return saveInOneBatchRequest(family, parameters: parameters, completionInBackground: completion)
        } catch let error {
            return (objects.first?.application ?? LCApplication.default).httpClient.request(error: error, completionHandler: completion)
        }
    }

    /**
     Save all descendant newborn orphans.

     The detail save process is described as follows:

     1. Save deepest newborn orphan objects in one batch request.
     2. Repeat step 1 until all descendant newborn objects saved.

     - parameter objects: An array of root object.
     - returns: The response of request.
     */
    private static func saveNewbornOrphans(_ objects: [LCObject], parameters: [String: Any]?, completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        let newbornOrphans = ObjectProfiler.shared.deepestNewbornOrphans(objects)

        if newbornOrphans.isEmpty {
            return (objects.first?.application ?? LCApplication.default).httpClient.request(object: .success) { result in
                completion(result)
            }
        } else {
            let sequenceRequest = LCSequenceRequest()

            let request = saveIndependentObjects(newbornOrphans, parameters: parameters, completionInBackground: { result in
                switch result {
                case .success:
                    let subsequentRequset = saveNewbornOrphans(objects, parameters: parameters, completionInBackground: completion)
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
    static func save(_ objects: [LCObject], parameters: [String: Any]?, completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        var family: [LCObject]
        let objects = objects.unique

        do {
            family = try ObjectProfiler.shared.family(objects)

            try family.forEach { object in
                try object.validateBeforeSaving()
            }
        } catch let error {
            return (objects.first?.application ?? LCApplication.default).httpClient.request(
                error: error,
                completionHandler: completion)
        }

        let sequenceRequest = LCSequenceRequest()

        let request = saveNewbornOrphans(objects, parameters: parameters, completionInBackground: { result in
            switch result {
            case .success:
                let request = saveInOneBatchRequest(family, parameters: parameters, completionInBackground: completion)
                sequenceRequest.setCurrentRequest(request)
            case .failure:
                completion(result)
            }
        })

        sequenceRequest.setCurrentRequest(request)

        return sequenceRequest
    }
    
    static func delete(
        _ objects: [LCObject],
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let httpClient: HTTPClient = (objects.first?.application ?? .default).httpClient
        guard !objects.isEmpty else {
            return httpClient.request(object: .success, completionHandler: completion)
        }
        do {
            let requests = try objects.unique.map { object in
                try BatchRequest(object: object, method: .delete)
                    .jsonValue()
            }
            if requests.isEmpty {
                return httpClient.request(object: .success, completionHandler: completion)
            } else {
                return httpClient.request(
                    .post, "batch",
                    parameters: ["requests": requests])
                { response in
                    if let data = response.data,
                       let body = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                       body.count == 1,
                       let errorDictionary = body.first?["error"] as? [String: Any],
                       let code = errorDictionary["code"] as? Int,
                       let reason = errorDictionary["error"] as? String {
                        completion(LCBooleanResult(error: LCError(code: code, reason: reason)))
                    } else {
                        completion(LCBooleanResult(response: response))
                    }
                }
            }
        } catch {
            return httpClient.request(error: error, completionHandler: completion)
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
            ObjectProfiler.shared.updateObject(object, dictionary)
            object.discardChanges()
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
    
    static func fetch(
        _ objects: [LCObject],
        keys: [String]?,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let httpClient: HTTPClient = (objects.first?.application ?? .default).httpClient
        guard !objects.isEmpty else {
            return httpClient.request(object: .success, completionHandler: completion)
        }
        do {
            var keysParameters: [String: Any]?
            if let keys = keys {
                keysParameters = ["keys": keys.joined(separator: ",")]
            }
            let requests = try objects.unique.map { object in
                try BatchRequest(object: object, method: .get, parameters: keysParameters)
                    .jsonValue()
            }
            return httpClient.request(
                .post, "batch",
                parameters: ["requests": requests])
            { response in
                var result = LCBooleanResult(response: response)
                if case .success = result {
                    result = self.handleObjectFetchedResponse(response, objects)
                }
                completion(result)
            }
        } catch {
            return httpClient.request(error: error, completionHandler: completion)
        }
    }
}
