//
//  BaseTestCase.swift
//  BaseTestCase
//
//  Created by Tang Tianyong on 2/22/16.
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

class BaseTestCase: XCTestCase {
    
    override func setUp() {
        super.setUp()
        /* App name is "iOS SDK UnitTest". */
        LeanCloud.initialize(
            applicationID:  "nq0awk3lh1dpmbkziz54377mryii8ny4xvp6njoygle5nlyg",
            applicationKey: "6vdnmdkdi4fva9i06lt50s4mcsfhppjpzm3zf5zjc9ty4pdz"
        )
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
}
