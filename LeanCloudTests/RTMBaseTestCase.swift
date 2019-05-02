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
    
    let testableRTMURL: URL = URL(string: "wss://rtm51.leancloud.cn")!
    
    var uuid: String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    static var uuid: String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        try! FileManager.default.removeItem(at: LCApplication.default.localStorageContext!.applicationSupportDirectoryPath)
        try! FileManager.default.removeItem(at: LCApplication.default.localStorageContext!.cachesDirectoryPath)
        super.tearDown()
    }

}
