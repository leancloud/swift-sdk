//
//  TypeTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 9/2/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class TypeTestCase: BaseTestCase {

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
    }

    func testStringConvertible() {
        XCTAssertEqual(convert("foo") as? LCString, "foo")
        XCTAssertEqual(convert(NSString(string: "foo")) as? LCString, "foo")
    }

    func testArrayConvertible() {
        let array = [42, true, NSNull(), [:], [], Data(), Date()] as [Any]
        XCTAssertEqual(convert(array) as? LCArray, LCArray(unsafeObject: array as [AnyObject]))
    }

    func testDictionaryConvertible() {
        let dictionary = ["foo": "bar", "true": true, "dict": ["null": NSNull()]] as [String : Any]
        XCTAssertEqual(convert(dictionary) as? LCDictionary, LCDictionary(unsafeObject: dictionary as [LCDictionary.Key : AnyObject]))
    }

    func testDataConvertible() {
        let data = Data()
        XCTAssertEqual(convert(data) as? LCData, LCData(data))
    }

    func testDateConvertible() {
        let date = Date()
        XCTAssertEqual(convert(date) as? LCDate, LCDate(date))
    }

    func archiveThenUnarchive<T>(_ object: T) -> T {
        return NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: object)) as! T
    }

    func testCoding() {
        let acl = LCACL()
        acl.setAccess(.write, allowed: true)
        let aclCopy = archiveThenUnarchive(acl)
        XCTAssertTrue(aclCopy.getAccess(.write))

        let array = [true, 42, "foo"].lcArray
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

        let dictionary = ["foo": "bar", "baz": 42].lcDictionary
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
        object.insertRelation("friend", object: friend)
        let objectCopy = LCApplication.default.perform {
            archiveThenUnarchive(object)
        }
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
