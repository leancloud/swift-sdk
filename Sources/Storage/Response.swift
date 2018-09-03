//
//  Response.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/28/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation
import Alamofire

final class LCResponse {
    let response: Alamofire.DataResponse<Any>

    init(response: Alamofire.DataResponse<Any>) {
        self.response = response
    }

    var error: Error? {
        return response.error
    }

    /**
     A boolean property indicates whether response is OK or not.
     */
    var isSuccess: Bool {
        return error == nil
    }

    var value: AnyObject? {
        return response.result.value as AnyObject?
    }

    subscript<T>(key: String) -> T? {
        return value?[key] as? T
    }

    var results: [AnyObject] {
        return self["results"] ?? []
    }

    var count: Int {
        return self["count"] ?? 0
    }
}
