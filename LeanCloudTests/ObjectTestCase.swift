//
//  ObjectTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/18/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class TestObject: LCObject {
    dynamic var numberField: LCNumber?
    dynamic var booleanField: LCBool?
    dynamic var stringField: LCString?
    dynamic var arrayField: LCArray?
    dynamic var dictionaryField: LCDictionary?
    dynamic var objectField: LCObject?
    dynamic var relationField: LCRelation?
    dynamic var geoPointField: LCGeoPoint?
    dynamic var dataField: LCData?
    dynamic var dateField: LCDate?
    dynamic var fileField: LCFile?
}

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

}
