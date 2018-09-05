//
//  APITestCase.swift
//  LeanCloudTests
//
//  Created by Tianyong Tang on 2018/9/5.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class APITestCase: BaseTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testUrlEncoding() {
        XCTAssertEqual("foo bar".urlPathEncoded, "foo%20bar")
        XCTAssertEqual("+8610000000".urlQueryEncoded, "%2B8610000000")
    }

}
