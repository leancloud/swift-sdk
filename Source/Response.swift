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
    let alamofireResponse: Alamofire.Response<AnyObject, NSError>

    init(_ alamofireResponse: Alamofire.Response<AnyObject, NSError>) {
        self.alamofireResponse = alamofireResponse
    }
}