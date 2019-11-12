//
//  LCApplicationTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2019/5/7.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCApplicationTestCase: BaseTestCase {
    
    func testRegistry() {
        XCTAssertTrue(LCApplication.registry[LCApplication.default.id] === LCApplication.default)
    }
    
    func testLogLevel() {
        Array<(LCApplication.LogLevel, LCApplication.LogLevel)>([
            (.all, .verbose),
            (.verbose, .debug),
            (.debug, .error),
            (.error, .off)
        ]).forEach { (left, right) in
            XCTAssertGreaterThan(left, right)
        }
    }
    
    func testBasic() {
        if [.cn, .ce].contains(LCApplication.default.region) {
            XCTAssertNotNil(LCApplication.default.id)
            XCTAssertNotNil(LCApplication.default.key)
            XCTAssertNotNil(LCApplication.default.serverURL)
        } else if [.us].contains(LCApplication.default.region) {
            XCTAssertNotNil(LCApplication.default.id)
            XCTAssertNotNil(LCApplication.default.key)
        }
    }
    
    func testServerCustomizableModule() {
        let host = "avoscloud.com"
        let config = LCApplication.Configuration(
            customizedServers: [
                .api(host),
                .push(host),
                .rtm(host),
                .engine(host)])
        let app = try! LCApplication(
            id: UUID().uuidString,
            key: UUID().uuidString,
            serverURL: "leancloud.cn",
            configuration: config)

        Array<AppRouter.Module>([.api, .push, .rtm, .engine]).forEach { (module) in
            if module == .rtm {
                XCTAssertEqual(
                    app.appRouter.route(path: "foo", module: module),
                    URL(string: "https://\(host)/foo"))
            } else {
                XCTAssertEqual(
                    app.appRouter.route(path: "foo", module: module),
                    URL(string: "https://\(host)/\(AppRouter.Configuration.default.apiVersion)/foo"))
            }
        }
        
        app.unregister()
    }
    
    func testEnvironment() {
        let config = LCApplication.Configuration(
            environment: [
                .cloudEngineDevelopment,
                .pushDevelopment])
        let app = try! LCApplication(
            id: UUID().uuidString,
            key: UUID().uuidString,
            serverURL: "leancloud.cn",
            configuration: config)
        
        XCTAssertEqual(app.cloudEngineMode, "0")
        XCTAssertEqual(app.pushMode, "dev")
        
        try! app.set(
            id: app.id,
            key: app.key,
            serverURL: app.serverURL,
            configuration: LCApplication.Configuration(
                environment: .default))
        
        XCTAssertEqual(app.cloudEngineMode, "1")
        XCTAssertEqual(app.pushMode, "prod")
        
        app.unregister()
    }
    
    func testRegion() {
        Array<(String, LCApplication.Region)>([
            (UUID().uuidString + "-gzGzoHsz", .cn),
            (UUID().uuidString.replacingOccurrences(of: "-", with: ""), .cn),
            (UUID().uuidString + "-9Nh9j0Va", .ce),
            (UUID().uuidString + "-MdYXbMMI", .us)
        ]).forEach { (id, region) in
            let app = try! LCApplication(
                id: id,
                key: UUID().uuidString,
                serverURL: "leancloud.cn")
            XCTAssertEqual(app.region, region)
            app.unregister()
        }
    }
    
    func testInit() {
        Array([
            UUID().uuidString + "-gzGzoHsz",
            UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            UUID().uuidString + "-9Nh9j0Va"
        ]).forEach { (id) in
            do {
                _ = try LCApplication(
                    id: id,
                    key: UUID().uuidString,
                    serverURL: nil)
                XCTFail()
            } catch {
                XCTAssertTrue(error is LCError)
            }
            do {
                let app = try LCApplication(
                    id: id,
                    key: UUID().uuidString,
                    serverURL: "leancloud.cn")
                Array<AppRouter.Module>([.api, .push, .rtm, .engine]).forEach { (module) in
                    if module == .rtm {
                        XCTAssertEqual(
                            app.appRouter.route(path: "foo", module: module),
                            URL(string: "https://leancloud.cn/foo"))
                    } else {
                        XCTAssertEqual(
                            app.appRouter.route(path: "foo", module: module),
                            URL(string: "https://leancloud.cn/\(AppRouter.Configuration.default.apiVersion)/foo"))
                    }
                }
                app.unregister()
            } catch {
                XCTFail("\(error)")
            }
        }
        
        do {
            let app = try LCApplication(
                id: UUID().uuidString + "-MdYXbMMI",
                key: UUID().uuidString)
            app.unregister()
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testDeinit() {
        let appID = UUID().uuidString
        var app: LCApplication! = try! LCApplication(
            id: appID,
            key: UUID().uuidString,
            serverURL: "https://leancloud.cn")
        XCTAssertTrue(LCApplication.registry[appID] === app)
        XCTAssertNotNil(app.localStorageContext)
        XCTAssertNotNil(app.httpClient)
        XCTAssertNotNil(app.appRouter)
        weak var wApp = app
        app.unregister()
        app = nil
        delay()
        XCTAssertNil(wApp)
    }
    
    func testCurrentInstallation() {
        let installation1 = LCApplication.default.currentInstallation
        installation1.set(
            deviceToken: UUID().uuidString,
            apnsTeamId: "LeanCloud")
        XCTAssertTrue(installation1.save().isSuccess)
        
        try! LCApplication.default.set(
            id: LCApplication.default.id,
            key: LCApplication.default.key,
            serverURL: LCApplication.default.serverURL)
        let installation2 = LCApplication.default.currentInstallation
        
        XCTAssertTrue(installation1 !== installation2)
        XCTAssertEqual(
            installation1.deviceToken?.value,
            installation2.deviceToken?.value)
        
        if let fileURL = LCApplication.default.currentInstallationFileURL,
            FileManager.default.fileExists(atPath: fileURL.path) {
            try! FileManager.default.removeItem(at: fileURL)
        }
    }

}
