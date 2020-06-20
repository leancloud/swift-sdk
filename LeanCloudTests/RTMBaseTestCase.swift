//
//  RTMBaseTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2019/1/21.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class RTMBaseTestCase: BaseTestCase {
    
    static let useTestableRTMURL = false
    static let testableRTMURL = RTMBaseTestCase.useTestableRTMURL
        ? URL(string: "wss://cn-n1-core-k8s-cell-12.leancloud.cn")!
        : nil
}
