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
open class LCUser: LCObject {
    /// Username of user.
    @objc open dynamic var username: LCString?

    /**
     Password of user.

     - note: this property will not be filled in when fetched or logged in for security.
     */
    @objc open dynamic var password: LCString?

    /**
     Email of user.

     If the "Enable Email Verification" application option is enabled,
     a verification email will be sent to user when user registered with an email address.
     */
    @objc open dynamic var email: LCString?

    /// A flag indicates whether email is verified or not.
    @objc open fileprivate(set) dynamic var emailVerified: LCBool?

    /**
     Mobile phone number.

     If the "Enable Mobile Phone Number Verification" application option is enabled,
     an sms message will be sent to user's phone when user registered with a phone number.
     */
    @objc open dynamic var mobilePhoneNumber: LCString?

    /// A flag indicates whether mobile phone is verified or not.
    @objc open fileprivate(set) dynamic var mobilePhoneVerified: LCBool?

    /// Session token of user authenticated by server.
    @objc open fileprivate(set) dynamic var sessionToken: LCString?

    /// Current authenticated user.
    open static var current: LCUser? = nil

    public final override class func objectClassName() -> String {
        return "_User"
    }

    /**
     Sign up an user.

     - returns: The result of signing up request.
     */
    open func signUp() -> LCBooleanResult {
        return self.save()
    }

    /**
     Sign up an user asynchronously.

     - parameter completion: The completion callback closure.
     */
    open func signUp(_ completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.signUp() }) { result in
            completion(result)
        }
    }

    /**
     Log in with username and password.
     
     - parameter username: The username.
     - parameter password: The password.

     - returns: The result of login request.
     */
    open static func logIn<User: LCUser>(username: String, password: String) -> LCObjectResult<User> {
        return logIn(parameters: [
            "username": username as AnyObject,
            "password": password as AnyObject
        ])
    }

    /**
     Log in with username and password asynchronously.

     - parameter username:   The username.
     - parameter password:   The password.
     - parameter completion: The completion callback closure.
     */
    open static func logIn<User: LCUser>(username: String, password: String, completion: @escaping (LCObjectResult<User>) -> Void) {
        RESTClient.asynchronize({ self.logIn(username: username, password: password) }) { result in
            completion(result)
        }
    }

    /**
     Log in with mobile phone number and password.

     - parameter username: The mobile phone number.
     - parameter password: The password.

     - returns: The result of login request.
     */
    open static func logIn<User: LCUser>(mobilePhoneNumber: String, password: String) -> LCObjectResult<User> {
        return logIn(parameters: [
            "mobilePhoneNumber": mobilePhoneNumber as AnyObject,
            "password": password as AnyObject
        ])
    }

    /**
     Log in with mobile phone number and password asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter password:          The password.
     - parameter completion:        The completion callback closure.
     */
    open static func logIn<User: LCUser>(mobilePhoneNumber: String, password: String, completion: @escaping (LCObjectResult<User>) -> Void) {
        RESTClient.asynchronize({ self.logIn(mobilePhoneNumber: mobilePhoneNumber, password: password) }) { result in
            completion(result)
        }
    }

    /**
     Log in with mobile phone number and verification code.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.

     - returns: The result of login request.
     */
    open static func logIn<User: LCUser>(mobilePhoneNumber: String, verificationCode: String) -> LCObjectResult<User> {
        return logIn(parameters: [
            "mobilePhoneNumber": mobilePhoneNumber as AnyObject,
            "smsCode": verificationCode as AnyObject
        ])
    }

    /**
     Log in with mobile phone number and verification code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.
     - parameter completion:        The completion callback closure.
     */
    open static func logIn<User: LCUser>(mobilePhoneNumber: String, verificationCode: String, completion: @escaping (LCObjectResult<User>) -> Void) {
        RESTClient.asynchronize({ self.logIn(mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode) }) { result in
            completion(result)
        }
    }

    /**
     Log in with session token.

     - parameter sessionToken: The session token.

     - returns: The result of login request.
     */
    open static func logIn<User: LCUser>(sessionToken: String) -> LCObjectResult<User> {
        let parameters = ["session_token": sessionToken]
        let endpoint   = RESTClient.endpoint(objectClassName())
        let response   = RESTClient.request(.get, "\(endpoint)/me", parameters: parameters as [String: AnyObject])
        let result     = objectResult(response) as LCObjectResult<User>

        if case let .success(user) = result {
            LCUser.current = user
        }

        return result
    }

    /**
     Log in with session token asynchronously.

     - parameter sessionToken: The session token.
     - parameter completion:   The completion callback closure.
     */
    open static func logIn<User: LCUser>(sessionToken: String, completion: @escaping (LCObjectResult<User>) -> Void) {
        RESTClient.asynchronize({ self.logIn(sessionToken: sessionToken) }) { result in
            completion(result)
        }
    }

    /**
     Log in with parameters.

     - parameter parameters: The parameters.

     - returns: The result of login request.
     */
    static func logIn<User: LCUser>(parameters: [String: AnyObject]) -> LCObjectResult<User> {
        let response = RESTClient.request(.post, "login", parameters: parameters)
        let result   = objectResult(response) as LCObjectResult<User>

        if case let .success(user) = result {
            LCUser.current = user
        }

        return result
    }

    /**
     Sign up or log in with mobile phone number and verification code.

     This method will sign up a user automatically if user for mobile phone number not found.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.
     */
    open static func signUpOrLogIn<User: LCUser>(mobilePhoneNumber: String, verificationCode: String) -> LCObjectResult<User> {
        let parameters = [
            "mobilePhoneNumber": mobilePhoneNumber,
            "smsCode": verificationCode
        ]

        let response = RESTClient.request(.post, "usersByMobilePhone", parameters: parameters as [String: AnyObject])
        let result   = objectResult(response) as LCObjectResult<User>

        if case let .success(user) = result {
            LCUser.current = user
        }

        return result
    }

    /**
     Sign up or log in with mobile phone number and verification code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.
     - parameter completion:        The completion callback closure.
     */
    open static func signUpOrLogIn<User: LCUser>(mobilePhoneNumber: String, verificationCode: String, completion: @escaping (LCObjectResult<User>) -> Void) {
        RESTClient.asynchronize({ self.signUpOrLogIn(mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode) }) { result in
            completion(result)
        }
    }

    /**
     Convert response to user object result.

     - parameter response: The response of login request.

     - returns: The user object result of reponse.
     */
    static func objectResult<User: LCUser>(_ response: LCResponse) -> LCObjectResult<User> {
        if let error = response.error {
            return .failure(error: error)
        }

        guard var dictionary = response.value as? [String: AnyObject] else {
            return .failure(error: LCError(code: .malformedData, reason: "Malformed user response data."))
        }

        /* Patch response data to fulfill object format. */
        dictionary["__type"]    = RESTClient.DataType.object.rawValue as AnyObject?
        dictionary["className"] = LCUser.objectClassName() as AnyObject?

        let user = try! ObjectProfiler.object(jsonValue: dictionary as AnyObject) as! User

        return .success(object: user)
    }

    /**
     Log out current user.
     */
    open static func logOut() {
        current = nil
    }

    /**
     Request to send a verification mail to specified email address.

     - parameter email: The email address to where the mail will be sent.

     - returns: The result of verification request.
     */
    open static func requestVerificationMail(email: String) -> LCBooleanResult {
        let parameters = ["email": email]
        let response   = RESTClient.request(.post, "requestEmailVerify", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Request to send a verification mail to specified email address asynchronously.

     - parameter email:      The email address to where the mail will be sent.
     - parameter completion: The completion callback closure.
     */
    open static func requestVerificationMail(email: String, completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.requestVerificationMail(email: email) }) { result in
            completion(result)
        }
    }

    /**
     Request to send a verification code to specified mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number where the verification code will be sent to.

     - returns: The result of request.
     */
    open static func requestVerificationCode(mobilePhoneNumber: String) -> LCBooleanResult {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let response   = RESTClient.request(.post, "requestMobilePhoneVerify", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Request to send a verification code to specified mobile phone number asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where the verification code will be sent to.
     - parameter completion:        The completion callback closure.
     */
    open static func requestVerificationCode(mobilePhoneNumber: String, completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.requestVerificationCode(mobilePhoneNumber: mobilePhoneNumber) }) { result in
            completion(result)
        }
    }

    /**
     Verify a mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.

     - returns: The result of verification request.
     */
    open static func verifyMobilePhoneNumber(_ mobilePhoneNumber: String, verificationCode: String) -> LCBooleanResult {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let response   = RESTClient.request(.get, "verifyMobilePhone/\(verificationCode)", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Verify mobile phone number with code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.
     - parameter completion:        The completion callback closure.
     */
    open static func verifyMobilePhoneNumber(_ mobilePhoneNumber: String, verificationCode: String, completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.verifyMobilePhoneNumber(mobilePhoneNumber, verificationCode: verificationCode) }) { result in
            completion(result)
        }
    }

    /**
     Request a verification code for login with mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number where the verification code will be sent to.

     - returns: The result of request.
     */
    open static func requestLoginVerificationCode(mobilePhoneNumber: String) -> LCBooleanResult {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let response = RESTClient.request(.post, "requestLoginSmsCode", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Request a verification code for login with mobile phone number asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where the verification code message will be sent to.
     - parameter completion:        The completion callback closure.
     */
    open static func requestLoginVerificationCode(mobilePhoneNumber: String, completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.requestLoginVerificationCode(mobilePhoneNumber: mobilePhoneNumber) }) { result in
            completion(result)
        }
    }

    /**
     Request password reset mail.

     - parameter email: The email address where the password reset mail will be sent to.

     - returns: The result of request.
     */
    open static func requestPasswordReset(email: String) -> LCBooleanResult {
        let parameters = ["email": email]
        let response   = RESTClient.request(.post, "requestPasswordReset", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Request password reset email asynchronously.

     - parameter email:      The email address where the password reset email will be sent to.
     - parameter completion: The completion callback closure.
     */
    open static func requestPasswordReset(email: String, completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.requestPasswordReset(email: email) }) { result in
            completion(result)
        }
    }

    /**
     Request password reset verification code.

     - parameter mobilePhoneNumber: The mobile phone number where the password reset verification code will be sent to.

     - returns: The result of request.
     */
    open static func requestPasswordReset(mobilePhoneNumber: String) -> LCBooleanResult {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let response   = RESTClient.request(.post, "requestPasswordResetBySmsCode", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Request password reset verification code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where the password reset verification code will be sent to.
     - parameter completion:        The completion callback closure.
     */
    open static func requestPasswordReset(mobilePhoneNumber: String, completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.requestPasswordReset(mobilePhoneNumber: mobilePhoneNumber) }) { result in
            completion(result)
        }
    }

    /**
     Reset password with verification code and new password.

     - note: 
     This method will reset password of `LCUser.current`.
     If `LCUser.current` is nil, in other words, no user logged in,
     password reset will be failed because of permission.

     - parameter mobilePhoneNumber: The mobile phone number of user.
     - parameter verificationCode:  The verification code in password reset message.
     - parameter newPassword:       The new password.

     - returns: The result of reset request.
     */
    open static func resetPassword(mobilePhoneNumber: String, verificationCode: String, newPassword: String) -> LCBooleanResult {
        let parameters = [
            "mobilePhoneNumber": mobilePhoneNumber,
            "password": newPassword
        ]
        let response = RESTClient.request(.put, "resetPasswordBySmsCode/\(verificationCode)", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Reset password with verification code and new password asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number of user.
     - parameter verificationCode:  The verification code in password reset message.
     - parameter newPassword:       The new password.
     - parameter completion:        The completion callback closure.
     */
    open static func resetPassword(mobilePhoneNumber: String, verificationCode: String, newPassword: String, completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.resetPassword(mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode, newPassword: newPassword) }) { result in
            completion(result)
        }
    }

    /**
     Update password for user.

     - parameter oldPassword: The old password.
     - parameter newPassword: The new password.

     - returns: The result of update request.
     */
    open func updatePassword(oldPassword: String, newPassword: String) -> LCBooleanResult {
        guard let endpoint = RESTClient.eigenEndpoint(self) else {
            return .failure(error: LCError(code: .notFound, reason: "User not found."))
        }
        guard let sessionToken = sessionToken else {
            return .failure(error: LCError(code: .notFound, reason: "Session token not found."))
        }

        let parameters = [
            "old_password": oldPassword,
            "new_password": newPassword
        ]
        let headers  = [RESTClient.HeaderFieldName.session: sessionToken.value]
        let response = RESTClient.request(.put, endpoint + "/updatePassword", parameters: parameters as [String: AnyObject], headers: headers)

        if let error = response.error {
            return .failure(error: error)
        } else {
            if let dictionary = response.value as? [String: AnyObject] {
                ObjectProfiler.updateObject(self, dictionary)
            }
            return .success
        }
    }

    /**
     Update password for user asynchronously.

     - parameter oldPassword: The old password.
     - parameter newPassword: The new password.
     - parameter completion:  The completion callback closure.
     */
    open func updatePassword(oldPassword: String, newPassword: String, completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.updatePassword(oldPassword: oldPassword, newPassword: newPassword) }) { result in
            completion(result)
        }
    }
}
