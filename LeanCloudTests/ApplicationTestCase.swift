//
//  ApplicationTestCase.swift
//  LeanCloudTests
//
//  Created by Tianyong Tang on 2018/6/27.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
import LeanCloud

class ApplicationTestCase: BaseTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testMultipleApplications() {
        let application1 = LCApplication.default
        let application2 = LCApplication()

        application1.logLevel = .all
        application2.logLevel = .all

        /* App name: "SDK Dev" */
        application2.identity = LCApplication.Identity(
            ID: "uay57kigwe0b6f5n0e1d4z4xhydsml3dor24bzwvzr57wdap",
            key: "kfgz7jjfsk55r5a8a3y4ttd3je1ko11bkibcikonk32oozww",
            region: .cn)

        let object = TestObject()

        /* By default, object will be bound to shared application. */
        XCTAssertTrue(object.application === LCApplication.default)

        let object1 = TestObject(application: application1)
        let object2 = TestObject(application: application2)

        /* Save objects individually will be OK. */
        XCTAssertTrue(object1.save().isSuccess)
        XCTAssertTrue(object2.save().isSuccess)

        let wildObject = TestObject(objectId: object2.objectId!)

        /* Fetch object from a wrong application will be failed. */
        XCTAssertFalse(wildObject.fetch().isSuccess)

        let object1Pointer = TestObject(objectId: object1.objectId!, application: application1)
        let object2Pointer = TestObject(objectId: object2.objectId!, application: application2)

        let objects = [object1Pointer, object2Pointer]

        /* Fetch objects from correct application will be OK. */
        XCTAssertTrue(LCObject.fetch(objects).isSuccess)

        /* Clean up objects. */
        XCTAssertTrue(LCObject.delete(objects).isSuccess)

        /* Fetch objects will be failed after clean-up */
        XCTAssertFalse(LCObject.fetch(objects).isSuccess)
    }

}
