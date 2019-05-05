//
//  LCInstallationTestCase.swift
//  LeanCloudTests
//
//  Created by Tianyong Tang on 2018/10/17.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCInstallationTestCase: BaseTestCase {

    func testCurrentInstallation() {
        let installation = LCApplication.default.currentInstallation
        
        installation.set(deviceToken: UUID().uuidString.replacingOccurrences(of: "-", with: ""), apnsTeamId: "LeanCloud")
        
        XCTAssertTrue(installation.hasDataToUpload)

        XCTAssertTrue(installation.save().isSuccess)
        
        XCTAssertFalse(installation.hasDataToUpload)
        
        try? installation.append("channels", element: "test", unique: true)
        
        XCTAssertTrue(installation.hasDataToUpload)
        
        XCTAssertTrue(installation.save().isSuccess)
        
        XCTAssertFalse(installation.hasDataToUpload)
    }

}
