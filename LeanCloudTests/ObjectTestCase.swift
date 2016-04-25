//
//  ObjectTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/18/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class ObjectTestCase: BaseTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testSaveObject() {
        let object = TestObject()

        XCTAssertTrue(object.save().isSuccess)
        XCTAssertNotNil(object.objectId)
    }

    func testPrimitiveProperty() {
        let object = TestObject()

        object.numberField   = 1
        object.booleanField  = true
        object.stringField   = "123456"
        object.geoPointField = LCGeoPoint(latitude: 45, longitude: -45)
        object.dataField     = LCData(NSData())
        object.dateField     = LCDate(NSDate(timeIntervalSince1970: 1))

        XCTAssertTrue(object.save().isSuccess)
        XCTAssertNotNil(object.objectId)

        let shadow = TestObject(objectId: object.objectId!.value)

        XCTAssertTrue(shadow.fetch().isSuccess)

        XCTAssertEqual(shadow.numberField,   object.numberField)
        XCTAssertEqual(shadow.booleanField,  object.booleanField)
        XCTAssertEqual(shadow.stringField,   object.stringField)
        XCTAssertEqual(shadow.geoPointField, object.geoPointField)
        XCTAssertEqual(shadow.dataField,     object.dataField)
        XCTAssertEqual(shadow.dateField,     object.dateField)
    }

    func testArrayProperty() {
        let object  = TestObject()
        let element = TestObject()

        object.append("arrayField", element: element)

        XCTAssertTrue(object.save().isSuccess)
        XCTAssertNotNil(element.objectId)
        XCTAssertNotNil(object.objectId)

        let shadow = TestObject(objectId: object.objectId!.value)

        XCTAssertTrue(shadow.fetch().isSuccess)
        XCTAssertEqual(shadow.arrayField, LCArray([element]))
    }

    func testDictionaryProperty() {
        let object  = TestObject()
        let element = TestObject()

        let dictionary: LCDictionary = [
            "foo": element,
            "bar": LCString("foo and bar")
        ]

        object.dictionaryField = dictionary

        XCTAssertTrue(object.save().isSuccess)
        XCTAssertNotNil(element.objectId)
        XCTAssertNotNil(object.objectId)

        let shadow = TestObject(objectId: object.objectId!.value)

        XCTAssertTrue(shadow.fetch().isSuccess)
        XCTAssertEqual(shadow.dictionaryField, dictionary)
    }

    func testRelationProperty() {
        let object   = TestObject()
        let relation = TestObject()

        object.insertRelation("relationField", object: relation)

        XCTAssertTrue(object.save().isSuccess)
        XCTAssertNotNil(relation.objectId)
        XCTAssertNotNil(object.objectId)

        let shadow = TestObject(objectId: object.objectId!.value)

        XCTAssertTrue(shadow.fetch().isSuccess)
        XCTAssertNotNil(shadow.relationField)
    }

    func testObjectProperty() {
        let object = TestObject()
        let child  = TestObject()

        object.objectField = child

        XCTAssertTrue(object.save().isSuccess)
        XCTAssertNotNil(child.objectId)
        XCTAssertNotNil(object.objectId)
    }

    func testNonLCTypeProperty() {
        let object1 = TestObject()
        let object2 = TestObject(dictionary: ["nonLCTypeField": LCString("foo")])

        object1.nonLCTypeField = "foo"

        XCTAssertNil(object1.dictionary["nonLCTypeField"])
        XCTAssertNil(object2.nonLCTypeField)
    }

    func testNonDynamicProperty() {
        let object1 = TestObject(objectId: "1010101010101010")
        let object2 = TestObject(objectId: "1010101010101010")

        object1.nonDynamicField = "foo"
        object2.set("nonDynamicField", value: LCString("foo"))

        /* Non-dynamic property cannot record update operation by accessor assignment.
           However, you can use set(_:value:) method to get things done. */
        XCTAssertFalse(object1.hasDataToUpload)

        XCTAssertEqual(object2.nonDynamicField, LCString("foo"))
        XCTAssertTrue(object2.hasDataToUpload)
    }

}
