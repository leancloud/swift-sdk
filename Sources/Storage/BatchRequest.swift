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
        return method ?? (isNewborn ? .post : .put)
    }

    var path: String {
        var path: String
        let apiVersion = RESTClient.apiVersion

        switch actualMethod {
        case .get, .put, .delete:
            path = RESTClient.eigenEndpoint(object)!
        case .post:
            path = RESTClient.endpoint(object)
        }

        return "/\(apiVersion)/\(path)"
    }

    var body: AnyObject {
        var body: [String: AnyObject] = [
            "__internalId": object.objectId?.value as AnyObject? ?? object.internalId as AnyObject
        ]

        var children: [(String, LCObject)] = []

        operationTable?.forEach { (key, operation) in
            switch operation.name {
            case .set:
                /* If object is newborn, put it in __children field. */
                if let child = operation.value as? LCObject {
                    if !child.hasObjectId {
                        children.append((key, child))
                        break
                    }
                }

                body[key] = operation.lconValue
            default:
                body[key] = operation.lconValue
            }
        }

        if children.count > 0 {
            var list: [AnyObject] = []

            children.forEach { (key, child) in
                list.append([
                    "className": child.actualClassName,
                    "cid": child.internalId,
                    "key": key
                ] as AnyObject)
            }

            body["__children"] = list as AnyObject?
        }

        return body as AnyObject
    }

    func jsonValue() -> AnyObject {
        let method = actualMethod

        var request: [String: AnyObject] = [
            "path": path as AnyObject,
            "method": method.rawValue as AnyObject
        ]

        switch method {
        case .get:
            break
        case .post, .put:
            request["body"] = body

            if isNewborn {
                request["new"] = true as AnyObject?
            }
        case .delete:
            break
        }

        return request as AnyObject
    }
}

class BatchRequestBuilder {
    /**
     Get a list of requests of an object.

     - parameter object: The object from which you want to get.

     - returns: A list of request.
     */
    static func buildRequests(_ object: LCObject) -> [BatchRequest] {
        return operationTableList(object).map { element in
            BatchRequest(object: object, operationTable: element)
        }
    }

    /**
     Get initial operation table list of an object.

     - parameter object: The object from which to get.

     - returns: The operation table list.
     */
    fileprivate static func initialOperationTableList(_ object: LCObject) -> OperationTableList {
        var operationTable: OperationTable = [:]

        /* Collect all non-null properties. */
        object.forEach { (key, value) in
            switch value {
            case let relation as LCRelation:
                /* If the property type is relation,
                   We should use "AddRelation" instead of "Set" as operation type.
                   Otherwise, the relations will added as an array. */
                operationTable[key] = Operation(name: .addRelation, key: key, value: LCArray(relation.value))
            default:
                operationTable[key] = Operation(name: .set, key: key, value: value)
            }
        }

        return [operationTable]
    }

    /**
     Get operation table list of object.

     - parameter object: The object from which you want to get.

     - returns: A list of operation tables.
     */
    fileprivate static func operationTableList(_ object: LCObject) -> OperationTableList {
        if object.hasObjectId {
            return object.operationHub.operationTableList()
        } else {
            return initialOperationTableList(object)
        }
    }
}
