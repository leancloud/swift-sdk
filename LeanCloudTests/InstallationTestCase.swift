//
//  InstallationTestCase.swift
//  LeanCloudTests
//
//  Created by Tianyong Tang on 2018/10/17.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class InstallationTestCase: BaseTestCase {

    func testCurrentInstallation() {
        let installation = LCApplication.default.currentInstallation

        installation.deviceToken = "01010101010101010101010101"

        XCTAssertTrue(installation.save().isSuccess)

        let cachedInstallation = LCApplication.default.storageContextCache.installation

        XCTAssertFalse(installation === cachedInstallation)
        XCTAssertEqual(installation, cachedInstallation)
    }

}
