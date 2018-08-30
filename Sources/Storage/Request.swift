//
//  Request.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/30/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation
import Alamofire

public final class LCRequest {
    let alamofireRequest: Alamofire.Request

    init(_ alamofireRequest: Alamofire.Request) {
        self.alamofireRequest = alamofireRequest
    }

    public func resume() {
        alamofireRequest.resume()
    }

    public func suspend() {
        alamofireRequest.suspend()
    }

    public func cancel() {
        alamofireRequest.cancel()
    }
}
