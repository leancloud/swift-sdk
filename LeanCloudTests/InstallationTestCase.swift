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

        installation.set(deviceToken: UUID().uuidString.replacingOccurrences(of: "-", with: ""), apnsTeamId: "LeanCloud")

        XCTAssertTrue(installation.save().isSuccess)

        let cachedInstallation = LCApplication.default.storageContextCache.installation

        XCTAssertFalse(installation === cachedInstallation)
        XCTAssertEqual(installation, cachedInstallation)
    }

}
