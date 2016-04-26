//
//  Response.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/28/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation
import Alamofire

public class Response {
    let alamofireResponse: Alamofire.Response<AnyObject, NSError>?

    init() {
        alamofireResponse = nil
    }

    init(_ alamofireResponse: Alamofire.Response<AnyObject, NSError>) {
        self.alamofireResponse = alamofireResponse
    }

    var value: AnyObject? {
        return alamofireResponse?.result.value
    }

    var error: Error? {
        var result: Error?

        if let response = alamofireResponse {
            if let error = response.result.error {
                result = Error(error: error)
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

extension Response {
    var count: Int {
        return (self["count"] as? Int) ?? 0
    }
}