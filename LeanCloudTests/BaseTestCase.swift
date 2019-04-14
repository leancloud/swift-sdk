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
        timeout: TimeInterval = 60.0,
        expectations: (() -> [XCTestExpectation])? = nil,
        closure: ([XCTestExpectation]) -> Void)
    {
        if let exps = expectations?() {
            closure(exps)
            wait(for: exps, timeout: timeout)
        } else {
            let exp = expectation(description: "default expectation")
            closure([exp])
            wait(for: [exp], timeout: timeout)
        }
    }

}
