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

    var observed = false

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

        XCTAssertNil(object1["nonLCTypeField"])
        XCTAssertNil(object2.nonLCTypeField)
        XCTAssertNotNil(object2["nonLCTypeField"])
    }

    func testNonDynamicProperty() {
        let object1 = TestObject(objectId: "1010101010101010")
        let object2 = TestObject(objectId: "1010101010101010")

        object1.nonDynamicField = "foo"
        XCTAssertEqual(object1.nonDynamicField, "foo")
        XCTAssertEqual(object1["nonDynamicField"], nil)
        XCTAssertFalse(object1.hasDataToUpload)

        /* Non-dynamic property cannot record update operation by accessor assignment.
           However, you can use subscript to get things done. */
        object2["nonDynamicField"] = LCString("foo")
        XCTAssertEqual(object2.nonDynamicField, nil)
        XCTAssertEqual(object2["nonDynamicField"], LCString("foo"))
        XCTAssertTrue(object2.hasDataToUpload)
    }

    func testFetch() {
        let object = sharedObject
        let shadow = TestObject(objectId: object.objectId!.value)

        let result = shadow.fetch()
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(shadow.stringField, "foo")
    }

    func testFetchNewborn() {
        let object = TestObject()

        let result = object.fetch()
        XCTAssertTrue(result.isFailure)
        XCTAssertEqual(Error.InternalErrorCode(rawValue: result.error!.code), .NotFound)
    }

    func testFetchNotFound() {
        let object = TestObject(objectId: "000")

        let result = object.fetch()
        XCTAssertTrue(result.isFailure)
        XCTAssertEqual(Error.ServerErrorCode(rawValue: result.error!.code), .ObjectNotFound)
    }

    func testFetchObjects() {
        let object   = sharedObject
        let child    = sharedChild
        let notFound = TestObject(objectId: "000")
        let newborn  = TestObject()

        XCTAssertEqual(Error.InternalErrorCode(rawValue: LCObject.fetch([object, newborn]).error!.code), .NotFound)
        XCTAssertEqual(Error.ServerErrorCode(rawValue: LCObject.fetch([object, notFound]).error!.code), .ObjectNotFound)
        XCTAssertTrue(LCObject.fetch([object, child]).isSuccess)
    }

    func testDelete() {
        let object = TestObject()
        XCTAssertTrue(object.save().isSuccess)
        XCTAssertTrue(object.delete().isSuccess)
        XCTAssertTrue(object.fetch().isFailure)
    }

    func testDeleteAll() {
        let object1 = TestObject()
        let object2 = TestObject()

        XCTAssertTrue(object1.save().isSuccess)
        XCTAssertTrue(object2.save().isSuccess)

        let shadow1 = TestObject(objectId: object1.objectId!.value)
        let shadow2 = TestObject(objectId: object1.objectId!.value)

        shadow1.stringField = "bar"
        shadow2.stringField = "bar"

        /* After deleted, we cannot update shadow object any more, because object not found. */
        XCTAssertTrue(LCObject.delete([object1, object2]).isSuccess)
        XCTAssertFalse(shadow1.save().isSuccess)
        XCTAssertFalse(shadow2.save().isSuccess)
    }

    func testKVO() {
        let object = TestObject()

        object.addObserver(self, forKeyPath: "stringField", options: .New, context: nil)
        object.stringField = "yet another value"
        object.removeObserver(self, forKeyPath: "stringField")

        XCTAssertTrue(observed)
    }

    override func observeValueForKeyPath(
        keyPath: String?,
        ofObject object: AnyObject?,
        change: [String : AnyObject]?,
        context: UnsafeMutablePointer<Void>)
    {
        if let newValue = change?["new"] as? LCString {
            if newValue == LCString("yet another value") {
                observed = true
            }
        }
    }

    func testInvalidType() {
        let object = TestObject()

        XCTAssertThrowsException({
            object.set("stringField", value: "123" as LCString)
            object.increase("stringField", by: 1)
        })
    }

    func testClassName() {
        let className = "TestObject"
        let object = LCObject(className: className)
        let stringValue = LCString("foo")

        object["stringField"] = stringValue
        XCTAssertTrue(object.save().isSuccess)

        let shadow = LCObject(className: className, objectId: object.objectId!.value)
        XCTAssertTrue(shadow.fetch().isSuccess)
        XCTAssertEqual(shadow["stringField"], stringValue)
    }
}
