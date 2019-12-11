//
//  LCTypeTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 9/2/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCTypeTestCase: BaseTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func convert(_ object: LCValueConvertible) -> LCValue {
        return object.lcValue
    }

    func testNullConvertible() {
        XCTAssertEqual(convert(NSNull()) as? LCNull, LCNull())
    }
    
    func testBoolConvertible() {
        XCTAssertEqual(convert(true) as? LCBool, true)
        XCTAssertEqual(LCBool(true).boolValue, true)
        XCTAssertFalse(LCBool(LCBool()).value)
    }

    func testIntegerConvertible() {
        XCTAssertEqual(convert(Int(42))    as? LCNumber, 42)
        XCTAssertEqual(convert(UInt(42))   as? LCNumber, 42)
        XCTAssertEqual(convert(Int8(42))   as? LCNumber, 42)
        XCTAssertEqual(convert(UInt8(42))  as? LCNumber, 42)
        XCTAssertEqual(convert(Int16(42))  as? LCNumber, 42)
        XCTAssertEqual(convert(UInt16(42)) as? LCNumber, 42)
        XCTAssertEqual(convert(Int32(42))  as? LCNumber, 42)
        XCTAssertEqual(convert(UInt32(42)) as? LCNumber, 42)
        XCTAssertEqual(convert(Int64(42))  as? LCNumber, 42)
        XCTAssertEqual(convert(UInt64(42)) as? LCNumber, 42)
    }

    func testFloatConvertible() {
        XCTAssertEqual(convert(Float(42))  as? LCNumber, 42)
        XCTAssertEqual(convert(Double(42)) as? LCNumber, 42)
        XCTAssertEqual(LCNumber(), LCNumber(LCNumber()))
    }

    func testStringConvertible() {
        XCTAssertEqual(convert("foo") as? LCString, "foo")
        XCTAssertEqual(convert(NSString(string: "foo")) as? LCString, "foo")
        XCTAssertEqual(LCString(), LCString(LCString()))
    }
    
    func testArrayInit() {
        let array1 = LCArray([42])
        let array2 = LCArray(array1)
        XCTAssertFalse(array1 === array2)
        XCTAssertEqual(array1.value.count, array2.value.count)
        XCTAssertEqual(array1.value.first as? LCNumber, array2.value.first as? LCNumber)
    }

    func testArrayConvertible() {
        let date = Date()
        let object = LCObject()

        XCTAssertEqual(
            LCArray([42, true, NSNull(), [String: String](), [String](), Data(), date, object]),
            try LCArray(unsafeObject: [42, true, NSNull(), [String: String](), [String](), Data(), date, object]))
    }
    
    func testArrayLiteral() {
        let _: LCArray = ["a"]
        let _: LCArray = ["a", 1]
        let _: LCArray = ["a", LCNumber(1)]
        let _: LCArray = [LCString("a"), 1]
        let _: LCArray = [LCString("a"), LCNumber(1)]
    }

    func testDictionaryConvertible() {
        let date = Date()
        let object = LCObject()

        XCTAssertEqual(
            LCDictionary(["foo": "bar", "true": true, "dict": ["null": NSNull()], "date": date, "object": object]),
            try LCDictionary(unsafeObject: ["foo": "bar", "true": true, "dict": ["null": NSNull()], "date": date, "object": object]))
        
        let dic = LCDictionary()
        dic["1"] = "a"
        dic["2"] = 42
        dic["3"] = true
        XCTAssertEqual(dic["1"]?.stringValue, "a")
        XCTAssertEqual(dic["2"]?.intValue, 42)
        XCTAssertEqual(dic["3"]?.boolValue, true)
    }

    func testDataConvertible() {
        let data = Data()
        XCTAssertEqual(convert(data) as? LCData, LCData(data))
        XCTAssertTrue(LCData(LCData()).value.isEmpty)
    }

    func testDateConvertible() {
        let date = Date()
        XCTAssertEqual(convert(date) as? LCDate, LCDate(date))
        XCTAssertEqual(LCDate(date), LCDate(LCDate(date)))
    }
    
    func testGeoPoint() {
        XCTAssertEqual(LCGeoPoint(), LCGeoPoint(LCGeoPoint()))
    }

    func archiveThenUnarchive<T>(_ object: T) -> T {
        return NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: object)) as! T
    }

    func testCoding() {
        let acl = LCACL()
        acl.setAccess(.write, allowed: true)
        let aclCopy = archiveThenUnarchive(acl)
        XCTAssertTrue(aclCopy.getAccess(.write))

        let array = LCArray([true, 42, "foo"])
        let arrayCopy = archiveThenUnarchive(array)
        XCTAssertEqual(arrayCopy, array)

        let bool = LCBool(true)
        let boolCopy = archiveThenUnarchive(bool)
        XCTAssertEqual(boolCopy, bool)

        let data = LCData(base64EncodedString: "Zm9v")!
        let dataCopy = archiveThenUnarchive(data)
        XCTAssertEqual(dataCopy, data)

        let date = LCDate()
        let dateCopy = archiveThenUnarchive(date)
        XCTAssertEqual(dateCopy, date)

        let dictionary = LCDictionary(["foo": "bar", "baz": 42])
        let dictionaryCopy = archiveThenUnarchive(dictionary)
        XCTAssertEqual(dictionaryCopy, dictionary)

        let geoPoint = LCGeoPoint(latitude: 12, longitude: 34)
        let geoPointCopy = archiveThenUnarchive(geoPoint)
        XCTAssertEqual(geoPointCopy, geoPoint)

        let null = LCNull()
        let nullCopy = archiveThenUnarchive(null)
        XCTAssertEqual(nullCopy, null)

        let number = LCNumber(42)
        let numberCopy = archiveThenUnarchive(number)
        XCTAssertEqual(numberCopy, number)

        let object = LCObject(objectId: "1234567890")
        let friend = LCObject(objectId: "0987654321")
        try! object.insertRelation("friend", object: friend)
        let objectCopy = archiveThenUnarchive(object)
        XCTAssertEqual(objectCopy, object)
        let relation = object.relationForKey("friend")
        let relationCopy = objectCopy.relationForKey("friend")
        XCTAssertEqual(relationCopy.value, relation.value)

        /* Test mutability after unarchiving. */
        objectCopy["foo"] = "bar" as LCString

        let string = LCString("foo")
        let stringCopy = archiveThenUnarchive(string)
        XCTAssertEqual(stringCopy, string)
    }

}
