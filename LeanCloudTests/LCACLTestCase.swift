//
//  LCACLTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 5/6/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCACLTestCase: BaseTestCase {

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

    func testPublicRead() {
        var user: LCUser! = LCUser()
        user.username = uuid.lcString
        user.password = uuid.lcString
        XCTAssertTrue(user.signUp().isSuccess)
        user = LCUser.logIn(
            username: user.username!.value,
            password: user.password!.value)
            .object
        XCTAssertNotNil(user)
        
        let object = self.object()
        let acl = LCACL()
        acl.setAccess(.read, allowed: true)
        acl.setAccess(.write, allowed: false)
        acl.setAccess(.read, allowed: false, forUserID: user.objectId!.value)
        acl.setAccess(.write, allowed: true, forUserID: user.objectId!.value)
        object.ACL = acl
        XCTAssertTrue(object.save().isSuccess)
        
        let query = LCQuery(className: self.className)
        query.whereKey("objectId", .equalTo(object.objectId!))
        XCTAssertFalse(query.find().objects!.isEmpty)
    }
}
