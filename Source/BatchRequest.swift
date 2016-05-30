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
    let method: RESTClient.Method?
    let operationTable: OperationTable?

    init(object: LCObject, method: RESTClient.Method? = nil, operationTable: OperationTable? = nil) {
        self.object = object
        self.method = method
        self.operationTable = operationTable
    }

    var isNewborn: Bool {
        return !object.hasObjectId
    }

    var actualMethod: RESTClient.Method {
        return method ?? (isNewborn ? .POST : .PUT)
    }

    var path: String {
        var path: String
        let APIVersion = RESTClient.APIVersion

        switch actualMethod {
        case .GET, .PUT, .DELETE:
            path = RESTClient.eigenEndpoint(object)!
        case .POST:
            path = RESTClient.endpoint(object)
        }

        return "/\(APIVersion)/\(path)"
    }

    var body: AnyObject {
        var body: [String: AnyObject] = [
            "__internalId": object.objectId?.value ?? object.internalId
        ]

        var children: [(String, LCObject)] = []

        operationTable?.forEach { (key, operation) in
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
                    "className": child.actualClassName,
                    "cid": child.internalId,
                    "key": key
                ])
            }

            body["__children"] = list
        }

        return body
    }

    func JSONValue() -> AnyObject {
        let method = actualMethod

        var request: [String: AnyObject] = [
            "path": path,
            "method": method.rawValue
        ]

        switch method {
        case .GET:
            break
        case .POST, .PUT:
            request["body"] = body

            if isNewborn {
                request["new"] = true
            }
        case .DELETE:
            break
        }

        return request
    }
}

class BatchRequestBuilder {
    /**
     Get a list of requests of an object.

     - parameter object: The object from which you want to get.

     - returns: A list of request.
     */
    static func buildRequests(object: LCObject) -> [BatchRequest] {
        return operationTableList(object).map { element in
            BatchRequest(object: object, operationTable: element)
        }
    }

    /**
     Get initial operation table list of an object.

     - parameter object: The object from which to get.

     - returns: The operation table list.
     */
    private static func initialOperationTableList(object: LCObject) -> OperationTableList {
        var operationTable: OperationTable = [:]

        /* Collect all non-null properties. */
        object.forEach { (key, value) in
            switch value {
            case let relation as LCRelation:
                /* If the property type is relation,
                   We should use "AddRelation" instead of "Set" as operation type.
                   Otherwise, the relations will added as an array. */
                operationTable[key] = Operation(name: .AddRelation, key: key, value: LCArray(relation.value))
            default:
                operationTable[key] = Operation(name: .Set, key: key, value: value)
            }
        }

        return [operationTable]
    }

    /**
     Get operation table list of object.

     - parameter object: The object from which you want to get.

     - returns: A list of operation tables.
     */
    private static func operationTableList(object: LCObject) -> OperationTableList {
        if object.hasObjectId {
            return object.operationHub.operationTableList()
        } else {
            return initialOperationTableList(object)
        }
    }
}