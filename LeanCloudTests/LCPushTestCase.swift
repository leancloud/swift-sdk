//
//  LCPushTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2019/7/9.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCPushTestCase: BaseTestCase {
    
    func testSend() {
        let data = ["alert": "test"]
        
        XCTAssertTrue(LCPush.send(data: data).isSuccess)
    }
    
    func testSendWithQuery() {
        let data = ["alert": "test"]
        
        let query = LCQuery(className: LCInstallation.objectClassName())
        query.whereKey("deviceType", .equalTo("ios"))
        
        XCTAssertTrue(LCPush.send(data: data, query: query).isSuccess)
    }
    
    func testSendWithChannels() {
        let data = ["alert": "test"]
        
        let channels = ["test"]
        
        XCTAssertTrue(LCPush.send(data: data, channels: channels).isSuccess)
    }
    
    func testSendWithPushDate() {
        let data = ["alert": "test"]
        
        let pushDate = Date(timeIntervalSinceNow: 5)
        
        XCTAssertTrue(LCPush.send(data: data, pushDate: pushDate).isSuccess)
    }
    
    func testSendWithExpirationDate() {
        let data = ["alert": "test"]
        
        let expirationDate = Date(timeIntervalSinceNow: 5)
        
        XCTAssertTrue(LCPush.send(data: data, expirationDate: expirationDate).isSuccess)
    }
    
    func testSendWithExpirationInterval() {
        let data = ["alert": "test"]
        
        XCTAssertTrue(LCPush.send(data: data, expirationInterval: 5).isSuccess)
    }

}
