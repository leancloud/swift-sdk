//
//  LCRouterTestCase.swift
//  LeanCloudTests
//
//  Created by Tianyong Tang on 2018/9/7.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCRouterTestCase: BaseTestCase {
    
    static let usApplication = try! LCApplication(
        id: "Aexzfa0OETv4wzLpAb44E48Y-MdYXbMMI",
        key: "4u1YuP1Oz4AW2WScKb5RJN4f"
    )
    
    var appRouter: AppRouter {
        return LCRouterTestCase.usApplication.appRouter
    }
    
    func testModule() {
        XCTAssertEqual(appRouter.module("v1/route"), .rtm)
        XCTAssertEqual(appRouter.module("/v1/route"), .rtm)
        XCTAssertEqual(appRouter.module("push"), .push)
        XCTAssertEqual(appRouter.module("/push"), .push)
        XCTAssertEqual(appRouter.module("installations"), .push)
        XCTAssertEqual(appRouter.module("/installations"), .push)
        XCTAssertEqual(appRouter.module("call"), .engine)
        XCTAssertEqual(appRouter.module("/call"), .engine)
        XCTAssertEqual(appRouter.module("functions"), .engine)
        XCTAssertEqual(appRouter.module("/functions"), .engine)
        XCTAssertEqual(appRouter.module("user"), .api)
        XCTAssertEqual(appRouter.module("/user"), .api)
    }
    
    func testVersionizedPath() {
        XCTAssertEqual(
            appRouter.versionizedPath("foo"),
            "\(appRouter.configuration.apiVersion)/foo")
        XCTAssertEqual(
            appRouter.versionizedPath("/foo"),
            "\(appRouter.configuration.apiVersion)/foo")
    }
    
    func testAbsolutePath() {
        XCTAssertEqual(
            appRouter.absolutePath("foo"),
            "/foo")
        XCTAssertEqual(
            appRouter.absolutePath("/foo"),
            "/foo")
    }
    
    func testSchemingURL() {
        XCTAssertEqual(
            appRouter.schemingURL("example.com"),
            "https://example.com")
        XCTAssertEqual(
            appRouter.schemingURL("http://example.com"),
            "http://example.com")
        XCTAssertEqual(
            appRouter.schemingURL("https://example.com"),
            "https://example.com")
        XCTAssertEqual(
            appRouter.schemingURL("example.com:8000"),
            "https://example.com:8000")
        XCTAssertEqual(
            appRouter.schemingURL("http://example.com:8000"),
            "http://example.com:8000")
        XCTAssertEqual(
            appRouter.schemingURL("https://example.com:8000"),
            "https://example.com:8000")
    }
    
    func testAbsoluteURL() {
        XCTAssertEqual(
            appRouter.absoluteURL("example.com", path: "foo"),
            URL(string: "https://example.com/foo"))
        XCTAssertEqual(
            appRouter.absoluteURL("example.com/", path: "foo"),
            URL(string: "https://example.com/foo"))
        XCTAssertEqual(
            appRouter.absoluteURL("example.com/foo", path: "bar"),
            URL(string: "https://example.com/foo/bar"))
        XCTAssertEqual(
            appRouter.absoluteURL("example.com:8000", path: "foo"),
            URL(string: "https://example.com:8000/foo"))
        XCTAssertEqual(
            appRouter.absoluteURL("example.com:8000/", path: "foo"),
            URL(string: "https://example.com:8000/foo"))
        XCTAssertEqual(
            appRouter.absoluteURL("example.com:8000/foo", path: "bar"),
            URL(string: "https://example.com:8000/foo/bar"))
        
        XCTAssertEqual(
            appRouter.absoluteURL("https://example.com", path: "foo"),
            URL(string: "https://example.com/foo"))
        XCTAssertEqual(
            appRouter.absoluteURL("https://example.com/", path: "foo"),
            URL(string: "https://example.com/foo"))
        XCTAssertEqual(
            appRouter.absoluteURL("https://example.com/foo", path: "bar"),
            URL(string: "https://example.com/foo/bar"))
        XCTAssertEqual(
            appRouter.absoluteURL("https://example.com:8000", path: "foo"),
            URL(string: "https://example.com:8000/foo"))
        XCTAssertEqual(
            appRouter.absoluteURL("https://example.com:8000/", path: "foo"),
            URL(string: "https://example.com:8000/foo"))
        XCTAssertEqual(
            appRouter.absoluteURL("https://example.com:8000/foo", path: "bar"),
            URL(string: "https://example.com:8000/foo/bar"))
        
        XCTAssertEqual(
            appRouter.absoluteURL("http://example.com", path: "foo"),
            URL(string: "http://example.com/foo"))
        XCTAssertEqual(
            appRouter.absoluteURL("http://example.com/", path: "foo"),
            URL(string: "http://example.com/foo"))
        XCTAssertEqual(
            appRouter.absoluteURL("http://example.com/foo", path: "bar"),
            URL(string: "http://example.com/foo/bar"))
        XCTAssertEqual(
            appRouter.absoluteURL("http://example.com:8000", path: "foo"),
            URL(string: "http://example.com:8000/foo"))
        XCTAssertEqual(
            appRouter.absoluteURL("http://example.com:8000/", path: "foo"),
            URL(string: "http://example.com:8000/foo"))
        XCTAssertEqual(
            appRouter.absoluteURL("http://example.com:8000/foo", path: "bar"),
            URL(string: "http://example.com:8000/foo/bar"))
    }
    
    func testFallbackURL() {
        XCTAssertEqual(
            appRouter.fallbackURL(module: .api, path: "foo"),
            URL(string: "https://\("Aexzfa0O".lowercased()).api.lncldglobal.com/foo"))
        XCTAssertEqual(
            appRouter.fallbackURL(module: .api, path: "/foo"),
            URL(string: "https://\("Aexzfa0O".lowercased()).api.lncldglobal.com/foo"))
        XCTAssertEqual(
            appRouter.fallbackURL(module: .rtm, path: "foo"),
            URL(string: "https://\("Aexzfa0O".lowercased()).rtm.lncldglobal.com/foo"))
        XCTAssertEqual(
            appRouter.fallbackURL(module: .rtm, path: "/foo"),
            URL(string: "https://\("Aexzfa0O".lowercased()).rtm.lncldglobal.com/foo"))
        XCTAssertEqual(
            appRouter.fallbackURL(module: .push, path: "foo"),
            URL(string: "https://\("Aexzfa0O".lowercased()).push.lncldglobal.com/foo"))
        XCTAssertEqual(
            appRouter.fallbackURL(module: .push, path: "/foo"),
            URL(string: "https://\("Aexzfa0O".lowercased()).push.lncldglobal.com/foo"))
        XCTAssertEqual(
            appRouter.fallbackURL(module: .engine, path: "foo"),
            URL(string: "https://\("Aexzfa0O".lowercased()).engine.lncldglobal.com/foo"))
        XCTAssertEqual(
            appRouter.fallbackURL(module: .engine, path: "/foo"),
            URL(string: "https://\("Aexzfa0O".lowercased()).engine.lncldglobal.com/foo"))
    }
    
    func testCachedHost() {
        appRouter.cacheTable = nil
        XCTAssertNil(appRouter.cachedHost(module: .api))
        
        delay()
        
        XCTAssertNotNil(appRouter.cachedHost(module: .api))
        XCTAssertNotNil(appRouter.cachedHost(module: .push))
        XCTAssertNotNil(appRouter.cachedHost(module: .rtm))
        XCTAssertNotNil(appRouter.cachedHost(module: .engine))
        
        appRouter.cacheTable!.createdTimestamp =
            appRouter.cacheTable!.createdTimestamp! -
            appRouter.cacheTable!.ttl!
        XCTAssertNil(appRouter.cachedHost(module: .api))
    }
    
    func testGetAppRouter() {
        expecting { (exp) in
            appRouter.getAppRouter { (response) in
                XCTAssertTrue(response.isSuccess)
                exp.fulfill()
            }
        }
    }
    
    func testRequestAppRouter() {
        for i in 0...1 {
            if i == 1 {
                XCTAssertTrue(appRouter.isRequesting)
            }
            appRouter.requestAppRouter()
        }
        
        delay()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: appRouter.cacheFileURL!.path))
        try! LCRouterTestCase.usApplication.set(
            id: LCRouterTestCase.usApplication.id,
            key: LCRouterTestCase.usApplication.key)
        XCTAssertNotNil(appRouter.cacheTable)
    }
    
    func testBatchRequestPath() {
        XCTAssertEqual(
            appRouter.batchRequestPath("foo"),
            "/\(appRouter.configuration.apiVersion)/foo")
        XCTAssertEqual(
            appRouter.batchRequestPath("/foo"),
            "/\(appRouter.configuration.apiVersion)/foo")
    }

}
