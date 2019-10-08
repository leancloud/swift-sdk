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
        let fileURL = LCApplication.default.currentInstallationFileURL!
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try! FileManager.default.removeItem(at: fileURL)
        }
        
        let installation = LCInstallation()
        installation.set(
            deviceToken: UUID().uuidString,
            apnsTeamId: "LeanCloud")
        XCTAssertTrue(installation.save().isSuccess)
        
        XCTAssertNil(LCInstallation.currentInstallation(application: .default))
        LCInstallation.saveCurrentInstallation(installation)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        let currentInstallation = LCInstallation.currentInstallation(application: .default)
        XCTAssertEqual(
            currentInstallation?.objectId?.value,
            installation.objectId?.value)
        XCTAssertEqual(
            currentInstallation?.deviceToken?.value,
            installation.deviceToken?.value)
        XCTAssertEqual(
            currentInstallation?.apnsTeamId?.value,
            installation.apnsTeamId?.value)
        XCTAssertEqual(
            currentInstallation?.apnsTopic?.value,
            installation.apnsTopic?.value)
        XCTAssertEqual(
            currentInstallation?.deviceType?.value,
            installation.deviceType?.value)
        XCTAssertEqual(
            currentInstallation?.timeZone?.value,
            installation.timeZone?.value)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try! FileManager.default.removeItem(at: fileURL)
        }
    }

}
