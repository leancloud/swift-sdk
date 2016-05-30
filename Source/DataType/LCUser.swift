//
//  LCUser.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 5/7/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud user type.

 A base type of LeanCloud built-in user system.
 You can extend this class with custom properties.
 However, LCUser can be extended only once.
 */
public class LCUser: LCObject {
    /// Username of user.
    public dynamic var username: LCString?

    /**
     Password of user.

     - note: this property will not be filled in when fetched or logged in for security.
     */
    public dynamic var password: LCString?

    /**
     Email of user.

     If the "Enable Email Verification" application option is enabled,
     a verification email will be sent to user when user registered with an email address.
     */
    public dynamic var email: LCString?

    /// A flag indicates whether email is verified or not.
    public private(set) dynamic var emailVerified: LCBool?

    /**
     Mobile phone number.

     If the "Enable Mobile Phone Number Verification" application option is enabled,
     an sms message will be sent to user's phone when user registered with a phone number.
     */
    public dynamic var mobilePhoneNumber: LCString?

    /// A flag indicates whether mobile phone is verified or not.
    public private(set) dynamic var mobilePhoneVerified: LCBool?

    /// Session token of user authenticated by server.
    public private(set) dynamic var sessionToken: LCString?

    /// Current authenticated user.
    public static var current: LCUser? = nil

    public final override class func objectClassName() -> String {
        return "_User"
    }

    /**
     Sign up an user.

     - returns: The result of signing up request.
     */
    public func signUp() -> BooleanResult {
        return self.save()
    }

    /**
     Log in with username and password.
     
     - parameter username: The username.
     - parameter password: The password.

     - returns: The result of login request.
     */
    public static func logIn<User: LCUser>(username username: String, password: String) -> ObjectResult<User> {
        return logIn(parameters: [
            "username": username,
            "password": password
        ])
    }

    /**
     Log in with mobile phone number and password.

     - parameter username: The mobile phone number.
     - parameter password: The password.

     - returns: The result of login request.
     */
    public static func logIn<User: LCUser>(mobilePhoneNumber mobilePhoneNumber: String, password: String) -> ObjectResult<User> {
        return logIn(parameters: [
            "mobilePhoneNumber": mobilePhoneNumber,
            "password": password
        ])
    }

    /**
     Log in with mobile phone number and short code.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter shortCode:         The login short code.

     - returns: The result of login request.
     */
    public static func logIn<User: LCUser>(mobilePhoneNumber mobilePhoneNumber: String, shortCode: String) -> ObjectResult<User> {
        return logIn(parameters: [
            "mobilePhoneNumber": mobilePhoneNumber,
            "smsCode": shortCode
        ])
    }

    /**
     Log in with session token.

     - parameter sessionToken: The session token.

     - returns: The result of login request.
     */
    public static func logIn<User: LCUser>(sessionToken sessionToken: String) -> ObjectResult<User> {
        let parameters = ["session_token": sessionToken]
        let endpoint   = RESTClient.endpoint(objectClassName())
        let response   = RESTClient.request(.GET, "\(endpoint)/me", parameters: parameters)
        let result     = response.objectResult() as ObjectResult<User>

        if case let .Success(user) = result {
            LCUser.current = user
        }

        return result
    }

    /**
     Log in with parameters.

     - parameter parameters: The parameters.

     - returns: The result of login request.
     */
    static func logIn<User: LCUser>(parameters parameters: [String: AnyObject]) -> ObjectResult<User> {
        let response = RESTClient.request(.POST, "login", parameters: parameters)
        let result   = response.objectResult() as ObjectResult<User>

        if case let .Success(user) = result {
            LCUser.current = user
        }

        return result
    }

    /**
     Log out current user.
     */
    public static func logOut() {
        current = nil
    }

    /**
     Request to send a verification email to specified email address.

     - parameter email: The email address to where the email will be sent.

     - returns: The result of request.
     */
    public static func requestVerification(email email: String) -> BooleanResult {
        let parameters = ["email": email]
        let response   = RESTClient.request(.POST, "requestEmailVerify", parameters: parameters)
        return BooleanResult(response: response)
    }

    /**
     Request to send a verification short code to specified mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number where the verification short code will be sent to.

     - returns: The result of request.
     */
    public static func requestVerification(mobilePhoneNumber mobilePhoneNumber: String) -> BooleanResult {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let response   = RESTClient.request(.POST, "requestMobilePhoneVerify", parameters: parameters)
        return BooleanResult(response: response)
    }

    /**
     Verify mobile phone number with code.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter code:              The verification code.

     - returns: The result of verification request.
     */
    public static func verify(mobilePhoneNumber mobilePhoneNumber: String, shortCode: String) -> BooleanResult {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let response   = RESTClient.request(.GET, "verifyMobilePhone/\(shortCode)", parameters: parameters)
        return BooleanResult(response: response)
    }

    /**
     Request a short code for login with mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number where the short code message will be sent to.

     - returns: The result of request.
     */
    public static func requestLoginShortCode(mobilePhoneNumber mobilePhoneNumber: String) -> BooleanResult {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let response = RESTClient.request(.POST, "requestLoginSmsCode", parameters: parameters)
        return BooleanResult(response: response)
    }

    /**
     Request password reset email.

     - parameter email: The email address where the password reset email will be sent to.
     
     - returns: The result of request.
     */
    public static func requestPasswordReset(email email: String) -> BooleanResult {
        let parameters = ["email": email]
        let response   = RESTClient.request(.POST, "requestPasswordReset", parameters: parameters)
        return BooleanResult(response: response)
    }

    /**
     Request password reset short code.

     - parameter mobilePhoneNumber: The mobile phone number where the password reset short code will be sent to.

     - returns: The result of request.
     */
    public static func requestPasswordReset(mobilePhoneNumber mobilePhoneNumber: String) -> BooleanResult {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let response   = RESTClient.request(.POST, "requestPasswordResetBySmsCode", parameters: parameters)
        return BooleanResult(response: response)
    }

    /**
     Reset password with short code and new password.

     - note: 
     This method will reset password of `LCUser.current`.
     If `LCUser.current` is nil, in other words, no user logged in,
     password reset will be failed because of permission.

     - parameter shortCode:   The short code in password reset message.
     - parameter newPassword: The new password.

     - returns: The result of reset request.
     */
    public static func resetPassword(mobilePhoneNumber mobilePhoneNumber: String, shortCode: String, newPassword: String) -> BooleanResult {
        let parameters = [
            "mobilePhoneNumber": mobilePhoneNumber,
            "password": newPassword
        ]
        let response = RESTClient.request(.PUT, "resetPasswordBySmsCode/\(shortCode)", parameters: parameters)
        return BooleanResult(response: response)
    }
}