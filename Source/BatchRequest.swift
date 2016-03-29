//
//  BatchRequest.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/22/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

class BatchRequest {
    let object: LCObject
    let operationTable: OperationTable

    /// REST API version
    static let APIVersion = "1.1"

    init(object: LCObject, operationTable: OperationTable) {
        self.object = object
        self.operationTable = operationTable
    }

    var isNew: Bool {
        return !object.hasObjectId
    }

    var method: String {
        return isNew ? "POST" : "PUT"
    }

    var path: String {
        return "/\(BatchRequest.APIVersion)/classes/\(object.dynamicType.className())"
    }

    var body: AnyObject {
        var body: [String: AnyObject] = [
            "__internalId": object.objectId ?? object.internalId
        ]

        var children: [(String, LCObject)] = []

        operationTable.forEach { (key, operation) in
            switch operation.name {
            case .Set:
                /* If object is newborn, put it in __children field. */
                if let child = operation.value as? LCObject {
                    if !child.hasObjectId {
                        children.append((key, child))
                        break
                    }
                }

                body[key] = operation.JSONValue()
            default:
                body[key] = operation.JSONValue()
            }
        }

        if children.count > 0 {
            var list: [AnyObject] = []

            children.forEach { (key, child) in
                list.append([
                    "className": child.dynamicType.className(),
                    "cid": child.internalId,
                    "key": key
                ])
            }

            body["__children"] = list
        }

        return body
    }

    func JSONValue() -> AnyObject {
        var request: [String: AnyObject] = [
            "path": path,
            "method": method,
            "body": body
        ]

        if isNew {
            request["new"] = true
        }

        return request
    }
}

class BatchRequestBuilder {
    /**
     Get a list of requests of an object.

     - parameter object: The object from which you want to get.

     - returns: A list of requests.
     */
    static func buildShallowRequests(object: LCObject) -> [BatchRequest] {
        return buildRequests(object, depth: 0)
    }

    /**
     Get a list of requests of an object and its descendant objects.

     - parameter object: The object from which you want to get.

     - returns: A list of requests.
     */
    static func buildDeepRequests(object: LCObject) -> [BatchRequest] {
        return buildRequests(object, depth: -1)
    }

    /**
     Get operation table list of object.

     - returns: A list of operation tables.
     */
    static func operationTableList(object: LCObject) -> OperationTableList {
        if object.hasObjectId {
            return object.operationHub.operationTableList()
        } else {
            var operationTable: OperationTable = [:]

            /* Collect all non-null properties. */
            ObjectProfiler.iterateProperties(object) { (key, value) in
                if let value = value {
                    operationTable[key] = Operation(name: .Set, key: key, value: value)
                }
            }

            return [operationTable]
        }
    }

    /**
     Get a list of requests of an object.

     - parameter object: The object from which you want to get.

     - returns: A list of request.
     */
    static func buildRequests(object: LCObject) -> [BatchRequest] {
        return operationTableList(object).map { BatchRequest(object: object, operationTable: $0) }
    }

    /**
     Get a list of requests of an object with depth option.

     - parameter object: The object from which you want to get.
     - parameter depth:  The depth of objects to deal with.

     - returns: A list of requests.
     */
    static func buildRequests(object: LCObject, depth: Int) -> [BatchRequest] {
        var result: [BatchRequest] = []

        ObjectProfiler.iterateObject(object, depth: depth) { (object) in
            let requests = buildRequests(object)

            if requests.count > 0 {
                result.appendContentsOf(requests)
            }
        }

        return result
    }
}