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
    let application: LCApplication
    let response: Alamofire.DataResponse<Any, Error>

    init(application: LCApplication, response: Alamofire.DataResponse<Any, Error>) {
        self.application = application
        self.response = response
    }
    
    init(application: LCApplication, afDataResponse: AFDataResponse<Any>) {
        self.application = application
        let result: Result<Any, Error>
        switch afDataResponse.result {
        case let .success(v):
            result = .success(v)
        case let .failure(e):
            result = .failure(e)
        }
        self.response = DataResponse<Any, Error>(
            request: afDataResponse.request,
            response: afDataResponse.response,
            data: afDataResponse.data,
            metrics: afDataResponse.metrics,
            serializationDuration: afDataResponse.serializationDuration,
            result: result)
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

    var data: Data? {
        return response.data
    }

    var value: Any? {
        return response.value
    }

    subscript<T>(key: String) -> T? {
        guard let value = value as? [String: Any] else {
            return nil
        }
        return value[key] as? T
    }

    var results: [Any] {
        return self["results"] ?? []
    }

    var count: Int {
        return self["count"] ?? 0
    }
}
