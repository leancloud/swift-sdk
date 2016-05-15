//
//  EngineTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 5/13/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
import LeanCloud

class EngineTestCase: BaseTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testOptionalResult() {
        XCTAssertTrue(Engine.call("echoSuccess").isSuccess)
        XCTAssertEqual(Engine.call("echoSuccess", parameters: ["foo": "bar"]).object, LCDictionary(["foo": LCString("bar")]))
    }

}
