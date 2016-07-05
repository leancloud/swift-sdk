//
//  RelationTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 7/5/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class RelationTestCase: BaseTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testQuery() {
        let object   = sharedObject
        let relation = sharedRelation

        let query  = object.relationForKey("relationField").query
        let result = query.find()

        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.objects!.contains(relation))
    }

    func testClassNameRedirection() {
        let object   = LCObject()
        let relation = TestObject()

        object.insertRelation("relationField", object: relation)
        XCTAssertTrue(object.save().isSuccess)

        let shadow = LCObject(objectId: object.objectId!.value)
        let query = shadow.relationForKey("relationField").query

        XCTAssertEqual(query.className, object.actualClassName)
        XCTAssertNotEqual(query.className, relation.actualClassName)

        let result = query.find()

        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.objects!.contains(relation))
    }

    func testInsertAndRemove() {
        let object   = LCObject()
        let child    = TestObject()
        let relation = object.relationForKey("relationField")
        let query    = relation.query

        relation.insert(child)
        XCTAssertTrue(object.save().isSuccess)
        XCTAssertTrue(query.find().objects!.contains(child))

        relation.remove(child)
        XCTAssertTrue(object.save().isSuccess)
        XCTAssertFalse(query.find().objects!.contains(child))
    }

}
