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
    @objc dynamic public var username: LCString?

    /**
     Password of user.

     - note: this property will not be filled in when fetched or logged in for security.
     */
    @objc dynamic public var password: LCString?

    /**
     Email of user.

     If the "Enable Email Verification" application option is enabled,
     a verification email will be sent to user when user registered with an email address.
     */
    @objc dynamic public var email: LCString?

    /// A flag indicates whether email is verified or not.
    @objc dynamic public private(set) var emailVerified: LCBool?

    /**
     Mobile phone number.

     If the "Enable Mobile Phone Number Verification" application option is enabled,
     an sms message will be sent to user's phone when user registered with a phone number.
     */
    @objc dynamic public var mobilePhoneNumber: LCString?

    /// A flag indicates whether mobile phone is verified or not.
    @objc dynamic public private(set) var mobilePhoneVerified: LCBool?
    
    /// Auth Data of third party account.
    @objc dynamic public private(set) var authData: LCDictionary?

    /// Session token of user authenticated by server.
    @objc dynamic public private(set) var sessionToken: LCString?

    public final override class func objectClassName() -> String {
        return "_User"
    }
    
    // MARK: Sign up

    /**
     Sign up an user.

     - returns: The result of signing up request.
     */
    public func signUp() -> LCBooleanResult {
        return expect { fulfill in
            self.signUp(completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Sign up an user asynchronously.

     - parameter completion: The completion callback closure.
     */
    public func signUp(_ completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        return signUp(completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }
    
    @discardableResult
    private func signUp(completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        return type(of: self).save([self], options: [], completionInBackground: completion)
    }

    // MARK: Log in with username and password

    /**
     Log in with username and password.
     
     - parameter username: The username.
     - parameter password: The password.

     - returns: The result of login request.
     */
    public static func logIn<User: LCUser>(
        application: LCApplication = LCApplication.default,
        username: String,
        password: String)
        -> LCValueResult<User>
    {
        return expect { fulfill in
            logIn(application: application, username: username, password: password, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Log in with username and password asynchronously.

     - parameter username:   The username.
     - parameter password:   The password.
     - parameter completion: The completion callback closure.
     */
    public static func logIn<User: LCUser>(
        application: LCApplication = LCApplication.default,
        username: String,
        password: String,
        completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return logIn(application: application, username: username, password: password, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    @discardableResult
    private static func logIn<User: LCUser>(
        application: LCApplication,
        username: String,
        password: String,
        completionInBackground completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        let parameters = [
            "username": username,
            "password": password
        ]

        let request = logIn(application: application, parameters: parameters, completionInBackground: completion)

        return request
    }
    
    // MARK: Log in with email and password
    
    /// Log in with email and password.
    ///
    /// - Parameters:
    ///   - email: The email.
    ///   - password: The password.
    /// - Returns: The result of login request.
    public static func logIn<User: LCUser>(
        application: LCApplication = LCApplication.default,
        email: String,
        password: String)
        -> LCValueResult<User>
    {
        return expect { fulfill in
            logIn(application: application, email: email, password: password, completionInBackground: { result in
                fulfill(result)
            })
        }
    }
    
    /// Log in with email and password.
    ///
    /// - Parameters:
    ///   - email: The email.
    ///   - password: The password.
    ///   - completion: The completion callback closure.
    /// - Returns: The result of login request.
    public static func logIn<User: LCUser>(
        application: LCApplication = LCApplication.default,
        email: String,
        password: String,
        completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return logIn(application: application, email: email, password: password, completionInBackground: { (result) in
            mainQueueAsync {
                completion(result)
            }
        })
    }
    
    @discardableResult
    private static func logIn<User: LCUser>(
        application: LCApplication,
        email: String,
        password: String,
        completionInBackground completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        let parameters = [
            "email": email,
            "password": password
        ]
        
        let request = logIn(application: application, parameters: parameters, completionInBackground: completion)
        
        return request
    }

    // MARK: Log in with phone number and password

    /**
     Log in with mobile phone number and password.

     - parameter username: The mobile phone number.
     - parameter password: The password.

     - returns: The result of login request.
     */
    public static func logIn<User: LCUser>(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        password: String)
        -> LCValueResult<User>
    {
        return expect { fulfill in
            logIn(application: application, mobilePhoneNumber: mobilePhoneNumber, password: password, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Log in with mobile phone number and password asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter password:          The password.
     - parameter completion:        The completion callback closure.
     */
    public static func logIn<User: LCUser>(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        password: String,
        completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return logIn(application: application, mobilePhoneNumber: mobilePhoneNumber, password: password, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    @discardableResult
    private static func logIn<User: LCUser>(
        application: LCApplication,
        mobilePhoneNumber: String,
        password: String,
        completionInBackground completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        let parameters = [
            "password": password,
            "mobilePhoneNumber": mobilePhoneNumber
        ]

        let request = logIn(application: application, parameters: parameters, completionInBackground: completion)

        return request
    }

    // MARK: Log in with phone number and verification code

    /**
     Log in with mobile phone number and verification code.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.

     - returns: The result of login request.
     */
    public static func logIn<User: LCUser>(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        verificationCode: String)
        -> LCValueResult<User>
    {
        return expect { fulfill in
            logIn(application: application, mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Log in with mobile phone number and verification code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.
     - parameter completion:        The completion callback closure.
     */
    public static func logIn<User: LCUser>(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        verificationCode: String,
        completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return logIn(application: application, mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    @discardableResult
    private static func logIn<User: LCUser>(
        application: LCApplication,
        mobilePhoneNumber: String,
        verificationCode: String,
        completionInBackground completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        let parameters = [
            "smsCode": verificationCode,
            "mobilePhoneNumber": mobilePhoneNumber
        ]

        let request = logIn(application: application, parameters: parameters, completionInBackground: completion)

        return request
    }

    // MARK: Log in with parameters

    /**
     Log in with parameters asynchronously.

     - parameter parameters: The login parameters.
     - parameter completion: The completion callback, it will be called in background thread.

     - returns: A login request.
     */
    @discardableResult
    private static func logIn<User: LCUser>(
        application: LCApplication,
        parameters: [String: Any],
        completionInBackground completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        let request = application.httpClient.request(.post, "login", parameters: parameters) { response in
            let result = LCValueResult<User>(response: response)

            switch result {
            case .success(let user):
                application.currentUser = user
            case .failure:
                break
            }

            completion(result)
        }

        return request
    }

    // MARK: Log in with session token

    /**
     Log in with session token.

     - parameter sessionToken: The session token.

     - returns: The result of login request.
     */
    public static func logIn<User: LCUser>(
        application: LCApplication = LCApplication.default,
        sessionToken: String)
        -> LCValueResult<User>
    {
        return expect { fulfill in
            logIn(application: application, sessionToken: sessionToken, completionInBackground: { (result: LCValueResult<User>) in
                fulfill(result)
            })
        }
    }

    /**
     Log in with session token asynchronously.

     - parameter sessionToken: The session token.
     - parameter completion:   The completion callback closure, it will be called in main thread.
     */
    public static func logIn<User: LCUser>(
        application: LCApplication = LCApplication.default,
        sessionToken: String,
        completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return logIn(application: application, sessionToken: sessionToken, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    /**
     Log in with session token asynchronously.

     - parameter sessionToken: The session token.
     - parameter completion:   The completion callback closure, it will be called in a background thread.
     */
    @discardableResult
    private static func logIn<User: LCUser>(
        application: LCApplication,
        sessionToken: String,
        completionInBackground completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        let httpClient: HTTPClient = application.httpClient
        let className = objectClassName()
        let classEndpoint = httpClient.getClassEndpoint(className: className)

        let endpoint = "\(classEndpoint)/me"
        let parameters = ["session_token": sessionToken]

        let request = httpClient.request(.get, endpoint, parameters: parameters) { response in
            let result = LCValueResult<User>(response: response)

            switch result {
            case .success(let user):
                application.currentUser = user
            case .failure:
                break
            }

            completion(result)
        }

        return request
    }

    // MARK: Sign up or log in with phone number and verification code

    /**
     Sign up or log in with mobile phone number and verification code.

     This method will sign up a user automatically if user for mobile phone number not found.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.
     */
    public static func signUpOrLogIn<User: LCUser>(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        verificationCode: String)
        -> LCValueResult<User>
    {
        return expect { fulfill in
            signUpOrLogIn(application: application, mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Sign up or log in with mobile phone number and verification code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.
     - parameter completion:        The completion callback closure.
     */
    public static func signUpOrLogIn<User: LCUser>(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        verificationCode: String,
        completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return signUpOrLogIn(application: application, mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    @discardableResult
    private static func signUpOrLogIn<User: LCUser>(
        application: LCApplication,
        mobilePhoneNumber: String,
        verificationCode: String,
        completionInBackground completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        let parameters = [
            "smsCode": verificationCode,
            "mobilePhoneNumber": mobilePhoneNumber
        ]

        let request = application.httpClient.request(.post, "usersByMobilePhone", parameters: parameters) { response in
            let result = LCValueResult<User>(response: response)

            switch result {
            case .success(let user):
                application.currentUser = user
            case .failure:
                break
            }

            completion(result)
        }

        return request
    }

    /**
     Log out current user.
     */
    public static func logOut(application: LCApplication = LCApplication.default) {
        application.currentUser = nil
    }

    // MARK: Send verification mail

    /**
     Request to send a verification mail to specified email address.

     - parameter email: The email address to where the mail will be sent.

     - returns: The result of verification request.
     */
    public static func requestVerificationMail(
        application: LCApplication = LCApplication.default,
        email: String)
        -> LCBooleanResult
    {
        return expect { fulfill in
            requestVerificationMail(application: application, email: email, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Request to send a verification mail to specified email address asynchronously.

     - parameter email:      The email address to where the mail will be sent.
     - parameter completion: The completion callback closure.
     */
    public static func requestVerificationMail(
        application: LCApplication = LCApplication.default,
        email: String,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return requestVerificationMail(application: application, email: email, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    @discardableResult
    private static func requestVerificationMail(
        application: LCApplication,
        email: String,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let parameters = ["email": email]
        let request = application.httpClient.request(.post, "requestEmailVerify", parameters: parameters) { response in
            completion(LCBooleanResult(response: response))
        }
        return request
    }

    // MARK: Send verification code

    /**
     Request to send a verification code to specified mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number where the verification code will be sent to.

     - returns: The result of request.
     */
    public static func requestVerificationCode(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String)
        -> LCBooleanResult
    {
        return expect { fulfill in
            requestVerificationCode(application: application, mobilePhoneNumber: mobilePhoneNumber, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Request to send a verification code to specified mobile phone number asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where the verification code will be sent to.
     - parameter completion:        The completion callback closure.
     */
    public static func requestVerificationCode(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return requestVerificationCode(application: application, mobilePhoneNumber: mobilePhoneNumber, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    @discardableResult
    private static func requestVerificationCode(
        application: LCApplication,
        mobilePhoneNumber: String,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let request = application.httpClient.request(.post, "requestMobilePhoneVerify", parameters: parameters) { response in
            completion(LCBooleanResult(response: response))
        }
        return request
    }

    // MARK: Verify phone number

    /**
     Verify a mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.

     - returns: The result of verification request.
     */
    public static func verifyMobilePhoneNumber(
        application: LCApplication = LCApplication.default,
        _ mobilePhoneNumber: String,
        verificationCode: String)
        -> LCBooleanResult
    {
        return expect { fulfill in
            verifyMobilePhoneNumber(application: application, mobilePhoneNumber, verificationCode: verificationCode, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Verify mobile phone number with code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number.
     - parameter verificationCode:  The verification code.
     - parameter completion:        The completion callback closure.
     */
    public static func verifyMobilePhoneNumber(
        application: LCApplication = LCApplication.default,
        _ mobilePhoneNumber: String,
        verificationCode: String,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return verifyMobilePhoneNumber(application: application, mobilePhoneNumber, verificationCode: verificationCode, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    @discardableResult
    private static func verifyMobilePhoneNumber(
        application: LCApplication,
        _ mobilePhoneNumber: String,
        verificationCode: String,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let request = application.httpClient.request(.get, "verifyMobilePhone/\(verificationCode)", parameters: parameters) { response in
            completion(LCBooleanResult(response: response))
        }
        return request
    }

    // MARK: Send a login verification code

    /**
     Request a verification code for login with mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number where the verification code will be sent to.

     - returns: The result of request.
     */
    public static func requestLoginVerificationCode(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String)
        -> LCBooleanResult
    {
        return expect { fulfill in
            requestLoginVerificationCode(application: application, mobilePhoneNumber: mobilePhoneNumber, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Request a verification code for login with mobile phone number asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where the verification code message will be sent to.
     - parameter completion:        The completion callback closure.
     */
    public static func requestLoginVerificationCode(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return requestLoginVerificationCode(application: application, mobilePhoneNumber: mobilePhoneNumber, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    @discardableResult
    private static func requestLoginVerificationCode(
        application: LCApplication,
        mobilePhoneNumber: String,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let request = application.httpClient.request(.post, "requestLoginSmsCode", parameters: parameters) { response in
            completion(LCBooleanResult(response: response))
        }

        return request
    }

    // MARK: Send password reset mail

    /**
     Request password reset mail.

     - parameter email: The email address where the password reset mail will be sent to.

     - returns: The result of request.
     */
    public static func requestPasswordReset(
        application: LCApplication = LCApplication.default,
        email: String)
        -> LCBooleanResult
    {
        return expect { fulfill in
            requestPasswordReset(application: application, email: email, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Request password reset email asynchronously.

     - parameter email:      The email address where the password reset email will be sent to.
     - parameter completion: The completion callback closure.
     */
    public static func requestPasswordReset(
        application: LCApplication = LCApplication.default,
        email: String,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return requestPasswordReset(application: application, email: email, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    @discardableResult
    private static func requestPasswordReset(
        application: LCApplication,
        email: String,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let parameters = ["email": email]
        let request = application.httpClient.request(.post, "requestPasswordReset", parameters: parameters) { response in
            completion(LCBooleanResult(response: response))
        }

        return request
    }

    // MARK: Send password reset short message

    /**
     Request password reset verification code.

     - parameter mobilePhoneNumber: The mobile phone number where the password reset verification code will be sent to.

     - returns: The result of request.
     */
    public static func requestPasswordReset(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String)
        -> LCBooleanResult
    {
        return expect { fulfill in
            requestPasswordReset(application: application, mobilePhoneNumber: mobilePhoneNumber, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Request password reset verification code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where the password reset verification code will be sent to.
     - parameter completion:        The completion callback closure.
     */
    public static func requestPasswordReset(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return requestPasswordReset(application: application, mobilePhoneNumber: mobilePhoneNumber, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    @discardableResult
    private static func requestPasswordReset(
        application: LCApplication,
        mobilePhoneNumber: String,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let parameters = ["mobilePhoneNumber": mobilePhoneNumber]
        let request = application.httpClient.request(.post, "requestPasswordResetBySmsCode", parameters: parameters) { response in
            completion(LCBooleanResult(response: response))
        }

        return request
    }

    // MARK: Reset password with verification code and new password

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
    public static func resetPassword(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        verificationCode: String,
        newPassword: String)
        -> LCBooleanResult
    {
        return expect { fulfill in
            resetPassword(application: application, mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode, newPassword: newPassword, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Reset password with verification code and new password asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number of user.
     - parameter verificationCode:  The verification code in password reset message.
     - parameter newPassword:       The new password.
     - parameter completion:        The completion callback closure.
     */
    public static func resetPassword(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        verificationCode: String,
        newPassword: String,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return resetPassword(application: application, mobilePhoneNumber: mobilePhoneNumber, verificationCode: verificationCode, newPassword: newPassword, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    @discardableResult
    private static func resetPassword(
        application: LCApplication,
        mobilePhoneNumber: String,
        verificationCode: String,
        newPassword: String,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let parameters = [
            "password": newPassword,
            "mobilePhoneNumber": mobilePhoneNumber
        ]
        let request = application.httpClient.request(.put, "resetPasswordBySmsCode/\(verificationCode)", parameters: parameters) { response in
            completion(LCBooleanResult(response: response))
        }

        return request
    }

    // MARK: Update password with new password

    /**
     Update password for user.

     - parameter oldPassword: The old password.
     - parameter newPassword: The new password.

     - returns: The result of update request.
     */
    public func updatePassword(oldPassword: String, newPassword: String) -> LCBooleanResult {
        return expect { fulfill in
            self.updatePassword(oldPassword: oldPassword, newPassword: newPassword, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Update password for user asynchronously.

     - parameter oldPassword: The old password.
     - parameter newPassword: The new password.
     - parameter completion:  The completion callback closure.
     */
    public func updatePassword(oldPassword: String, newPassword: String, completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        return updatePassword(oldPassword: oldPassword, newPassword: newPassword, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    @discardableResult
    private func updatePassword(oldPassword: String, newPassword: String, completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        let httpClient: HTTPClient = self.application.httpClient
        
        guard let endpoint = httpClient.getObjectEndpoint(object: self) else {
            return httpClient.request(
                error: LCError(code: .notFound, reason: "User not found."),
                completionHandler: completion)
        }
        guard let sessionToken = sessionToken else {
            return httpClient.request(
                error: LCError(code: .notFound, reason: "Session token not found."),
                completionHandler: completion)
        }

        let parameters = [
            "old_password": oldPassword,
            "new_password": newPassword
        ]
        let headers = [HTTPClient.HeaderFieldName.session: sessionToken.value]

        let request = httpClient.request(.put, "\(endpoint)/updatePassword", parameters: parameters, headers: headers) { response in
            if let error = LCError(response: response) {
                completion(.failure(error: error))
            } else {
                if let dictionary = response.value as? [String: Any] {
                    ObjectProfiler.shared.updateObject(self, dictionary)
                }
                completion(.success)
            }
        }

        return request
    }
    
    // MARK: Auth Data
    
    public enum AuthDataPlatform {
        case qq
        case weibo
        case weixin
        case custom(_ key: String)
        
        public var key: String {
            switch self {
            case .qq:
                return "qq"
            case .weibo:
                return "weibo"
            case .weixin:
                return "weixin"
            case .custom(let key):
                return key
            }
        }
    }
    
    public struct AuthDataOptions: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let mainAccount = AuthDataOptions(rawValue: 1 << 0)
        
        public static let failOnNotExist = AuthDataOptions(rawValue: 1 << 1)
    }
    
    public func logIn(
        authData: [String: Any],
        platform: AuthDataPlatform,
        unionID: String? = nil,
        unionIDPlatform: AuthDataPlatform? = nil,
        options: AuthDataOptions? = nil)
        -> LCBooleanResult
    {
        return expect { fulfill in
            self.logIn(
                authData: authData,
                platform: platform,
                unionID: unionID,
                unionIDPlatform: unionIDPlatform,
                options: options,
                completionInBackground: { fulfill($0) }
            )
        }
    }
    
    @discardableResult
    public func logIn(
        authData: [String: Any],
        platform: AuthDataPlatform,
        unionID: String? = nil,
        unionIDPlatform: AuthDataPlatform? = nil,
        options: AuthDataOptions? = nil,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.logIn(
            authData: authData,
            platform: platform,
            unionID: unionID,
            unionIDPlatform: unionIDPlatform,
            options: options,
            completionInBackground: { (result) in mainQueueAsync { completion(result) } }
        )
    }
    
    @discardableResult
    private func logIn(
        authData: [String: Any],
        platform: AuthDataPlatform,
        unionID: String?,
        unionIDPlatform: AuthDataPlatform?,
        options: AuthDataOptions?,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        var authData: [String: Any] = authData
        if let unionID: String = unionID {
            authData["unionid"] = unionID
        }
        if let unionIDPlatform: AuthDataPlatform = unionIDPlatform {
            authData["platform"] = unionIDPlatform.key
        }
        if let options: AuthDataOptions = options, options.contains(.mainAccount) {
            authData["main_account"] = true
        }
        
        var parameters = (self.dictionary.jsonValue as? [String: Any]) ?? [:]
        parameters["authData"] = [platform.key: authData]
        
        let path: String
        if let options = options, options.contains(.failOnNotExist) {
            path = "users?failOnNotExist=true"
        } else {
            path = "users"
        }
        
        let request = self.application.httpClient.request(.post, path, parameters: parameters) { response in
            if let error = LCError(response: response) {
                completion(.failure(error: error))
            } else {
                if let dictionary = response.value as? [String: Any] {
                    
                    ObjectProfiler.shared.updateObject(self, dictionary)
                    self.application.currentUser = self
                    
                    completion(.success)
                } else {
                    let error = LCError(code: .invalidType, reason: "invalid response data type.")
                    completion(.failure(error: error))
                }
            }
        }
        
        return request
    }
    
    public func associate(
        authData: [String: Any],
        platform: AuthDataPlatform,
        unionID: String? = nil,
        unionIDPlatform: AuthDataPlatform? = nil,
        options: AuthDataOptions? = nil)
        throws
        -> LCBooleanResult
    {
        return try expect { fulfill in
            try self.associate(
                authData: authData,
                platform: platform,
                unionID: unionID,
                unionIDPlatform: unionIDPlatform,
                options: options,
                completionInBackground: { fulfill($0) }
            )
        }
    }
    
    @discardableResult
    public func associate(
        authData: [String: Any],
        platform: AuthDataPlatform,
        unionID: String? = nil,
        unionIDPlatform: AuthDataPlatform? = nil,
        options: AuthDataOptions? = nil,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
        -> LCRequest
    {
        return try self.associate(
            authData: authData,
            platform: platform,
            unionID: unionID,
            unionIDPlatform: unionIDPlatform,
            options: options,
            completionInBackground: { result in mainQueueAsync { completion(result) } }
        )
    }
    
    @discardableResult
    private func associate(
        authData: [String: Any],
        platform: AuthDataPlatform,
        unionID: String?,
        unionIDPlatform: AuthDataPlatform?,
        options: AuthDataOptions?,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        throws
        -> LCRequest
    {
        guard let objectID: String = self.objectId?.stringValue else {
            throw LCError(code: .inconsistency, reason: "object id not found.")
        }
        guard let sessionToken: String = self.sessionToken?.stringValue else {
            throw LCError(code: .inconsistency, reason: "session token not found.")
        }
        
        var authData: [String: Any] = authData
        if let unionID: String = unionID {
            authData["unionid"] = unionID
        }
        if let unionIDPlatform: AuthDataPlatform = unionIDPlatform {
            authData["platform"] = unionIDPlatform.key
        }
        if let options: AuthDataOptions = options, options.contains(.mainAccount) {
            authData["main_account"] = true
        }
        
        let path: String = "users/\(objectID)"
        let parameters: [String: Any] = ["authData": [platform.key : authData]]
        let headers: [String: String] = [HTTPClient.HeaderFieldName.session: sessionToken]
        
        let request = self.application.httpClient.request(.put, path, parameters: parameters, headers: headers) { response in
            if let error = LCError(response: response) {
                completion(.failure(error: error))
            } else {
                if var dictionary = response.value as? [String: Any] {
                    var originAuthData: [String: Any] = (self.authData?.jsonValue as? [String: Any]) ?? [:]
                    originAuthData[platform.key] = authData
                    dictionary["authData"] = originAuthData
                    ObjectProfiler.shared.updateObject(self, dictionary)
                    completion(.success)
                } else {
                    let error = LCError(code: .invalidType, reason: "invalid response data type.")
                    completion(.failure(error: error))
                }
            }
        }
        
        return request
    }
    
    public func disassociate(authData platform: AuthDataPlatform) throws -> LCBooleanResult {
        return try expect { fulfill in
            try self.disassociate(
                authData: platform,
                completionInBackground: { fulfill($0) }
            )
        }
    }
    
    @discardableResult
    public func disassociate(
        authData platform: AuthDataPlatform,
        completion: @escaping (LCBooleanResult) -> Void)
        throws
        -> LCRequest
    {
        return try self.disassociate(
            authData: platform,
            completionInBackground: { result in mainQueueAsync { completion(result) } }
        )
    }
    
    @discardableResult
    private func disassociate(
        authData platform: AuthDataPlatform,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        throws
        -> LCRequest
    {
        guard let objectID: String = self.objectId?.stringValue else {
            throw LCError(code: .inconsistency, reason: "object id not found.")
        }
        guard let sessionToken: String = self.sessionToken?.stringValue else {
            throw LCError(code: .inconsistency, reason: "session token not found.")
        }
        
        let path: String = "users/\(objectID)"
        let parameters: [String: Any] = ["authData.\(platform.key)": [Operation.key: Operation.Name.delete.rawValue]]
        let headers: [String: String] = [HTTPClient.HeaderFieldName.session: sessionToken]
        
        let request = self.application.httpClient.request(.put, path, parameters: parameters, headers: headers) { response in
            if let error = LCError(response: response) {
                completion(.failure(error: error))
            } else {
                if var dictionary = response.value as? [String: Any] {
                    var originAuthData: [String: Any] = (self.authData?.jsonValue as? [String: Any]) ?? [:]
                    originAuthData.removeValue(forKey: platform.key)
                    dictionary["authData"] = originAuthData
                    ObjectProfiler.shared.updateObject(self, dictionary)
                    completion(.success)
                } else {
                    let error = LCError(code: .invalidType, reason: "invalid response data type.")
                    completion(.failure(error: error))
                }
            }
        }
        
        return request
    }
}
