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
    
    func testError() {
        let result = LCEngine.run("error")
        XCTAssertNil(result.value)
        XCTAssertNotNil(LCEngine.run("error").error)
    }
}
