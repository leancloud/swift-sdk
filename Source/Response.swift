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

    /**
     A boolean property indicates whether response is OK or not.
     */
    public var isSuccess: Bool {
        if let response = alamofireResponse {
            /* TODO: Handle the business error. */
            return response.result.isSuccess
        } else {
            return true
        }
    }
}