//
//  LCObjectTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/18/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCObjectTestCase: BaseTestCase {

    var observed = false
    
    func testDeinit() {
        var object: LCObject! = LCObject()
        weak var wObject: LCObject? = object
        XCTAssertNotNil(wObject)
        object = nil
        XCTAssertNil(wObject)
    }

    func testSave() {
        let object = TestObject()

        XCTAssertTrue(object.save().isSuccess)
        XCTAssertNotNil(object.objectId)
        
        XCTAssertTrue(object.save().isSuccess)
    }
    
    func testSaveObjectWithOption() {
        let object = TestObject(className: "\(TestObject.self)")
        object.numberField = 0
        
        XCTAssertTrue(object.save(options: [.fetchWhenSave]).isSuccess)
        
        if let objectId = object.objectId {
            object.numberField = 1
            
            let noResultQuery = LCQuery(className: "\(TestObject.self)")
            noResultQuery.whereKey("objectId", .equalTo(UUID().uuidString))
            XCTAssertEqual(object.save(options: [.query(noResultQuery)]).error?.code, 305)
            
            let hasResultQuery = LCQuery(className: "\(TestObject.self)")
            hasResultQuery.whereKey("objectId", .equalTo(objectId))
            XCTAssertTrue(object.save(options: [.query(hasResultQuery)]).isSuccess)
        } else {
            XCTFail("no objectId")
        }
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

    func testSaveObjects() {
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
        
        XCTAssertTrue(LCObject.save([]).isSuccess)
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
        
        XCTAssertTrue(LCObject.fetch([]).isSuccess)
    }
    
    func testFetchWithKeys() {
        let object = TestObject(className: "\(TestObject.self)")
        object.booleanField = false
        object.stringField = "string"
        object.numberField = 1
        XCTAssertTrue(object.save().isSuccess)
        
        if let objectId = object.objectId {
            let replica = TestObject(className: "\(TestObject.self)", objectId: objectId)
            replica.booleanField = true
            replica.stringField = "changed"
            replica.numberField = 2
            XCTAssertTrue(replica.save().isSuccess)
            
            XCTAssertTrue(object.fetch(keys: ["booleanField", "numberField"]).isSuccess)
            XCTAssertEqual(object.booleanField, replica.booleanField)
            XCTAssertEqual(object.numberField, replica.numberField)
            XCTAssertNotEqual(object.stringField, replica.stringField)
        } else {
            XCTFail("no objectId")
        }
    }

    func testDelete() {
        let object = TestObject()
        XCTAssertTrue(object.save().isSuccess)
        XCTAssertTrue(object.delete().isSuccess)
        XCTAssertTrue(object.fetch().isFailure)
    }

    func testDeleteObjects() {
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
        
        XCTAssertTrue(LCObject.delete([]).isSuccess)
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
    
    func testBatchChildren() {
        let object1 = LCObject(className: "BatchChildren")
        let object2 = LCObject(className: "BatchChildren")
        let object3 = LCObject(className: "BatchChildren")
        object1["child"] = object2
        object2["child"] = object3
        XCTAssertTrue(object1.save(options: [.fetchWhenSave]).isSuccess)
        XCTAssertNotNil(object1.objectId)
        XCTAssertNotNil(object2.objectId)
        XCTAssertNotNil(object3.objectId)
    }
    
    func testValueForKey() {
        let object = LCObject()
        let key = "key"
        XCTAssertNil(object[key])
        XCTAssertNil(object.get(key))
        XCTAssertNil(object.value(forKey: key))
        XCTAssertNil(object.value(forUndefinedKey: key))
        object[key] = "value".lcString
        XCTAssertNotNil(object[key])
        XCTAssertNotNil(object.get(key))
        XCTAssertNotNil(object.value(forKey: key))
        XCTAssertNil(object.value(forUndefinedKey: key))
    }
    
    func testSubscriptValueConvertible() {
        let object = LCObject()
        
        let intKey = "int"
        object[intKey] = 42
        XCTAssertTrue(object[intKey] is LCNumber)
        XCTAssertEqual(object[intKey]?.intValue, 42)
        object[intKey] = 43.lcValue
        XCTAssertTrue(object[intKey] is LCNumber)
        XCTAssertEqual(object[intKey]?.intValue, 43)
        object[intKey] = 44.lcNumber
        XCTAssertTrue(object[intKey] is LCNumber)
        XCTAssertEqual(object[intKey]?.intValue, 44)
        
        let doubleKey = "double"
        object[doubleKey] = 42.0
        XCTAssertTrue(object[doubleKey] is LCNumber)
        XCTAssertEqual(object[doubleKey]?.doubleValue, 42.0)
        object[doubleKey] = 43.0.lcValue
        XCTAssertTrue(object[doubleKey] is LCNumber)
        XCTAssertEqual(object[doubleKey]?.doubleValue, 43.0)
        object[doubleKey] = 44.0.lcNumber
        XCTAssertTrue(object[doubleKey] is LCNumber)
        XCTAssertEqual(object[doubleKey]?.doubleValue, 44.0)
        
        let boolKey = "bool"
        object[boolKey] = true
        XCTAssertTrue(object[boolKey] is LCBool)
        XCTAssertEqual(object[boolKey]?.boolValue, true)
        object[boolKey] = false.lcValue
        XCTAssertTrue(object[boolKey] is LCBool)
        XCTAssertEqual(object[boolKey]?.boolValue, false)
        object[boolKey] = true.lcBool
        XCTAssertTrue(object[boolKey] is LCBool)
        XCTAssertEqual(object[boolKey]?.boolValue, true)
        
        let stringKey = "string"
        object[stringKey] = "a"
        XCTAssertTrue(object[stringKey] is LCString)
        XCTAssertEqual(object[stringKey]?.stringValue, "a")
        object[stringKey] = "b".lcValue
        XCTAssertTrue(object[stringKey] is LCString)
        XCTAssertEqual(object[stringKey]?.stringValue, "b")
        object[stringKey] = "c".lcString
        XCTAssertTrue(object[stringKey] is LCString)
        XCTAssertEqual(object[stringKey]?.stringValue, "c")
        
        let arrayKey = "array"
        object[arrayKey] = ["a"]
        XCTAssertTrue(object[arrayKey] is LCArray)
        XCTAssertEqual(object[arrayKey]?.arrayValue?.count, 1)
        XCTAssertEqual(object[arrayKey]?.arrayValue?[0] as? String, "a")
        object[arrayKey] = ["a", "b"].lcValue
        XCTAssertTrue(object[arrayKey] is LCArray)
        XCTAssertEqual(object[arrayKey]?.arrayValue?.count, 2)
        XCTAssertEqual(object[arrayKey]?.arrayValue?[0] as? String, "a")
        XCTAssertEqual(object[arrayKey]?.arrayValue?[1] as? String, "b")
        object[arrayKey] = ["a", "b", "c"].lcArray
        XCTAssertTrue(object[arrayKey] is LCArray)
        XCTAssertEqual(object[arrayKey]?.arrayValue?.count, 3)
        XCTAssertEqual(object[arrayKey]?.arrayValue?[0] as? String, "a")
        XCTAssertEqual(object[arrayKey]?.arrayValue?[1] as? String, "b")
        XCTAssertEqual(object[arrayKey]?.arrayValue?[2] as? String, "c")
        object[arrayKey] = LCArray(["a", 1])
        XCTAssertTrue(object[arrayKey] is LCArray)
        XCTAssertEqual(object[arrayKey]?.arrayValue?.count, 2)
        XCTAssertEqual(object[arrayKey]?.arrayValue?[0] as? String, "a")
        XCTAssertEqual(object[arrayKey]?.arrayValue?[1] as? Double, 1)
        
        let dictionaryKey = "dictionary"
        object[dictionaryKey] = ["1": "a"]
        XCTAssertTrue(object[dictionaryKey] is LCDictionary)
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?.count, 1)
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?["1"] as? String, "a")
        object[dictionaryKey] = ["1": "a", "2": "b"].lcValue
        XCTAssertTrue(object[dictionaryKey] is LCDictionary)
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?.count, 2)
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?["1"] as? String, "a")
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?["2"] as? String, "b")
        object[dictionaryKey] = ["1": "a", "2": "b", "3": "c"].lcDictionary
        XCTAssertTrue(object[dictionaryKey] is LCDictionary)
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?.count, 3)
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?["1"] as? String, "a")
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?["2"] as? String, "b")
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?["3"] as? String, "c")
        object[dictionaryKey] = LCDictionary(["1": "a", "2": 42])
        XCTAssertTrue(object[dictionaryKey] is LCDictionary)
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?.count, 2)
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?["1"] as? String, "a")
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?["2"] as? Double, 42)
        
        XCTAssertTrue(object.save(options: [.fetchWhenSave]).isSuccess)
        XCTAssertEqual(object[intKey]?.intValue, 44)
        XCTAssertEqual(object[doubleKey]?.doubleValue, 44.0)
        XCTAssertEqual(object[boolKey]?.boolValue, true)
        XCTAssertEqual(object[stringKey]?.stringValue, "c")
        XCTAssertEqual(object[arrayKey]?.arrayValue?.count, 2)
        XCTAssertEqual(object[arrayKey]?.arrayValue?[0] as? String, "a")
        XCTAssertEqual(object[arrayKey]?.arrayValue?[1] as? Double, 1)
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?.count, 2)
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?["1"] as? String, "a")
        XCTAssertEqual(object[dictionaryKey]?.dictionaryValue?["2"] as? Double, 42)
    }
    
    func testKeyPath() {
        do {
            let object = self.object()
            try object.set("foo.bar", value: 1)
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        
        let object = self.object()
        object.dictionaryField = LCDictionary([
            "number": 1,
            "foo": "foo",
            "foos": ["bar"],
            "unset": "unset"])
        object.stringField = "string literal"
        XCTAssertTrue(object.save().isSuccess)
        
        do {
            try object.increase("dictionaryField.number")
            try object.set("dictionaryField.foo", value: "bar")
            try object.unset("dictionaryField.unset")
            try object.append("dictionaryField.foos", element: "bars")
            try object.remove("dictionaryField.foos", element: "bar")
            try object.append("dictionaryField.foos", element: "bar", unique: true)
            XCTAssertTrue(object.save().isSuccess)
            let dictionaryField = object.dictionaryField as? LCDictionary
            XCTAssertNil(dictionaryField?.unset)
            XCTAssertEqual(dictionaryField?.number as? LCNumber, LCNumber(2))
            XCTAssertEqual(dictionaryField?.foo as? LCString, LCString("bar"))
            XCTAssertEqual(dictionaryField?.foos as? LCArray, LCArray(["bars", "bar"]))
            XCTAssertNil(object["dictionaryField.number"])
            XCTAssertNil(object["dictionaryField.unset"])
            XCTAssertNil(object["dictionaryField.foo"])
            XCTAssertNil(object["dictionaryField.foos"])
            
            let shadow = self.object(object.objectId)
            XCTAssertTrue(shadow.fetch().isSuccess)
            XCTAssertEqual(shadow.dictionaryField as? LCDictionary, dictionaryField)
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            try object.set("stringField.foo", value: "bar")
            XCTAssertNotNil(object.save().error)
            XCTAssertEqual(object.stringField as? LCString, LCString("string literal"))
            XCTAssertNil(object["stringField.foo"])
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            try object.insertRelation("dictionaryField.relation", object: self.object())
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
    }
}

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
