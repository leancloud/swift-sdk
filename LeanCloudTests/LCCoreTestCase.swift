//
//  LCCoreTestCase.swift
//  LeanCloudTests
//
//  Created by Tianyong Tang on 2018/9/26.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCCoreTestCase: BaseTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSequenceUnique() {
        let object1 = TestObject()
        let object2 = TestObject()
        let object3 = TestObject()

        XCTAssertEqual(
            [object1, object3, object2, object1].unique,
            [object1, object3, object2])

        XCTAssertEqual(
            [1, 3, 2, 1].unique,
            [1, 3, 2])
    }
    
}
