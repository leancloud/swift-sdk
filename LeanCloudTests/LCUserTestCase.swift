//
//  LCUserTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 7/4/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCUserTestCase: BaseTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSignUpAndLogIn() {
        let user = LCUser()
        let application = user.application

        let username = "user" + LeanCloud.Utility.uuid()
        let password = "qwerty"

        user.username = LCString(username)
        user.password = LCString(password)

        XCTAssertTrue(user.signUp().isSuccess)
        XCTAssertTrue(LCUser.logIn(username: username, password: password).isSuccess)
        XCTAssertNotNil(application.currentUser)
        
        let email = "\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))@qq.com"
        user.email = LCString(email)
        XCTAssertTrue(user.save().isSuccess)
        
        LCUser.logOut()
        
        XCTAssertTrue(LCUser.logIn(email: email, password: password).isSuccess)

        let current = application.currentUser!
        let sessionToken = current.sessionToken!.value
        let updatedAt = current.updatedAt!

        XCTAssertTrue(LCUser.logIn(sessionToken: sessionToken).isSuccess)

        let newPassword = "ytrewq"
        let result = current.updatePassword(oldPassword: password, newPassword: newPassword)

        XCTAssertTrue(result.isSuccess)
        XCTAssertNotEqual(current.sessionToken!.value, sessionToken)
        XCTAssertNotEqual(current.updatedAt, updatedAt)

        LCUser.logOut()
    }
    
    func testSignUpOrLogInByMobilePhoneNumberAndVerificationCode() {
        let mobilePhoneNumber = "18677777777"
        let verificationCode = "375586"
        XCTAssertTrue(LCUser.signUpOrLogIn(mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode).isSuccess)
    }

}
