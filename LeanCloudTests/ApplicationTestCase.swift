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

    let anotherApplication = LCApplication(
        ID: "uay57kigwe0b6f5n0e1d4z4xhydsml3dor24bzwvzr57wdap",
        key: "kfgz7jjfsk55r5a8a3y4ttd3je1ko11bkibcikonk32oozww",
        region: .cn)

    func testObject() {
        let defaultApplication = LCApplication.default!

        let object = TestObject()

        /* By default, object will be bound to shared application. */
        XCTAssertTrue(object.application === LCApplication.default)

        let object1 = TestObject(application: defaultApplication)
        let object2 = TestObject(application: anotherApplication)

        /* Save objects individually will be OK. */
        XCTAssertTrue(object1.save().isSuccess)
        XCTAssertTrue(object2.save().isSuccess)

        let wildObject = TestObject(objectId: object2.objectId!)

        /* Fetch object from a wrong application will be failed. */
        XCTAssertFalse(wildObject.fetch().isSuccess)

        let object1Pointer = TestObject(objectId: object1.objectId!, application: defaultApplication)
        let object2Pointer = TestObject(objectId: object2.objectId!, application: anotherApplication)

        let objects = [object1Pointer, object2Pointer]

        /* Fetch objects from correct application will be OK. */
        XCTAssertTrue(LCObject.fetch(objects).isSuccess)

        /* Clean up objects. */
        XCTAssertTrue(LCObject.delete(objects).isSuccess)

        /* Fetch objects will be failed after clean-up */
        XCTAssertFalse(LCObject.fetch(objects).isSuccess)
    }

    func testRelation() {
        let foo = TestObject(application: anotherApplication)
        let bar = LCObject(application: anotherApplication)

        foo.insertRelation("relationField", object: bar)

        XCTAssertTrue(foo.save().isSuccess)

        guard let query = foo.relationField?.query else {
            XCTFail("Relation query not found.")
            return
        }

        XCTAssertTrue(query.application === anotherApplication)

        query.whereKey("objectId", .equalTo(bar.objectId!))

        let result = query.getFirst()

        XCTAssertTrue(result.isSuccess)

        guard let barCopy = result.object else {
            XCTFail("Relation query failed.")
            return
        }

        XCTAssertTrue(barCopy.application === anotherApplication)
        XCTAssertEqual(barCopy, bar)
    }

}
