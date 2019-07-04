//
//  LCCloudTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2019/7/4.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCCloudTestCase: BaseTestCase {
    
    func testCloudFunction() {
        XCTAssertEqual((LCCloud.run("test").value as? LCString)?.value, "test")
    }

}
