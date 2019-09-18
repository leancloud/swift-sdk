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

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    static let cnApplication       = LCApplication.default
    static let ceApplication       = try! LCApplication(id: "uwWkfssEBRtrxVpQWEnFtqfr-9Nh9j0Va", key: "9OaLpoW21lIQtRYzJya4WHUR")
    static let usApplication       = try! LCApplication(id: "eX7urCufwLd6X5mHxt7V12nL-MdYXbMMI", key: "PrmzHPnRXjXezS54KryuHMG6")
    static let earlyCnApplication  = try! LCApplication(id: "uay57kigwe0b6f5n0e1d4z4xhydsml3dor24bzwvzr57wdap", key: "kfgz7jjfsk55r5a8a3y4ttd3je1ko11bkibcikonk32oozww")

    lazy var cnRouter       = AppRouter(application: LCRouterTestCase.cnApplication, configuration: .default)
    lazy var ceRouter       = AppRouter(application: LCRouterTestCase.ceApplication, configuration: .default)
    lazy var usRouter       = AppRouter(application: LCRouterTestCase.usApplication, configuration: .default)
    lazy var earlyCnRouter  = AppRouter(application: LCRouterTestCase.earlyCnApplication, configuration: .default)

    func testAbsoluteUrl() {
        XCTAssertEqual(
            cnRouter.absoluteUrl(host: "example.com", path: "foo"),
            URL(string: "https://example.com/foo"))
        XCTAssertEqual(
            cnRouter.absoluteUrl(host: "example.com:8000", path: "foo"),
            URL(string: "https://example.com:8000/foo"))
        XCTAssertEqual(
            cnRouter.absoluteUrl(host: "https://example.com", path: "foo"),
            URL(string: "https://example.com/foo"))
        XCTAssertEqual(
            cnRouter.absoluteUrl(host: "hello://example.com", path: "foo"),
            URL(string: "hello://example.com/foo"))
        XCTAssertEqual(
            cnRouter.absoluteUrl(host: "https://example.com:8000", path: "foo"),
            URL(string: "https://example.com:8000/foo"))
        XCTAssertEqual(
            cnRouter.absoluteUrl(host: "https://example.com:8000/", path: "foo"),
            URL(string: "https://example.com:8000/foo"))
        XCTAssertEqual(
            cnRouter.absoluteUrl(host: "https://example.com:8000", path: "/foo"),
            URL(string: "https://example.com:8000/foo"))
        XCTAssertEqual(
            cnRouter.absoluteUrl(host: "https://example.com:8000/", path: "/foo"),
            URL(string: "https://example.com:8000/foo"))
        XCTAssertEqual(
            cnRouter.absoluteUrl(host: "https://example.com:8000/foo", path: "bar"),
            URL(string: "https://example.com:8000/foo/bar"))
    }

    func testFallbackUrl() {
        for item in
            [AppRouter.Module.api,
             AppRouter.Module.engine,
             AppRouter.Module.push,
             AppRouter.Module.rtm,
             AppRouter.Module.stats]
        {
            switch item {
            case .api:
                XCTAssertEqual("\(item)", "api")
            case .engine:
                XCTAssertEqual("\(item)", "engine")
            case .push:
                XCTAssertEqual("\(item)", "push")
            case .rtm:
                XCTAssertEqual("\(item)", "rtm")
            case .stats:
                XCTAssertEqual("\(item)", "stats")
            }
            XCTAssertEqual(
                cnRouter.fallbackUrl(path: "1.1/foo", module: item),
                URL(string: "https://s5vdi3ie.\(item).lncld.net/1.1/foo"))
            XCTAssertEqual(
                ceRouter.fallbackUrl(path: "1.1/foo", module: item),
                URL(string: "https://uwwkfsse.\(item).lncldapi.com/1.1/foo"))
            XCTAssertEqual(
                usRouter.fallbackUrl(path: "1.1/foo", module: item),
                URL(string: "https://ex7urcuf.\(item).lncldglobal.com/1.1/foo"))
            XCTAssertEqual(
                earlyCnRouter.fallbackUrl(path: "1.1/foo", module: item),
                URL(string: "https://uay57kig.\(item).lncld.net/1.1/foo"))
        }
    }

    func testAppRouterThrottle() {
        var requestSet = Set<LCRequest>()
        var resultArray: [LCBooleanResult] = []

        let dispatchGroup = DispatchGroup()

        for _ in 0..<100 {
            dispatchGroup.enter()
            let request = cnRouter.requestAppRouter { result in
                synchronize(on: resultArray) {
                    resultArray.append(result)
                }
                dispatchGroup.leave()
            }
            requestSet.insert(request)
        }

        dispatchGroup.wait()

        XCTAssertEqual(resultArray.count, 100)
        XCTAssertEqual(requestSet.count, 1)
    }

}
