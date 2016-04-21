//
//  QueryTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/20/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

let sharedObject: TestObject = {
    let object = TestObject()

    object.stringField = "foo"
    object.booleanField = true
    object.numberField  = 42

    XCTAssertTrue(object.save().isSuccess)

    return object
}()

class QueryTestCase: BaseTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testIncluded() {
        let object = sharedObject
        let child  = TestObject()

        object.objectField = child
        child.stringField = "bar"

        XCTAssertTrue(object.save().isSuccess)

        let query = Query(className: TestObject.className())
        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("objectField", .Included)

        let (response, objects) = query.find()
        XCTAssertTrue(response.isSuccess && !objects.isEmpty)

        if let child = (objects.first as? TestObject)?.objectField as? TestObject {
            XCTAssertEqual(child.stringField, "bar")
        } else {
            XCTFail()
        }
    }

    func testSelected() {
        let object = sharedObject

        let query = Query(className: TestObject.className())
        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("stringField", .Selected)
        query.whereKey("booleanField", .Selected)

        let (response, objects) = query.find()
        XCTAssertTrue(response.isSuccess && !objects.isEmpty)

        let shadow = objects.first as! TestObject

        XCTAssertEqual(shadow.stringField, "foo")
        XCTAssertEqual(shadow.booleanField, true)
        XCTAssertNil(shadow.numberField)
    }

    func testExisted() {
        let object = sharedObject

        let query = Query(className: TestObject.className())
        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("stringField", .Existed)

        let (response, objects) = query.find()
        XCTAssertTrue(response.isSuccess && !objects.isEmpty)
    }

    func testNotExisted() {
        let query = Query(className: TestObject.className())
        query.whereKey("objectId", .NotExisted)

        let (response, objects) = query.find()
        XCTAssertTrue(response.isSuccess && objects.isEmpty)
    }

    func testEqualTo() {
        let object = sharedObject

        let query = Query(className: TestObject.className())
        query.whereKey("objectId", .EqualTo(value: object.objectId!))

        let (response, objects) = query.find()
        XCTAssertTrue(response.isSuccess && !objects.isEmpty)
    }

}
