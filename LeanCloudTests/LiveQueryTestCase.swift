//
//  LiveQueryTestCase.swift
//  LeanCloudTests
//
//  Created by pzheng on 2020/05/13.
//  Copyright © 2020 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LiveQueryTestCase: RTMBaseTestCase {
    
    func testUserLogin() {
        let appID = LCApplication.default.id!
        let appKey = LCApplication.default.key!
        let serverURL = LCApplication.default.serverURL!
        
        let application1 = try! LCApplication(
            id: appID,
            key: appKey,
            serverURL: serverURL)
        let application2 = try! LCApplication(
            id: appID,
            key: appKey,
            serverURL: serverURL)
        
        let username = uuid
        let password = uuid
        let user = LCUser(application: application1)
        user.username = username.lcString
        user.password = password.lcString
        let userSignUpResult = user.signUp()
        XCTAssertNil(userSignUpResult.error)
        
        let user1LogInResult = LCUser.logIn(
            application: application1,
            username: username,
            password: password)
        XCTAssertNil(user1LogInResult.error)
        
        if let objectId = user.objectId?.value,
            let user1 = user1LogInResult.object,
            let _ = user1.sessionToken,
            user1 === application1.currentUser {
            var liveQuery1: LiveQuery!
            var liveQuery2: LiveQuery!
            expecting(
                description: "user login",
                count: 4)
            { (exp) in
                liveQuery1 = try! LiveQuery(
                    application: application1,
                    query: {
                        let query = LCQuery(
                            application: application1,
                            className: LCUser.objectClassName())
                        query.whereKey("objectId", .equalTo(objectId))
                        return query
                }())
                { (_, event) in
                    switch event {
                    case .login(user: let user):
                        XCTAssertEqual(user.objectId?.value, objectId)
                        exp.fulfill()
                    default:
                        break
                    }
                }
                
                liveQuery1.subscribe { (result) in
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    exp.fulfill()
                    
                    liveQuery2 = try! LiveQuery(
                        application: application1,
                        query: {
                            let query = LCQuery(
                                application: application1,
                                className: LCUser.objectClassName())
                            query.whereKey("createdAt", .existed)
                            return query
                    }())
                    { (_, event) in
                        switch event {
                        case .login(user: let user):
                            XCTAssertEqual(user.objectId?.value, objectId)
                            exp.fulfill()
                        default:
                            break
                        }
                    }
                    
                    liveQuery2.subscribe { (result) in
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertTrue(result.isSuccess)
                        XCTAssertNil(result.error)
                        exp.fulfill()
                        
                        let user2LogInResult = LCUser.logIn(
                            application: application2,
                            username: username,
                            password: password)
                        XCTAssertNil(user2LogInResult.error)
                    }
                }
            }
        } else {
            XCTFail()
        }
        
        application1.unregister()
        application2.unregister()
    }
}
