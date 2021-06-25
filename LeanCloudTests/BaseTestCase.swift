//
//  BaseTestCase.swift
//  BaseTestCase
//
//  Created by Tang Tianyong on 2/22/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class BaseTestCase: XCTestCase {
    
    static let timeout: TimeInterval = 60.0
    let timeout: TimeInterval = 60.0
    
    static var uuid: String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    var uuid: String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    struct AppInfo {
        let id: String
        let key: String
        let serverURL: String
        let testableServerURL: String
    }
    
    static let cnApp = AppInfo(
        id: "S5vDI3IeCk1NLLiM1aFg3262-gzGzoHsz",
        key: "7g5pPsI55piz2PRLPWK5MPz0",
        serverURL: "https://s5vdi3ie.lc-cn-n1-shared.com",
        testableServerURL: "https://beta.leancloud.cn")
    
    static let ceApp = AppInfo(
        id: "skhiVsqIk7NLVdtHaUiWn0No-9Nh9j0Va",
        key: "T3TEAIcL8Ls5XGPsGz41B1bz",
        serverURL: "https://skhivsqi.lc-cn-e1-shared.com",
        testableServerURL: "https://beta-tab.leancloud.cn")
    
    static let usApp = AppInfo(
        id: "jenSt9nvWtuJtmurdE28eg5M-MdYXbMMI",
        key: "8VLPsDlskJi8KsKppED4xKS0",
        serverURL: "",
        testableServerURL: "https://beta-us.leancloud.cn")
    
    static var config: LCApplication.Configuration {
        var config = LCApplication.Configuration()
        if let serverURL = RTMBaseTestCase.testableRTMURL {
            config.RTMCustomServerURL = serverURL
        }
        config.isObjectRawDataAtomic = true
        return config
    }
    
    override class func setUp() {
        super.setUp()
        let app = BaseTestCase.cnApp
//        let app = BaseTestCase.ceApp
//        let app = BaseTestCase.usApp
        TestObject.register()
        LCApplication.logLevel = .all
        try! LCApplication.default.set(
            id: app.id,
            key: app.key,
            serverURL: app.serverURL.isEmpty ? nil : app.serverURL,
//            serverURL: app.testableServerURL,
            configuration: BaseTestCase.config)
    }
    
    override class func tearDown() {
        [LCApplication.default.applicationSupportDirectoryURL,
         LCApplication.default.cachesDirectoryURL]
            .forEach { (url) in
                if FileManager.default.fileExists(atPath: url.path) {
                    try! FileManager.default.removeItem(at: url)
                }
        }
        LCApplication.default.unregister()
        super.tearDown()
    }
}

extension BaseTestCase {
    
    var className: String {
        return "\(type(of: self))"
    }
    
    func object(_ objectId: LCStringConvertible? = nil) -> LCObject {
        if let objectId = objectId {
            return LCObject(
                className: self.className,
                objectId: objectId)
        } else {
            return LCObject(
                className: self.className)
        }
    }
}

extension BaseTestCase {
    
    func busywait(interval: TimeInterval = 0.1, untilTrue: () -> Bool) -> Void {
        while !untilTrue() {
            let due = Date(timeIntervalSinceNow: interval)
            RunLoop.current.run(mode: .default, before: due)
        }
    }
    
    func delay(seconds: TimeInterval = 3.0) {
        print("\n------\nwait \(seconds) seconds.\n------\n")
        let exp = expectation(description: "delay \(seconds) seconds.")
        exp.isInverted = true
        wait(for: [exp], timeout: seconds)
    }
}

extension BaseTestCase {
    
    func bundleResourceURL(name: String, ext: String) -> URL {
        return Bundle(for: type(of: self))
            .url(forResource: name, withExtension: ext)!
    }
}

extension BaseTestCase {
    
    func expecting(
        description: String? = nil,
        count expectedFulfillmentCount: Int = 1,
        timeout: TimeInterval = BaseTestCase.timeout,
        testcase: (XCTestExpectation) -> Void)
    {
        let exp = self.expectation(description: description ?? "default expectation")
        exp.expectedFulfillmentCount = expectedFulfillmentCount
        self.expecting(
            timeout: timeout,
            expectation: { exp },
            testcase: testcase)
    }
    
    func expecting(
        timeout: TimeInterval = BaseTestCase.timeout,
        expectation: () -> XCTestExpectation,
        testcase: (XCTestExpectation) -> Void)
    {
        self.multiExpecting(
            timeout: timeout,
            expectations: { [expectation()] },
            testcase: { testcase($0[0]) })
    }
    
    func multiExpecting(
        timeout: TimeInterval = BaseTestCase.timeout,
        expectations: (() -> [XCTestExpectation]),
        testcase: ([XCTestExpectation]) -> Void)
    {
        let exps = expectations()
        testcase(exps)
        wait(for: exps, timeout: timeout)
    }
}

extension LCApplication {
    
    var masterKey: String {
        let key: String
        switch self.id {
        case BaseTestCase.cnApp.id:
            key = "Q26gTodbyi1Ki7lM9vtncF6U"
        case BaseTestCase.ceApp.id:
            key = "FTPdEcG7vLKxNqKxYhTFdK4g"
        case BaseTestCase.usApp.id:
            key = "fasiJXz8jvSwn3G2B2QeraRe"
        default:
            fatalError()
        }
        return key + ",master"
    }
    
    var v2router: AppRouter {
        return AppRouter(
            application: self,
            configuration: AppRouter.Configuration(apiVersion: "1.2"))
    }
    
    var applicationSupportDirectoryURL: URL {
        return (try!
            FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false))
            .appendingPathComponent(
                LocalStorageContext.domain,
                isDirectory: true)
            .appendingPathComponent(
                self.id.md5.lowercased(),
                isDirectory: true)
    }
    
    var cachesDirectoryURL: URL {
        return (try!
            FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false))
            .appendingPathComponent(
                LocalStorageContext.domain,
                isDirectory: true)
            .appendingPathComponent(
                self.id.md5.lowercased(),
                isDirectory: true)
    }
}
