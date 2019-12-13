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
    
    func testSignUpAndLogIn() {
        let user = LCUser()
        let application = user.application

        let username = "user" + LeanCloud.Utility.uuid
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
    
    func testAuthDataLogin() {
        let user = LCUser()
        let authData: [String: Any] = [
            "access_token": UUID().uuidString,
            "openid": UUID().uuidString
        ]
        XCTAssertTrue(user.logIn(authData: authData, platform: .weixin).isSuccess)
        XCTAssertNotNil(user.authData)
        XCTAssertTrue(user.application.currentUser === user)
    }
    
    func testAuthDataLoginWithUnionID() {
        let user = LCUser()
        let authData: [String: Any] = [
            "access_token": UUID().uuidString,
            "openid": UUID().uuidString
        ]
        let unionID: String = UUID().uuidString
        XCTAssertTrue(user.logIn(authData: authData, platform: .custom(UUID().uuidString), unionID: unionID, unionIDPlatform: .weixin, options: [.mainAccount]).isSuccess)
        XCTAssertNotNil(user.authData)
        XCTAssertTrue(user.application.currentUser === user)
    }
    
    func testAuthDataLoginFailOnNotExist() {
        let user = LCUser()
        let authData: [String: Any] = [
            "access_token": UUID().uuidString,
            "openid": UUID().uuidString
        ]
        XCTAssertTrue(user.logIn(authData: authData, platform: .weixin, options: [.failOnNotExist]).isFailure)
    }
    
    func testAuthDataAssociate() {
        let user = LCUser()
        user.username = UUID().uuidString.lcString
        user.password = UUID().uuidString.lcString
        XCTAssertTrue(user.signUp().isSuccess)
        
        let authData: [String: Any] = [
            "access_token": UUID().uuidString,
            "openid": UUID().uuidString
        ]
        do {
            let result = try user.associate(authData: authData, platform: .weixin)
            XCTAssertTrue(result.isSuccess)
            XCTAssertNotNil(user.authData)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testAuthDataDisassociate() {
        let user = LCUser()
        let authData: [String: Any] = [
            "access_token": UUID().uuidString,
            "openid": UUID().uuidString
        ]
        XCTAssertTrue(user.logIn(authData: authData, platform: .weixin).isSuccess)
        XCTAssertNotNil(user.authData)
        XCTAssertTrue(user.application.currentUser === user)
        
        do {
            let result = try user.disassociate(authData: .weixin)
            XCTAssertTrue(result.isSuccess)
            XCTAssertTrue((user.authData ?? [:]).isEmpty)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testCache() {
        let username = UUID().uuidString
        let password = UUID().uuidString
        let signUpUser = LCUser()
        signUpUser.username = username.lcString
        signUpUser.password = password.lcString
        XCTAssertTrue(signUpUser.signUp()
            .isSuccess)
        XCTAssertTrue(LCUser.logIn(
            username: username,
            password: password)
            .isSuccess)
        XCTAssertNotNil(LCApplication.default.currentUser?.sessionToken?.value)
        let sessionToken = LCApplication.default.currentUser?.sessionToken?.value
        LCApplication.default._currentUser = nil
        XCTAssertEqual(
            sessionToken,
            LCApplication.default.currentUser?.sessionToken?.value)
        LCUser.logOut()
        XCTAssertNil(LCApplication.default.currentUser)
    }

}
