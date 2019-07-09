//
//  LCEngineTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2019/7/4.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCEngineTestCase: BaseTestCase {
    
    func testEngineFunction() {
        XCTAssertEqual(LCEngine.run("test").value as? String, "test")
    }
    
    func testEngineRPC() {
        XCTAssertTrue(LCEngine.call("test").isSuccess)
    }

}
