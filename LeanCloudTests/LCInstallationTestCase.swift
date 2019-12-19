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
    
    func testSetDeviceTokenAndTeamID() {
        let installation = LCInstallation()
        let deviceToken = UUID().uuidString
        try! installation.set("deviceToken", value: deviceToken)
        try! installation.set("apnsTeamId", value: "LeanCloud")
        installation.badge = 0
        installation.channels = LCArray(["foo"])
        try! installation.append("channels", element: "bar", unique: true)
        XCTAssertTrue(installation.save().isSuccess)
        XCTAssertEqual(installation.deviceToken?.value, deviceToken)
        XCTAssertEqual(installation.apnsTeamId?.value, "LeanCloud")
        XCTAssertEqual(installation.badge, LCNumber(0))
        XCTAssertEqual(installation.channels, LCArray(["foo", "bar"]))
        XCTAssertNotNil(installation.timeZone)
        XCTAssertNotNil(installation.deviceType)
        XCTAssertNotNil(installation.apnsTopic)
        XCTAssertNotNil(installation.objectId)
        XCTAssertNotNil(installation.createdAt)
        
        let shadow = LCInstallation(objectId: installation.objectId!)
        XCTAssertTrue(shadow.fetch().isSuccess)
        XCTAssertEqual(installation.deviceToken, shadow.deviceToken)
        XCTAssertEqual(installation.apnsTeamId, shadow.apnsTeamId)
        XCTAssertEqual(installation.badge, shadow.badge)
        XCTAssertEqual(installation.channels, shadow.channels)
        XCTAssertEqual(installation.timeZone, shadow.timeZone)
        XCTAssertEqual(installation.deviceType, shadow.deviceType)
        XCTAssertEqual(installation.apnsTopic, shadow.apnsTopic)
        XCTAssertNotNil(shadow.objectId)
        XCTAssertNotNil(shadow.createdAt)
        XCTAssertNotNil(shadow.updatedAt)
    }
}
