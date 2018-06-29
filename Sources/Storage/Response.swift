//
//  Response.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/28/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation
import Alamofire

open class LCResponse {
    /// Internal error.
    /// It will override alamofire's response error.
    private var internalError: LCError?
    private var alamofireResponse: Alamofire.DataResponse<Any>?

    var application: LCApplication?

    private var subresponses: [LCResponse] = []

    init() {}

    init(_ error: LCError) {
        internalError = error
    }

    init(_ alamofireResponse: Alamofire.DataResponse<Any>?, _ application: LCApplication) {
        self.alamofireResponse = alamofireResponse
        self.application = application
    }

    init(_ subresponses: [LCResponse]) {
        self.subresponses = subresponses
    }

    var value: AnyObject? {
        return alamofireResponse?.result.value as AnyObject?
    }

    var error: LCError? {
        var result: LCError?

        /* There are 2 kinds of error:
           1. Internal error.
           2. Network error. */

        if let error = internalError {
            result = error
        } else if let response = alamofireResponse {
            if let error = response.result.error {
                result = LCError(error: error)
            }
        } else {
            for response in subresponses {
                /* Find the first error by DFS. */
                if let error = response.error {
                    result = error
                    break
                }
            }
        }

        return result
    }

    open subscript(key: String) -> AnyObject? {
        return value?[key] as AnyObject?
    }

    /**
     A boolean property indicates whether response is OK or not.
     */
    open var isSuccess: Bool {
        return error == nil
    }
}

extension LCResponse {
    var count: Int {
        return (self["count"] as? Int) ?? 0
    }

    var results: [AnyObject] {
        return (self["results"] as? [AnyObject]) ?? []
    }
}
