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

    func testCircularReference() {
        let object1 = TestObject()
        let object2 = TestObject()

        object1.objectField = object2
        object2.objectField = object1

        let result = object1.save()

        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.error?._code, LCError.InternalErrorCode.inconsistency.rawValue)
    }

    func testSaveNewbornOrphans() {
        let object = TestObject()
        let newbornOrphan1 = TestObject()
        let newbornOrphan2 = TestObject()
        let newbornOrphan3 = TestObject()
        let newbornOrphan4 = TestObject()
        let newbornOrphan5 = TestObject()

        object.arrayField = [newbornOrphan1]

        object.dictionaryField = [
            "object": newbornOrphan2,
            "objectArray": LCArray([newbornOrphan3])
        ]

        newbornOrphan3.arrayField = [newbornOrphan5]

        try! object.insertRelation("relationField", object: newbornOrphan4)

        XCTAssertTrue(object.save().isSuccess)

        XCTAssertNotNil(newbornOrphan1.objectId)
        XCTAssertNotNil(newbornOrphan2.objectId)
        XCTAssertNotNil(newbornOrphan3.objectId)
        XCTAssertNotNil(newbornOrphan4.objectId)
        XCTAssertNotNil(newbornOrphan5.objectId)
    }

    func testBatchSave() {
        let object1 = TestObject()
        let object2 = TestObject()

        XCTAssertTrue(LCObject.save([object1, object2]).isSuccess)

        XCTAssertNotNil(object1.objectId)
        XCTAssertNotNil(object2.objectId)

        let object3 = TestObject()
        let object4 = TestObject()

        let newbornOrphan1 = TestObject()
        let newbornOrphan2 = TestObject()

        newbornOrphan1.arrayField = [newbornOrphan2]

        object4.arrayField = [newbornOrphan1]

        XCTAssertTrue(LCObject.save([object3, object4]).isSuccess)

        XCTAssertNotNil(object3.objectId)
        XCTAssertNotNil(object4.objectId)
        XCTAssertNotNil(newbornOrphan1.objectId)
        XCTAssertNotNil(newbornOrphan2.objectId)
    }

    func testPrimitiveProperty() {
        let object = TestObject()

        object.numberField   = 1
        object.booleanField  = true
        object.stringField   = "123456"
        object.geoPointField = LCGeoPoint(latitude: 45, longitude: -45)
        object.dataField     = LCData(Data())
        object.dateField     = LCDate(Date(timeIntervalSince1970: 1))

        XCTAssertTrue(object.save().isSuccess)
        XCTAssertNotNil(object.objectId)

        let shadow = TestObject(objectId: object.objectId!)

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

        try! object.append("arrayField", element: element)

        XCTAssertTrue(object.save().isSuccess)
        XCTAssertNotNil(element.objectId)
        XCTAssertNotNil(object.objectId)

        let shadow = TestObject(objectId: object.objectId!)

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

        let shadow = TestObject(objectId: object.objectId!)

        XCTAssertTrue(shadow.fetch().isSuccess)
        XCTAssertEqual(shadow.dictionaryField, dictionary)
    }

    func testRelationProperty() {
        let object = TestObject()
        let friend = TestObject()

        try! object.insertRelation("relationField", object: friend)

        XCTAssertTrue(object.save().isSuccess)
        XCTAssertNotNil(friend.objectId)
        XCTAssertNotNil(object.objectId)

        let shadow = TestObject(objectId: object.objectId!)

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

    func testFetch() {
        let object = sharedObject
        let shadow = TestObject(objectId: object.objectId!)

        let result = shadow.fetch()
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(shadow.stringField, "foo")
    }

    func testFetchNewborn() {
        let object = TestObject()

        let result = object.fetch()
        XCTAssertTrue(result.isFailure)
        XCTAssertEqual(LCError.InternalErrorCode(rawValue: result.error!._code), .notFound)
    }

    func testFetchNotFound() {
        let object = TestObject(objectId: "000")

        let result = object.fetch()
        XCTAssertTrue(result.isFailure)
        XCTAssertEqual(LCError.ServerErrorCode(rawValue: result.error!._code), .objectNotFound)
    }

    func testFetchObjects() {
        let object   = sharedObject
        let child    = sharedChild
        let notFound = TestObject(objectId: "000")
        let newborn  = TestObject()

        XCTAssertEqual(LCError.InternalErrorCode(rawValue: LCObject.fetch([object, newborn]).error!._code), .notFound)
        XCTAssertEqual(LCError.ServerErrorCode(rawValue: LCObject.fetch([object, notFound]).error!._code), .objectNotFound)
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

        let shadow1 = TestObject(objectId: object1.objectId!)
        let shadow2 = TestObject(objectId: object2.objectId!)

        shadow1.stringField = "bar"
        shadow2.stringField = "bar"

        /* After deleted, we cannot update shadow object any more, because object not found. */
        XCTAssertTrue(LCObject.delete([object1, object2]).isSuccess)
        XCTAssertFalse(shadow1.save().isSuccess)
        XCTAssertFalse(shadow2.save().isSuccess)
    }

    func testKVO() {
        let object = TestObject()

        object.addObserver(self, forKeyPath: "stringField", options: .new, context: nil)
        object.stringField = "yet another value"
        object.removeObserver(self, forKeyPath: "stringField")

        XCTAssertTrue(observed)
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?)
    {
        if let newValue = change?[NSKeyValueChangeKey.newKey] as? LCString {
            if newValue == LCString("yet another value") {
                observed = true
            }
        }
    }

    func testClassName() {
        let className = "TestObject"
        let object = LCObject(className: className)
        let stringValue = LCString("foo")

        object["stringField"] = stringValue
        XCTAssertTrue(object.save().isSuccess)

        let shadow = LCObject(className: className, objectId: object.objectId!)
        XCTAssertTrue(shadow.fetch().isSuccess)
        XCTAssertEqual(shadow["stringField"] as? LCString, stringValue)
    }

    func testDynamicMemberLookup() {
        let object = LCObject()
        let dictionary = LCDictionary()

        object.foo = "bar"
        XCTAssertEqual(object.foo?.stringValue, "bar")

        dictionary.foo = "bar"
        XCTAssertEqual(dictionary.foo?.stringValue, "bar")
    }

    func testJSONString() {
        XCTAssertEqual(LCNull().jsonString, "null")
        XCTAssertEqual(LCNumber(1).jsonString, "1")
        XCTAssertEqual(LCNumber(3.14).jsonString, "3.14")
        XCTAssertEqual(LCBool(true).jsonString, "true")
        XCTAssertEqual(LCString("foo").jsonString, "\"foo\"")
        XCTAssertEqual(try LCArray(unsafeObject: [1, true, [0, false]]).jsonString, """
        [
            1,
            true,
            [
                0,
                false
            ]
        ]
        """)
        XCTAssertEqual(try LCDictionary(unsafeObject: ["foo": "bar", "bar": ["bar": "baz"]]).jsonString, """
        {
            "bar": {
                "bar": "baz"
            },
            "foo": "bar"
        }
        """)
        XCTAssertEqual(LCObject().jsonString, """
        {
            "__type": "Object",
            "className": "LCObject"
        }
        """)
    }
}
