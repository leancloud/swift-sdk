//
//  Response.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/28/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation
import Alamofire

public class LCResponse {
    /// Internal error.
    /// It will override alamofire's response error.
    private var internalError: LCError?
    private var alamofireResponse: Alamofire.Response<AnyObject, NSError>?

    init() {}

    init(_ error: LCError) {
        internalError = error
    }

    init(_ alamofireResponse: Alamofire.Response<AnyObject, NSError>) {
        self.alamofireResponse = alamofireResponse
    }

    var value: AnyObject? {
        return alamofireResponse?.result.value
    }

    var error: LCError? {
        var result: LCError?

        /* There are 3 kinds of errors:
           1. Internal error.
           2. Network error.
           3. Business error. */

        if let error = internalError {
            result = error
        } else if let response = alamofireResponse {
            if let error = response.result.error {
                result = LCError(error: error)
            } else {
                result = ObjectProfiler.error(JSONValue: value)
            }
        }

        return result
    }

    public subscript(key: String) -> AnyObject? {
        return value?[key]
    }

    /**
     A boolean property indicates whether response is OK or not.
     */
    public var isSuccess: Bool {
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