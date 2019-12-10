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
    
    func testFunction() {
        let result = LCEngine.run("test")
        XCTAssertEqual(result.value as? String, "test")
        XCTAssertNil(result.error)
    }
    
    func testError() {
        let result = LCEngine.run("error")
        XCTAssertNil(result.value)
        XCTAssertNotNil(LCEngine.run("error").error)
    }
    
    func testGetOnOffStatus() {
        let result = LCEngine.run(
            "getOnOffStatus",
            parameters: ["peerIds":
                ["FCA6CAA7E5A14748BA25DE46EC1B66C8",
                 UUID().uuidString]])
        XCTAssertEqual((result.value as? [Any])?.count, 2)
        XCTAssertNil(result.error)
    }
}
