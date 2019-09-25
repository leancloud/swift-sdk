//
//  LCAPITestCase.swift
//  LeanCloudTests
//
//  Created by Tianyong Tang on 2018/9/5.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCAPITestCase: BaseTestCase {

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

    func testCancelSingleRequest() {
        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()

        let request = LCApplication.default.httpClient.request(.get, "ping") { response in
            dispatchGroup.leave()
        }

        request.cancel() /* Cancel request immediately. */

        dispatchGroup.wait()
    }

    var newbornOrphanObservation: NSKeyValueObservation?

    func testCancelSequenceRequest() {
        let object = TestObject()

        let newbornOrphan1 = TestObject()
        let newbornOrphan2 = TestObject()

        newbornOrphan1.arrayField = [newbornOrphan2]

        object.arrayField = [newbornOrphan1]

        var result: LCBooleanResult?

        let request = object.save { aResult in
            result = aResult
        }

        newbornOrphanObservation = newbornOrphan2.observe(\.objectId) { (_, change) in
            request.cancel()
        }

        busywait { result != nil }

        XCTAssertFalse(result!.isSuccess)
    }

}
