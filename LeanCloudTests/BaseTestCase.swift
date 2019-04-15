//
//  BaseTestCase.swift
//  BaseTestCase
//
//  Created by Tang Tianyong on 2/22/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
import LeanCloud

class BaseTestCase: XCTestCase {
    
    static let timeout: TimeInterval = 60.0
    
    let timeout: TimeInterval = 60.0
    
    static var masterKey: String {
        if LCApplication.default.id == "S5vDI3IeCk1NLLiM1aFg3262-gzGzoHsz" {
            return "Q26gTodbyi1Ki7lM9vtncF6U,master"
        } else {
            XCTFail("default Application ID changed")
            return ""
        }
    }
    
    override func setUp() {
        super.setUp()

        LCApplication.default.logLevel = .all
        LCApplication.default.set(
            id: "S5vDI3IeCk1NLLiM1aFg3262-gzGzoHsz",
            key: "7g5pPsI55piz2PRLPWK5MPz0"
        )
        
        TestObject.register()
    }

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
    
    func resourceURL(name: String, ext: String) -> URL {
        let bundle = Bundle(for: type(of: self))
        return bundle.url(forResource: name, withExtension: ext)!
    }
    
    func expecting(
        description: String,
        expectation: (() -> XCTestExpectation)? = nil,
        closure: (XCTestExpectation) -> Void)
    {
        self.expecting(
            description: description,
            timeout: BaseTestCase.timeout,
            expectation: expectation,
            closure: closure
        )
    }
    
    func expecting(
        description: String? = nil,
        timeout: TimeInterval = BaseTestCase.timeout,
        expectation: (() -> XCTestExpectation)? = nil,
        closure: (XCTestExpectation) -> Void)
    {
        self.multiExpecting(timeout: timeout, expectations: {
            return [expectation?() ?? self.expectation(description: description ?? "default expectation")]
        }) {
            closure($0[0])
        }
    }
    
    func multiExpecting(
        timeout: TimeInterval = BaseTestCase.timeout,
        expectations: (() -> [XCTestExpectation]),
        closure: ([XCTestExpectation]) -> Void)
    {
        let exps = expectations()
        closure(exps)
        wait(for: exps, timeout: timeout)
    }

}
