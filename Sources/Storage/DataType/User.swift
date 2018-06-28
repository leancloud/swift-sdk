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
    @objc open private(set) dynamic var emailVerified: LCBool?

    /**
     Mobile phone number.

     If the "Enable Mobile Phone Number Verification" application option is enabled,
     an sms message will be sent to user's phone when user registered with a phone number.
     */
    @objc open dynamic var mobilePhoneNumber: LCString?

    /// A flag indicates whether mobile phone is verified or not.
    @objc open private(set) dynamic var mobilePhoneVerified: LCBool?

    /// Session token of user authenticated by server.
    @objc open private(set) dynamic var sessionToken: LCString?

    /// Current authenticated user.
    public static var current: LCUser? = nil

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
        HTTPClient.asynchronize({ self.signUp() }) { result in
            completion(result)
        }
    }

    /**
     Log in with username and password.
     
     - parameter username: The username.
     - parameter password: The password.

     - returns: The result of login request.
     */
    public static func logIn<User: LCUser>(username: String, password: String, application: LCApplication = .current ?? .default) -> LCObjectResult<User> {
        let parameters = [
            "username": username as AnyObject,
            "password": password as AnyObject
        ]
        return logIn(parameters: parameters, application: application)
    }

    /**
     Log in with username and password asynchronously.

     - parameter username:   The username.
     - parameter password:   The password.
     - parameter completion: The completion callback closure.
     */
    public static func logIn<User: LCUser>(username: String, password: String, application: LCApplication = .current ?? .default, completion: @escaping (LCObjectResult<User>) -> Void) {
        HTTPClient.asynchronize({ self.logIn(username: username, password: password, application: application) }) { result in
            completion(result)
        }
    }

    /**
     Log in with mobile phone number and password.

     - parameter username: The mobile phone number.
     - parameter password: The password.

     - returns: The result of login request.
     */
    public static func logIn<User: LCUser>(mobilePhoneNumber: String, password: String, application: LCApplication = .current ?? .default) -> LCObjectResult<User> {
        let parameters = [
            "mobilePhoneNumber": mobilePhoneNumber as AnyObject,
            "password": password as AnyObject
        ]
        return logIn(parameters: parameters, application: application)
    }

    /**
     Log in with mobile phone number and password asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter password:          The password.
     - parameter completion:        The completion callback closure.
     */
    public static func logIn<User: LCUser>(mobilePhoneNumber: String, password: String, application: LCApplication = .current ?? .default, completion: @escaping (LCObjectResult<User>) -> Void) {
        HTTPClient.asynchronize({ self.logIn(mobilePhoneNumber: mobilePhoneNumber, password: password, application: application) }) { result in
            completion(result)
        }
    }

    /**
     Log in with mobile phone number and verification code.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.

     - returns: The result of login request.
     */
    public static func logIn<User: LCUser>(mobilePhoneNumber: String, verificationCode: String, application: LCApplication = .current ?? .default) -> LCObjectResult<User> {
        let parameters = [
            "mobilePhoneNumber": mobilePhoneNumber as AnyObject,
            "smsCode": verificationCode as AnyObject
        ]
        return logIn(parameters: parameters, application: application)
    }

    /**
     Log in with mobile phone number and verification code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.
     - parameter completion:        The completion callback closure.
     */
    public static func logIn<User: LCUser>(mobilePhoneNumber: String, verificationCode: String, application: LCApplication = .current ?? .default, completion: @escaping (LCObjectResult<User>) -> Void) {
        HTTPClient.asynchronize({ self.logIn(mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode, application: application) }) { result in
            completion(result)
        }
    }

    /**
     Log in with session token.

     - parameter sessionToken: The session token.

     - returns: The result of login request.
     */
    public static func logIn<User: LCUser>(sessionToken: String, application: LCApplication = .current ?? .default) -> LCObjectResult<User> {
        let parameters = ["session_token": sessionToken]
        let endpoint   = HTTPClient.endpoint(objectClassName())
        let httpClient = HTTPClient(application: application)
        let response   = httpClient.request(.get, "\(endpoint)/me", parameters: parameters as [String: AnyObject])
        let result     = objectResult(response, application: application) as LCObjectResult<User>

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
    public static func logIn<User: LCUser>(sessionToken: String, application: LCApplication = .current ?? .default, completion: @escaping (LCObjectResult<User>) -> Void) {
        HTTPClient.asynchronize({ self.logIn(sessionToken: sessionToken, application: application) }) { result in
            completion(result)
        }
    }

    /**
     Log in with parameters.

     - parameter parameters: The parameters.

     - returns: The result of login request.
     */
    static func logIn<User: LCUser>(parameters: [String: AnyObject], application: LCApplication = .current ?? .default) -> LCObjectResult<User> {
        let httpClient = HTTPClient(application: application)
        let response   = httpClient.request(.post, "login", parameters: parameters)
        let result     = objectResult(response, application: application) as LCObjectResult<User>

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
    public static func signUpOrLogIn<User: LCUser>(mobilePhoneNumber: String, verificationCode: String, application: LCApplication = .current ?? .default) -> LCObjectResult<User> {
        let parameters = [
            "mobilePhoneNumber": mobilePhoneNumber,
            "smsCode": verificationCode
        ]

        let httpClient = HTTPClient(application: application)
        let response   = httpClient.request(.post, "usersByMobilePhone", parameters: parameters as [String: AnyObject])
        let result     = objectResult(response, application: application) as LCObjectResult<User>

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
    public static func signUpOrLogIn<User: LCUser>(mobilePhoneNumber: String, verificationCode: String, application: LCApplication = .current ?? .default, completion: @escaping (LCObjectResult<User>) -> Void) {
        HTTPClient.asynchronize({ self.signUpOrLogIn(mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode, application: application) }) { result in
            completion(result)
        }
    }

    /**
     Convert response to user object result.

     - parameter response: The response of login request.

     - returns: The user object result of reponse.
     */
    static func objectResult<User: LCUser>(_ response: LCResponse, application: LCApplication) -> LCObjectResult<User> {
        if let error = response.error {
            return .failure(error: error)
        }

        guard var dictionary = response.value as? [String: AnyObject] else {
            return .failure(error: LCError(code: .malformedData, reason: "Malformed user response data."))
        }

        /* Patch response data to fulfill object format. */
        dictionary["__type"]    = HTTPClient.DataType.object.rawValue as AnyObject?
        dictionary["className"] = LCUser.objectClassName() as AnyObject?

        let user = try! ObjectProfiler.object(jsonValue: dictionary as AnyObject, application: application) as! User

        return .success(object: user)
    }

    /**
     Log out current user.
     */
    public static func logOut() {
        current = nil
    }

    /**
     Request to send a verification mail to specified email address.

     - parameter email: The email address to where the mail will be sent.

     - returns: The result of verification request.
     */
    public static func requestVerificationMail(email: String, application: LCApplication = .current ?? .default) -> LCBooleanResult {
        let parameters = ["email": email]
        let httpClient = HTTPClient(application: application)
        let response   = httpClient.request(.post, "requestEmailVerify", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Request to send a verification mail to specified email address asynchronously.

     - parameter email:      The email address to where the mail will be sent.
     - parameter completion: The completion callback closure.
     */
    public static func requestVerificationMail(email: String, application: LCApplication = .current ?? .default, completion: @escaping (LCBooleanResult) -> Void) {
        HTTPClient.asynchronize({ self.requestVerificationMail(email: email, application: application) }) { result in
            completion(result)
        }
    }

    /**
     Request to send a verification code to specified mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number where the verification code will be sent to.

     - returns: The result of request.
     */
    public static func requestVerificationCode(mobilePhoneNumber: String, application: LCApplication = .current ?? .default) -> LCBooleanResult {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let httpClient = HTTPClient(application: application)
        let response   = httpClient.request(.post, "requestMobilePhoneVerify", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Request to send a verification code to specified mobile phone number asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where the verification code will be sent to.
     - parameter completion:        The completion callback closure.
     */
    public static func requestVerificationCode(mobilePhoneNumber: String, application: LCApplication = .current ?? .default, completion: @escaping (LCBooleanResult) -> Void) {
        HTTPClient.asynchronize({ self.requestVerificationCode(mobilePhoneNumber: mobilePhoneNumber, application: application) }) { result in
            completion(result)
        }
    }

    /**
     Verify a mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.

     - returns: The result of verification request.
     */
    public static func verifyMobilePhoneNumber(_ mobilePhoneNumber: String, verificationCode: String, application: LCApplication = .current ?? .default) -> LCBooleanResult {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let httpClient = HTTPClient(application: application)
        let response   = httpClient.request(.get, "verifyMobilePhone/\(verificationCode)", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Verify mobile phone number with code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.
     - parameter completion:        The completion callback closure.
     */
    public static func verifyMobilePhoneNumber(_ mobilePhoneNumber: String, verificationCode: String, application: LCApplication = .current ?? .default, completion: @escaping (LCBooleanResult) -> Void) {
        HTTPClient.asynchronize({ self.verifyMobilePhoneNumber(mobilePhoneNumber, verificationCode: verificationCode, application: application) }) { result in
            completion(result)
        }
    }

    /**
     Request a verification code for login with mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number where the verification code will be sent to.

     - returns: The result of request.
     */
    public static func requestLoginVerificationCode(mobilePhoneNumber: String, application: LCApplication = .current ?? .default) -> LCBooleanResult {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let httpClient = HTTPClient(application: application)
        let response   = httpClient.request(.post, "requestLoginSmsCode", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Request a verification code for login with mobile phone number asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where the verification code message will be sent to.
     - parameter completion:        The completion callback closure.
     */
    public static func requestLoginVerificationCode(mobilePhoneNumber: String, application: LCApplication = .current ?? .default, completion: @escaping (LCBooleanResult) -> Void) {
        HTTPClient.asynchronize({ self.requestLoginVerificationCode(mobilePhoneNumber: mobilePhoneNumber, application: application) }) { result in
            completion(result)
        }
    }

    /**
     Request password reset mail.

     - parameter email: The email address where the password reset mail will be sent to.

     - returns: The result of request.
     */
    public static func requestPasswordReset(email: String, application: LCApplication = .current ?? .default) -> LCBooleanResult {
        let parameters = ["email": email]
        let httpClient = HTTPClient(application: application)
        let response   = httpClient.request(.post, "requestPasswordReset", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Request password reset email asynchronously.

     - parameter email:      The email address where the password reset email will be sent to.
     - parameter completion: The completion callback closure.
     */
    public static func requestPasswordReset(email: String, application: LCApplication = .current ?? .default, completion: @escaping (LCBooleanResult) -> Void) {
        HTTPClient.asynchronize({ self.requestPasswordReset(email: email, application: application) }) { result in
            completion(result)
        }
    }

    /**
     Request password reset verification code.

     - parameter mobilePhoneNumber: The mobile phone number where the password reset verification code will be sent to.

     - returns: The result of request.
     */
    public static func requestPasswordReset(mobilePhoneNumber: String, application: LCApplication = .current ?? .default) -> LCBooleanResult {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let httpClient = HTTPClient(application: application)
        let response   = httpClient.request(.post, "requestPasswordResetBySmsCode", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Request password reset verification code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where the password reset verification code will be sent to.
     - parameter completion:        The completion callback closure.
     */
    public static func requestPasswordReset(mobilePhoneNumber: String, application: LCApplication = .current ?? .default, completion: @escaping (LCBooleanResult) -> Void) {
        HTTPClient.asynchronize({ self.requestPasswordReset(mobilePhoneNumber: mobilePhoneNumber, application: application) }) { result in
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
    public static func resetPassword(mobilePhoneNumber: String, verificationCode: String, newPassword: String, application: LCApplication = .current ?? .default) -> LCBooleanResult {
        let parameters = [
            "mobilePhoneNumber": mobilePhoneNumber,
            "password": newPassword
        ]
        let httpClient = HTTPClient(application: application)
        let response   = httpClient.request(.put, "resetPasswordBySmsCode/\(verificationCode)", parameters: parameters as [String: AnyObject])
        return LCBooleanResult(response: response)
    }

    /**
     Reset password with verification code and new password asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number of user.
     - parameter verificationCode:  The verification code in password reset message.
     - parameter newPassword:       The new password.
     - parameter completion:        The completion callback closure.
     */
    public static func resetPassword(mobilePhoneNumber: String, verificationCode: String, newPassword: String, application: LCApplication = .current ?? .default, completion: @escaping (LCBooleanResult) -> Void) {
        HTTPClient.asynchronize({ self.resetPassword(mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode, newPassword: newPassword, application: application) }) { result in
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
        guard let endpoint = HTTPClient.eigenEndpoint(self) else {
            return .failure(error: LCError(code: .notFound, reason: "User not found."))
        }
        guard let sessionToken = sessionToken else {
            return .failure(error: LCError(code: .notFound, reason: "Session token not found."))
        }

        let parameters = [
            "old_password": oldPassword,
            "new_password": newPassword
        ]
        let headers  = [HTTPClient.HeaderFieldName.session: sessionToken.value]
        let response = httpClient.request(.put, endpoint + "/updatePassword", parameters: parameters as [String: AnyObject], headers: headers)

        if let error = response.error {
            return .failure(error: error)
        } else {
            if let dictionary = response.value as? [String: AnyObject] {
                ObjectProfiler.updateObject(self, dictionary, application: application)
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
        HTTPClient.asynchronize({ self.updatePassword(oldPassword: oldPassword, newPassword: newPassword) }) { result in
            completion(result)
        }
    }
}
