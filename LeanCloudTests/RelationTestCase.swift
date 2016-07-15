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
        let object = sharedObject
        let friend = sharedFriend
        let query  = object.relationForKey("relationField").query
        let result = query.find()

        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.objects!.contains(friend))
    }

    func testClassNameRedirection() {
        let object = LCObject()
        let friend = TestObject()

        object.insertRelation("relationField", object: friend)
        XCTAssertTrue(object.save().isSuccess)

        let shadow = LCObject(objectId: object.objectId!.value)
        let query = shadow.relationForKey("relationField").query

        XCTAssertEqual(query.objectClassName, object.actualClassName)
        XCTAssertNotEqual(query.objectClassName, friend.actualClassName)

        let result = query.find()

        XCTAssertTrue(result.isSuccess)
        XCTAssertTrue(result.objects!.contains(friend))
    }

    func testInsertAndRemove() {
        let object = LCObject()
        let child  = TestObject()
        let friend = object.relationForKey("relationField")
        let query  = friend.query

        friend.insert(child)
        XCTAssertTrue(object.save().isSuccess)
        XCTAssertTrue(query.find().objects!.contains(child))

        friend.remove(child)
        XCTAssertTrue(object.save().isSuccess)
        XCTAssertFalse(query.find().objects!.contains(child))
    }

}
