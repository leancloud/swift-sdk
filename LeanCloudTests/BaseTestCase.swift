//
//  BaseTestCase.swift
//  BaseTestCase
//
//  Created by Tang Tianyong on 2/22/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

extension LCApplication {
    
    var masterKey: String {
        switch self.id {
        case "S5vDI3IeCk1NLLiM1aFg3262-gzGzoHsz":
            return "Q26gTodbyi1Ki7lM9vtncF6U,master"
        default:
            fatalError()
        }
    }
    
    var v2router: HTTPRouter {
        return HTTPRouter(
            application: self,
            configuration: HTTPRouter.Configuration(apiVersion: "1.2")
        )
    }
    
}

class BaseTestCase: XCTestCase {
    
    static let timeout: TimeInterval = 60.0
    
    let timeout: TimeInterval = 60.0
    
    override class func setUp() {
        super.setUp()

        TestObject.register()
        
        LCApplication.logLevel = .all
        
        try! LCApplication.default.set(
            id: "S5vDI3IeCk1NLLiM1aFg3262-gzGzoHsz",
            key: "7g5pPsI55piz2PRLPWK5MPz0"
        )
    }
    
    override class func tearDown() {
        let localDataURLs = [
            LCApplication.default.localStorageContext!.applicationSupportDirectoryPath,
            LCApplication.default.localStorageContext!.cachesDirectoryPath
        ]
        localDataURLs.forEach { (url) in
            if FileManager.default.fileExists(atPath: url.path) {
                try! FileManager.default.removeItem(at: url)
            }
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
        testcase: (XCTestExpectation) -> Void)
    {
        let exp = self.expectation(description: description ?? "default expectation")
        exp.expectedFulfillmentCount = expectedFulfillmentCount
        self.expecting(
            timeout: BaseTestCase.timeout,
            expectation: { exp },
            testcase: testcase
        )
    }
    
    func expecting(
        expectation: @escaping () -> XCTestExpectation,
        testcase: (XCTestExpectation) -> Void)
    {
        self.expecting(
            timeout: BaseTestCase.timeout,
            expectation: expectation,
            testcase: testcase
        )
    }
    
    func expecting(
        timeout: TimeInterval,
        expectation: (() -> XCTestExpectation),
        testcase: (XCTestExpectation) -> Void)
    {
        self.multiExpecting(
            timeout: timeout,
            expectations: { [expectation()] },
            testcase: { testcase($0[0]) }
        )
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
