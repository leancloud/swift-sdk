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
    /**
     Send a list of batch requests synchronously.

     - parameter requests: A list of batch requests.
     - returns: The response of request.
     */
    private static func sendBatchRequests(requests: [BatchRequest]) -> Response {
        let parameters = [
            "requests": requests.map { request in request.JSONValue() }
        ]

        return RESTClient.request(.POST, "batch/save", parameters: parameters)
    }

    /**
     Save independent objects in one batch request synchronously.

     - parameter objects: A set of independent objects to save.
     - returns: The response of request.
     */
    private static func saveIndependentObjects(objects: Set<LCObject>) -> Response {
        var requests: [BatchRequest] = []

        objects.forEach { object in
            requests.appendContentsOf(BatchRequestBuilder.buildShallowRequests(object))
        }

        let response = sendBatchRequests(requests)

        if response.isSuccess {
            /* TODO: Copy response data to objects. */
        }

        return response
    }

    /**
     Save all descendant newborn orphans.

     The detail save process is described as follows:

     1. Save deepest newborn orphan objects in one batch request.
     2. Repeat step 1 until all descendant newborn objects saved.

     - parameter object: The root object.
     - returns: The response of request.
     */
    private static func saveNewbornOrphanObjects(object: LCObject) -> Response {
        var response = Response()

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

     - returns: The response of request.
     */
    static func save(object: LCObject) -> Response {
        var response = saveNewbornOrphanObjects(object)

        guard response.isSuccess else {
            return response
        }

        /* Now, all newborn orphan objects should saved. We can save the object family safely. */

        let requests = BatchRequestBuilder.buildDeepRequests(object)

        response = sendBatchRequests(requests)

        if response.isSuccess {
            /* TODO: Copy response data to objects. */
        }

        return response
    }
}