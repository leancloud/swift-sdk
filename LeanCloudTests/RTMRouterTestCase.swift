//
//  RTMRouterTestCase.swift
//  LeanCloudTests
//
//  Created by Tianyong Tang on 2018/11/6.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class RTMRouterTestCase: RTMBaseTestCase {
    
    func test() {
        
        let router = try! RTMRouter(application: .default)
        let fileURL = router.tableCacheURL!
        
        XCTAssertTrue(fileURL.path.contains("Library/Caches"))
        XCTAssertTrue(fileURL.path.contains(LocalStorageContext.Module.router.path))
        XCTAssertTrue(fileURL.path.contains(LocalStorageContext.File.rtmServer.name))
        
        router.clearTableCache()
        
        XCTAssertNil(router.table)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        
        let date = Date()
        
        let exp = expectation(description: "routing")
        router.route { (direct, result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertFalse(direct)
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
        
        XCTAssertNotNil(router.table)
        XCTAssertNotNil(router.table?.secondary)
        XCTAssertEqual(router.table?.primary, router.table?.primaryURL?.absoluteString)
        XCTAssertEqual(router.table?.secondary, router.table?.secondaryURL?.absoluteString)
        XCTAssertTrue((router.table?.ttl ?? 0) > 0)
        XCTAssertEqual(router.table?.continuousFailureCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertGreaterThan(router.table?.createdTimestamp ?? 0, date.timeIntervalSince1970)
        XCTAssertEqual(router.table?.isExpired, false)
        
        router.updateFailureCount()
        XCTAssertEqual(router.table?.continuousFailureCount, 1)
        router.updateFailureCount(reset: true)
        XCTAssertEqual(router.table?.continuousFailureCount, 0)
        for _ in 0..<10 {
            router.updateFailureCount()
        }
        XCTAssertEqual(router.table?.shouldClear, true)
    }

}
