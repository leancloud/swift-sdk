//
//  BaseTestCase.swift
//  BaseTestCase
//
//  Created by Tang Tianyong on 2/22/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class TestObject: LCObject {
    @objc dynamic var numberField: LCNumber?
    @objc dynamic var booleanField: LCBool?
    @objc dynamic var stringField: LCString?
    @objc dynamic var arrayField: LCArray?
    @objc dynamic var dictionaryField: LCDictionary?
    @objc dynamic var objectField: LCObject?
    @objc dynamic var relationField: LCRelation?
    @objc dynamic var geoPointField: LCGeoPoint?
    @objc dynamic var dataField: LCData?
    @objc dynamic var dateField: LCDate?
    @objc dynamic var nullField: LCNull?
    @objc dynamic var fileField: LCFile?
}

class BaseTestCase: XCTestCase {
    
    let timeout: TimeInterval = 60.0
    
    override func setUp() {
        super.setUp()

        TestObject.register()

        LCApplication.default.logLevel = .all
        LCApplication.default.set(
            id: "S5vDI3IeCk1NLLiM1aFg3262-gzGzoHsz",
            key: "7g5pPsI55piz2PRLPWK5MPz0"
        )
    }

    func busywait(interval: TimeInterval = 0.1, untilTrue: () -> Bool) -> Void {
        while !untilTrue() {
            let due = Date(timeIntervalSinceNow: interval)
            RunLoop.current.run(mode: .default, before: due)
        }
    }

}
