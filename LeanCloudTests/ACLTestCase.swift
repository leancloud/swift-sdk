//
//  ACLTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 5/6/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class ACLTestCase: BaseTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testGetAndSet() {
        let acl = LCACL()

        /* Update access permission for public. */
        XCTAssertFalse(acl.getAccess(.read))
        acl.setAccess(.read, allowed: true)
        XCTAssertTrue(acl.getAccess(.read))
        XCTAssertFalse(acl.getAccess([.read, .write]))
        acl.setAccess(.write, allowed: true)
        XCTAssertTrue(acl.getAccess(.write))
        XCTAssertTrue(acl.getAccess([.read, .write]))

        let userID   = "1"
        let roleName = "2"
        let readKey  = "read"
        let writeKey = "write"
        let roleAccessKey = LCACL.accessKey(roleName: roleName)

        /* Update access permission for user. */
        acl.setAccess([.read, .write], allowed: true, forUserID: userID)
        XCTAssertTrue(acl.getAccess([.read, .write], forUserID: userID))
        acl.setAccess(.write, allowed: false, forUserID: userID)
        XCTAssertFalse(acl.getAccess(.write, forUserID: userID))

        /* Update access permission for role. */
        acl.setAccess([.read, .write], allowed: true, forRoleName: roleName)
        XCTAssertEqual(acl.value[roleAccessKey]!, [readKey: true, writeKey: true])
        acl.setAccess(.write, allowed: false, forRoleName: roleName)
        XCTAssertEqual(acl.value[roleAccessKey]!, [readKey: true])
        XCTAssertTrue(acl.getAccess(.read, forRoleName: roleName))
    }

    func testPublicACL() {
        let object = TestObject()
        object.ACL = LCACL()
        XCTAssertTrue(object.save().isSuccess)
        XCTAssertTrue(object.fetch().isFailure)
    }

}
