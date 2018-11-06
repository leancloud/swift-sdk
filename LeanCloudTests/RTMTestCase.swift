//
//  RTMTestCase.swift
//  LeanCloudTests
//
//  Created by Tianyong Tang on 2018/11/6.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class RTMTestCase: BaseTestCase {

    func testRouter() {
        let application = LCApplication.default

        let router = RTMRouter(application: application)
        let routerCache = router.cache

        try! routerCache.clear()
        XCTAssertNil(try! routerCache.getRoutingTable())

        var result: LCGenericResult<RTMRoutingTable>!

        router.route { aResult in
            result = aResult
        }

        busywait { result != nil }

        switch result! {
        case .success(let routingTable):
            XCTAssertNotNil(routingTable.primary)
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }

        XCTAssertNotNil(try! routerCache.getRoutingTable())
    }

}
