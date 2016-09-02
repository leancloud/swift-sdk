//
//  TypeTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 9/2/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
import LeanCloud

class TypeTestCase: BaseTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func convert(object: LCTypeConvertible) -> LCType {
        return object.lcType
    }

    func testConvertible() {
        // Null
        XCTAssertEqual(convert(NSNull()) as? LCNull, LCNull())

        // Integer
        XCTAssertEqual(convert(Int(42))     as? LCNumber, LCNumber(42))
        XCTAssertEqual(convert(UInt(42))    as? LCNumber, LCNumber(42))
        XCTAssertEqual(convert(Int8(42))    as? LCNumber, LCNumber(42))
        XCTAssertEqual(convert(UInt8(42))   as? LCNumber, LCNumber(42))
        XCTAssertEqual(convert(Int16(42))   as? LCNumber, LCNumber(42))
        XCTAssertEqual(convert(UInt16(42))  as? LCNumber, LCNumber(42))
        XCTAssertEqual(convert(Int32(42))   as? LCNumber, LCNumber(42))
        XCTAssertEqual(convert(UInt32(42))  as? LCNumber, LCNumber(42))
        XCTAssertEqual(convert(Int64(42))   as? LCNumber, LCNumber(42))
        XCTAssertEqual(convert(UInt64(42))  as? LCNumber, LCNumber(42))

        // Float
        XCTAssertEqual(convert(Float(42))   as? LCNumber, LCNumber(42))
        XCTAssertEqual(convert(Float80(42)) as? LCNumber, LCNumber(42))
        XCTAssertEqual(convert(Double(42))  as? LCNumber, LCNumber(42))

        // String
        XCTAssertEqual(convert("foo")                   as? LCString, LCString("foo"))
        XCTAssertEqual(convert(NSString(string: "foo")) as? LCString, LCString("foo"))

        // Array
        let array = [42, true, NSNull(), [:], [], NSData(), NSDate()]
        XCTAssertEqual(convert(array) as? LCArray, LCArray(unsafeObject: array))

        // Dictionary
        let dictionary = ["foo": "bar", "true": true, "dict": ["null": NSNull()]]
        XCTAssertEqual(convert(dictionary) as? LCDictionary, LCDictionary(unsafeObject: dictionary))

        // Data
        let data = NSData()
        XCTAssertEqual(convert(data) as? LCData, LCData(data))

        // Date
        let date = NSDate()
        XCTAssertEqual(convert(date) as? LCDate, LCDate(date))
    }

}
