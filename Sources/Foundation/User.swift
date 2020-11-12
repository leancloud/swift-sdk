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
    
    // MARK: Cache
    
    struct CacheTable: Codable {
        let jsonString: String
        let applicationID: String
        
        enum CodingKeys: String, CodingKey {
            case jsonString = "json_string"
            case applicationID = "application_id"
        }
    }
    
    static func saveCurrentUser(application: LCApplication, user: LCUser?) {
        guard let context = application.localStorageContext,
            let fileURL = application.currentUserFileURL else {
                return
        }
        do {
            if let user = user {
                try context.save(
                    table: CacheTable(
                        jsonString: user.jsonString,
                        applicationID: application.id),
                    to: fileURL)
            } else {
                try context.clear(
                    file: fileURL)
            }
        } catch {
            Logger.shared.error(error)
        }
    }
    
    static func currentUser(application: LCApplication) -> LCUser? {
        do {
            guard let fileURL = application.currentUserFileURL,
                let context = application.localStorageContext,
                let table: CacheTable = try context.table(from: fileURL),
                table.applicationID == application.id,
                let data = table.jsonString.data(using: .utf8),
                let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return nil
            }
            let dictionary = try LCDictionary(
                application: application,
                unsafeObject: jsonObject)
            return LCUser(
                application: application,
                dictionary: dictionary)
        } catch {
            Logger.shared.error(error)
            return nil
        }
    }
    
    func trySaveToLocal() {
        if self === self.application._currentUser {
            self.application.currentUser = self
        }
    }
    
    // MARK: Sign up
    
    /// Sign up an user synchronously.
    public func signUp() -> LCBooleanResult {
        return expect { fulfill in
            self.signUp(completionInBackground: { result in
                fulfill(result)
            })
        }
    }
    
    /// Sign up an user asynchronously.
    /// - Parameters:
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public func signUp(
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.signUp(completionInBackground: { result in
            completionQueue.async {
                completion(result)
            }
        })
    }
    
    @discardableResult
    private func signUp(completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        return type(of: self).save([self], options: [], completionInBackground: completion)
    }

    // MARK: Log in with username and password
    
    /// Log in with username and password synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - username: The name of the user.
    ///   - password: The password of the user.
    public static func logIn<User: LCUser>(application: LCApplication = .default, username: String, password: String) -> LCValueResult<User> {
        return expect { fulfill in
            self.logIn(
                application: application,
                username: username,
                password: password,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Log in with username and password asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - username: The name of the user.
    ///   - password: The password of the user.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func logIn<User: LCUser>(
        application: LCApplication = .default,
        username: String,
        password: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return self.logIn(
            application: application,
            username: username,
            password: password,
            completionInBackground: { result in
                completionQueue.async {
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
        return self.logIn(
            application: application,
            parameters: [
                "username": username,
                "password": password],
            completionInBackground: completion)
    }
    
    // MARK: Log in with email and password
    
    /// Log in with email and password synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - email: The email of the user.
    ///   - password: The password of the user.
    public static func logIn<User: LCUser>(application: LCApplication = .default, email: String, password: String) -> LCValueResult<User> {
        return expect { fulfill in
            self.logIn(
                application: application,
                email: email,
                password: password,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Log in with email and password asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - email: The email of the user.
    ///   - password: The password of the user.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func logIn<User: LCUser>(
        application: LCApplication = .default,
        email: String,
        password: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return self.logIn(
            application: application,
            email: email,
            password: password,
            completionInBackground: { (result) in
                completionQueue.async {
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
        return self.logIn(
            application: application,
            parameters: [
                "email": email,
                "password": password],
            completionInBackground: completion)
    }

    // MARK: Log in with phone number and password
    
    /// Log in with mobile phone number and password synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number of the user.
    ///   - password: The password of the user.
    public static func logIn<User: LCUser>(application: LCApplication = .default, mobilePhoneNumber: String, password: String) -> LCValueResult<User> {
        return expect { fulfill in
            self.logIn(
                application: application,
                mobilePhoneNumber: mobilePhoneNumber,
                password: password,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Log in with mobile phone number and password asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number of the user.
    ///   - password: The password of the user.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func logIn<User: LCUser>(
        application: LCApplication = .default,
        mobilePhoneNumber: String,
        password: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return self.logIn(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber,
            password: password,
            completionInBackground: { result in
                completionQueue.async {
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
        return self.logIn(
            application: application,
            parameters: [
                "password": password,
                "mobilePhoneNumber": mobilePhoneNumber],
            completionInBackground: completion)
    }

    // MARK: Log in with phone number and verification code
    
    /// Log in with mobile phone number and verification code synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number of the user.
    ///   - verificationCode: The verification code sent to `mobilePhoneNumber`.
    public static func logIn<User: LCUser>(application: LCApplication = .default, mobilePhoneNumber: String, verificationCode: String) -> LCValueResult<User> {
        return expect { fulfill in
            self.logIn(
                application: application,
                mobilePhoneNumber: mobilePhoneNumber,
                verificationCode: verificationCode,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Log in with mobile phone number and verification code asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number of the user.
    ///   - verificationCode: The verification code sent to `mobilePhoneNumber`.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func logIn<User: LCUser>(
        application: LCApplication = .default,
        mobilePhoneNumber: String,
        verificationCode: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return self.logIn(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber,
            verificationCode: verificationCode,
            completionInBackground: { result in
                completionQueue.async {
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
        return self.logIn(
            application: application,
            parameters: [
                "smsCode": verificationCode,
                "mobilePhoneNumber": mobilePhoneNumber],
            completionInBackground: completion)
    }

    // MARK: Log in with parameters
    
    @discardableResult
    private static func logIn<User: LCUser>(
        application: LCApplication,
        parameters: [String: Any],
        completionInBackground completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return application.httpClient.request(
            .post, "login",
            parameters: parameters)
        { response in
            let result = LCValueResult<User>(response: response)
            switch result {
            case .success(let user):
                application.currentUser = user
            case .failure:
                break
            }
            completion(result)
        }
    }

    // MARK: Log in with session token
    
    /// Log in with session token synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - sessionToken: The session token of the user.
    public static func logIn<User: LCUser>(application: LCApplication = .default, sessionToken: String) -> LCValueResult<User> {
        return expect { fulfill in
            self.logIn(
                application: application,
                sessionToken: sessionToken,
                completionInBackground: { (result) in
                    fulfill(result)
            })
        }
    }
    
    /// Log in with session token asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - sessionToken: The session token of the user.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func logIn<User: LCUser>(
        application: LCApplication = .default,
        sessionToken: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return self.logIn(
            application: application,
            sessionToken: sessionToken,
            completionInBackground: { result in
                completionQueue.async {
                    completion(result)
                }
        })
    }
    
    @discardableResult
    private static func logIn<User: LCUser>(
        application: LCApplication,
        sessionToken: String,
        completionInBackground completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return application.httpClient.request(
            .get, "users/me",
            parameters: ["session_token": sessionToken])
        { response in
            let result = LCValueResult<User>(response: response)
            switch result {
            case .success(let user):
                application.currentUser = user
            case .failure:
                break
            }
            completion(result)
        }
    }

    // MARK: Sign up or log in with phone number and verification code
    
    /// Sign up or log in with mobile phone number and verification code synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number of the user.
    ///   - verificationCode: The verification code sent to `mobilePhoneNumber`.
    public static func signUpOrLogIn<User: LCUser>(application: LCApplication = .default, mobilePhoneNumber: String, verificationCode: String) -> LCValueResult<User> {
        return expect { fulfill in
            self.signUpOrLogIn(
                application: application,
                mobilePhoneNumber: mobilePhoneNumber,
                verificationCode: verificationCode,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Sign up or log in with mobile phone number and verification code asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number of the user.
    ///   - verificationCode: The verification code sent to `mobilePhoneNumber`.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func signUpOrLogIn<User: LCUser>(
        application: LCApplication = .default,
        mobilePhoneNumber: String,
        verificationCode: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCValueResult<User>) -> Void)
        -> LCRequest
    {
        return self.signUpOrLogIn(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber,
            verificationCode: verificationCode,
            completionInBackground: { result in
                completionQueue.async {
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
        return application.httpClient.request(
            .post, "usersByMobilePhone",
            parameters: [
                "smsCode": verificationCode,
                "mobilePhoneNumber": mobilePhoneNumber])
        { response in
            let result = LCValueResult<User>(response: response)
            switch result {
            case .success(let user):
                application.currentUser = user
            case .failure:
                break
            }
            completion(result)
        }
    }
    
    /// Log out current user of the application.
    /// - Parameter application: The application current user belong to, default is `LCApplication.default`.
    public static func logOut(application: LCApplication = .default) {
        application.currentUser = nil
    }

    // MARK: Send verification mail
    
    /// Request to send a verification mail to specified email address synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - email: The email address where the mail will be sent to.
    public static func requestVerificationMail(application: LCApplication = .default, email: String) -> LCBooleanResult {
        return expect { fulfill in
            self.requestVerificationMail(
                application: application,
                email: email,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Request to send a verification mail to specified email address asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - email: The email address where the mail will be sent to.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func requestVerificationMail(
        application: LCApplication = .default,
        email: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.requestVerificationMail(
            application: application,
            email: email,
            completionInBackground: { result in
                completionQueue.async {
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
        return application.httpClient.request(
            .post, "requestEmailVerify",
            parameters: ["email": email])
        { response in
            completion(LCBooleanResult(response: response))
        }
    }

    // MARK: Send verification code
    
    /// Request to send a verification code to specified mobile phone number synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number where the verification code will be sent to.
    /// - Returns: `LCBooleanResult`
    public static func requestVerificationCode(
        application: LCApplication = .default,
        mobilePhoneNumber: String) -> LCBooleanResult
    {
        return expect { fulfill in
            self._requestVerificationCode(
                application: application,
                mobilePhoneNumber: mobilePhoneNumber)
            { result in
                fulfill(result)
            }
        }
    }
    
    /// Request to send a verification code to specified mobile phone number asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number where the verification code will be sent to.
    ///   - completionQueue: The queue where the completion be invoked, default is `DispatchQueue.main`.
    ///   - completion: The result callback.
    /// - Returns: `LCRequest`
    @discardableResult
    public static func requestVerificationCode(
        application: LCApplication = .default,
        mobilePhoneNumber: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        return self._requestVerificationCode(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber)
        { result in
            completionQueue.async {
                completion(result)
            }
        }
    }
    
    @discardableResult
    private static func _requestVerificationCode(
        application: LCApplication,
        mobilePhoneNumber: String,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        return application.httpClient.request(
            .post, "requestMobilePhoneVerify",
            parameters: ["mobilePhoneNumber": mobilePhoneNumber])
        { response in
            completion(LCBooleanResult(response: response))
        }
    }
    
    /// Request to send a verification code to bind or update mobile phone number synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number where the verification code will be sent to.
    ///   - timeToLive: The time-to-live of the code.
    /// - Returns: `LCBooleanResult`
    public static func requestVerificationCode(
        application: LCApplication = .default,
        forUpdatingMobilePhoneNumber mobilePhoneNumber: String,
        timeToLive: Int? = nil) -> LCBooleanResult
    {
        return expect { (fulfill) in
            self._requestVerificationCode(
                application: application,
                forUpdatingMobilePhoneNumber: mobilePhoneNumber,
                timeToLive: timeToLive)
            { (result) in
                fulfill(result)
            }
        }
    }
    
    /// Request to send a verification code to bind or update mobile phone number asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number where the verification code will be sent to.
    ///   - timeToLive: The time-to-live of the code.
    ///   - completionQueue: The queue where the completion be invoked, default is `DispatchQueue.main`.
    ///   - completion: The result callback.
    /// - Returns: `LCRequest`
    @discardableResult
    public static func requestVerificationCode(
        application: LCApplication = .default,
        forUpdatingMobilePhoneNumber mobilePhoneNumber: String,
        timeToLive: Int? = nil,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        return self._requestVerificationCode(
            application: application,
            forUpdatingMobilePhoneNumber: mobilePhoneNumber,
            timeToLive: timeToLive)
        { (result) in
            completionQueue.async {
                completion(result)
            }
        }
    }
    
    @discardableResult
    private static func _requestVerificationCode(
        application: LCApplication,
        forUpdatingMobilePhoneNumber mobilePhoneNumber: String,
        timeToLive: Int?,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        var parameters: [String: Any] = ["mobilePhoneNumber": mobilePhoneNumber]
        if let timeToLive = timeToLive {
            parameters["ttl"] = timeToLive
        }
        return application.httpClient.request(
            .post, "requestChangePhoneNumber",
            parameters: parameters)
        { response in
            completion(LCBooleanResult(response: response))
        }
    }
    
    // MARK: Verify phone number
    
    /// Verify mobile phone number with code synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number of the user.
    ///   - verificationCode: The verification code sent to mobile phone number.
    /// - Returns: `LCBooleanResult`
    public static func verifyMobilePhoneNumber(
        application: LCApplication = .default,
        _ mobilePhoneNumber: String,
        verificationCode: String) -> LCBooleanResult
    {
        return expect { fulfill in
            self._verifyMobilePhoneNumber(
                application: application,
                mobilePhoneNumber: mobilePhoneNumber,
                verificationCode: verificationCode)
            { result in
                fulfill(result)
            }
        }
    }
    
    /// Verify mobile phone number with code asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number of the user.
    ///   - verificationCode: The verification code sent to mobile phone number.
    ///   - completionQueue: The queue where the completion be invoked, default is `DispatchQueue.main`.
    ///   - completion: The result callback.
    /// - Returns: `LCRequest`
    @discardableResult
    public static func verifyMobilePhoneNumber(
        application: LCApplication = .default,
        _ mobilePhoneNumber: String,
        verificationCode: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        return self._verifyMobilePhoneNumber(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber,
            verificationCode: verificationCode)
        { result in
            completionQueue.async {
                completion(result)
            }
        }
    }
    
    @discardableResult
    private static func _verifyMobilePhoneNumber(
        application: LCApplication,
        mobilePhoneNumber: String,
        verificationCode: String,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        return application.httpClient.request(
            .post, "verifyMobilePhone/\(verificationCode)",
            parameters: ["mobilePhoneNumber": mobilePhoneNumber])
        { response in
            completion(LCBooleanResult(response: response))
        }
    }
    
    /// Verify code to bind or update mobile phone number synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - verificationCode: The verification code sent to mobile phone number.
    ///   - mobilePhoneNumber: The mobile phone number to be bound or updated.
    /// - Returns: `LCBooleanResult`
    public static func verifyVerificationCode(
        application: LCApplication = .default,
        _ verificationCode: String,
        toUpdateMobilePhoneNumber mobilePhoneNumber: String) -> LCBooleanResult
    {
        return expect { (fulfill) in
            self._verifyVerificationCode(
                application: application,
                verificationCode: verificationCode,
                toUpdateMobilePhoneNumber: mobilePhoneNumber)
            { (result) in
                fulfill(result)
            }
        }
    }
    
    /// Verify code to bind or update mobile phone number asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - verificationCode: The verification code sent to mobile phone number.
    ///   - mobilePhoneNumber: The mobile phone number to be bound or updated.
    ///   - completionQueue: The queue where the completion be invoked, default is `DispatchQueue.main`.
    ///   - completion: The result callback.
    /// - Returns: `LCRequest`
    @discardableResult
    public static func verifyVerificationCode(
        application: LCApplication = .default,
        _ verificationCode: String,
        toUpdateMobilePhoneNumber mobilePhoneNumber: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        return self._verifyVerificationCode(
            application: application,
            verificationCode: verificationCode,
            toUpdateMobilePhoneNumber: mobilePhoneNumber)
        { (result) in
            completionQueue.async {
                completion(result)
            }
        }
    }
    
    @discardableResult
    private static func _verifyVerificationCode(
        application: LCApplication,
        verificationCode: String,
        toUpdateMobilePhoneNumber mobilePhoneNumber: String,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        return application.httpClient.request(
            .post, "changePhoneNumber",
            parameters: [
                "mobilePhoneNumber": mobilePhoneNumber,
                "code": verificationCode
            ])
        { response in
            completion(LCBooleanResult(response: response))
        }
    }

    // MARK: Send a login verification code
    
    /// Request a verification code for login with mobile phone number synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number where the verification code will be sent to.
    public static func requestLoginVerificationCode(application: LCApplication = .default, mobilePhoneNumber: String) -> LCBooleanResult {
        return expect { fulfill in
            self.requestLoginVerificationCode(
                application: application,
                mobilePhoneNumber: mobilePhoneNumber,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Request a verification code for login with mobile phone number asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number where the verification code will be sent to.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func requestLoginVerificationCode(
        application: LCApplication = .default,
        mobilePhoneNumber: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.requestLoginVerificationCode(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber,
            completionInBackground: { result in
                completionQueue.async {
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
        return application.httpClient.request(
            .post, "requestLoginSmsCode",
            parameters: ["mobilePhoneNumber": mobilePhoneNumber])
        { response in
            completion(LCBooleanResult(response: response))
        }
    }

    // MARK: Send password reset mail
    
    /// Request password reset mail synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - email: The email address where the password reset mail will be sent to.
    public static func requestPasswordReset(application: LCApplication = .default, email: String) -> LCBooleanResult {
        return expect { fulfill in
            self.requestPasswordReset(
                application: application,
                email: email,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Request password reset email asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - email: The email address where the password reset mail will be sent to.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func requestPasswordReset(
        application: LCApplication = .default,
        email: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.requestPasswordReset(
            application: application,
            email: email,
            completionInBackground: { result in
                completionQueue.async {
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
        return application.httpClient.request(
            .post, "requestPasswordReset",
            parameters: ["email": email])
        { response in
            completion(LCBooleanResult(response: response))
        }
    }

    // MARK: Send password reset short message
    
    /// Request password reset verification code synchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number where the password reset verification code will be sent to.
    public static func requestPasswordReset(application: LCApplication = .default, mobilePhoneNumber: String) -> LCBooleanResult {
        return expect { fulfill in
            self.requestPasswordReset(
                application: application,
                mobilePhoneNumber: mobilePhoneNumber,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Request password reset verification code asynchronously.
    /// - Parameters:
    ///   - application: The application the user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number where the password reset verification code will be sent to.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult public static func requestPasswordReset(
        application: LCApplication = .default,
        mobilePhoneNumber: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.requestPasswordReset(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber,
            completionInBackground: { result in
                completionQueue.async {
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
        return application.httpClient.request(
            .post, "requestPasswordResetBySmsCode",
            parameters: ["mobilePhoneNumber": mobilePhoneNumber])
        { response in
            completion(LCBooleanResult(response: response))
        }
    }

    // MARK: Reset password with verification code and new password
    
    /// Reset password with verification code and new password synchronously.
    /// This method will reset password of current user.
    /// If current user is nil, in other words, no user logged in,
    /// Password reset will be failed because of permission.
    ///
    /// - Parameters:
    ///   - application: The application current user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number of current user.
    ///   - verificationCode: The verification code in password reset message.
    ///   - newPassword: The new password of current user.
    public static func resetPassword(application: LCApplication = .default, mobilePhoneNumber: String, verificationCode: String, newPassword: String) -> LCBooleanResult {
        return expect { fulfill in
            self.resetPassword(
                application: application,
                mobilePhoneNumber: mobilePhoneNumber,
                verificationCode: verificationCode,
                newPassword: newPassword,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }

    /// Reset password with verification code and new password asynchronously.
    /// This method will reset password of current user.
    /// If current user is nil, in other words, no user logged in,
    /// Password reset will be failed because of permission.
    ///
    /// - Parameters:
    ///   - application: The application current user belong to, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number of current user.
    ///   - verificationCode: The verification code in password reset message.
    ///   - newPassword: The new password of current user.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func resetPassword(
        application: LCApplication = .default,
        mobilePhoneNumber: String,
        verificationCode: String,
        newPassword: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.resetPassword(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber,
            verificationCode: verificationCode,
            newPassword: newPassword,
            completionInBackground: { result in
                completionQueue.async {
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
        return application.httpClient.request(
            .put, "resetPasswordBySmsCode/\(verificationCode)",
            parameters: [
                "password": newPassword,
                "mobilePhoneNumber": mobilePhoneNumber])
        { response in
            completion(LCBooleanResult(response: response))
        }
    }

    // MARK: Update password with new password
    
    /// Update password for user synchronously.
    /// - Parameters:
    ///   - oldPassword: The old password of the user.
    ///   - newPassword: The new password of the user.
    public func updatePassword(oldPassword: String, newPassword: String) -> LCBooleanResult {
        return expect { fulfill in
            self.updatePassword(
                oldPassword: oldPassword,
                newPassword: newPassword,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }

    /// Update password for user asynchronously.
    /// - Parameters:
    ///   - oldPassword: The old password of the user.
    ///   - newPassword: The new password of the user.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public func updatePassword(
        oldPassword: String,
        newPassword: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.updatePassword(
            oldPassword: oldPassword,
            newPassword: newPassword,
            completionInBackground: { result in
                completionQueue.async {
                    completion(result)
                }
        })
    }

    @discardableResult
    private func updatePassword(oldPassword: String, newPassword: String, completionInBackground completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        let httpClient: HTTPClient = self.application.httpClient
        guard let endpoint = httpClient.getObjectEndpoint(object: self) else {
            return httpClient.request(
                error: LCError(
                    code: .notFound,
                    reason: "Object ID not found."),
                completionHandler: completion)
        }
        guard let sessionToken = self.sessionToken?.value else {
            return httpClient.request(
                error: LCError(
                    code: .notFound,
                    reason: "Session Token not found."),
                completionHandler: completion)
        }
        return httpClient.request(
            .put, "\(endpoint)/updatePassword",
            parameters: [
                "old_password": oldPassword,
                "new_password": newPassword],
            headers: [HTTPClient.HeaderFieldName.session: sessionToken])
        { response in
            if let error = LCError(response: response) {
                completion(.failure(error: error))
            } else {
                if let dictionary = response.value as? [String: Any] {
                    ObjectProfiler.shared.updateObject(self, dictionary)
                }
                completion(.success)
            }
        }
    }
    
    // MARK: Auth Data
    
    /// The third party platform
    public enum AuthDataPlatform {
        case qq
        case weibo
        case weixin
        case apple
        case custom(_ key: String)
        
        public var key: String {
            switch self {
            case .qq:
                return "qq"
            case .weibo:
                return "weibo"
            case .weixin:
                return "weixin"
            case .apple:
                return "lc_apple"
            case .custom(let key):
                return key
            }
        }
    }
    
    /// The options of auth data
    public struct AuthDataOptions: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Using the auth data as main data.
        public static let mainAccount = AuthDataOptions(rawValue: 1 << 0)
        
        /// If a user with the auth data not exist, then return error.
        public static let failOnNotExist = AuthDataOptions(rawValue: 1 << 1)
    }
    
    /// Login with third party auth data synchronously.
    /// - Parameters:
    ///   - authData: The auth data of third party account.
    ///   - platform: The platform of third party account. @see `AuthDataPlatform`.
    ///   - unionID: The union ID of the auth data.
    ///   - unionIDPlatform: The platform of the `unionID`. @see `AuthDataPlatform`.
    ///   - options: @see `AuthDataOptions`.
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
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Login with third party auth data asynchronously.
    /// - Parameters:
    ///   - authData: The auth data of third party account.
    ///   - platform: The platform of third party account. @see `AuthDataPlatform`.
    ///   - unionID: The union ID of the auth data.
    ///   - unionIDPlatform: The platform of the `unionID`. @see `AuthDataPlatform`.
    ///   - options: @see `AuthDataOptions`.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public func logIn(
        authData: [String: Any],
        platform: AuthDataPlatform,
        unionID: String? = nil,
        unionIDPlatform: AuthDataPlatform? = nil,
        options: AuthDataOptions? = nil,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.logIn(
            authData: authData,
            platform: platform,
            unionID: unionID,
            unionIDPlatform: unionIDPlatform,
            options: options,
            completionInBackground: { (result) in
                completionQueue.async {
                    completion(result)
                }
        })
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
        var authData = authData
        if let unionID = unionID {
            authData["unionid"] = unionID
        }
        if let unionIDPlatform = unionIDPlatform {
            authData["platform"] = unionIDPlatform.key
        }
        if let options = options, options.contains(.mainAccount) {
            authData["main_account"] = true
        }
        
        var parameters = (self.dictionary.lconValue as? [String: Any]) ?? [:]
        parameters["authData"] = [platform.key: authData]
        parameters.removeValue(forKey: "__type")
        parameters.removeValue(forKey: "className")
        
        var path = "users"
        if let options = options, options.contains(.failOnNotExist) {
            path += "?failOnNotExist=true"
        }
        
        return self.application.httpClient.request(
            .post, path,
            parameters: parameters)
        { response in
            if let error = LCError(response: response) {
                completion(.failure(error: error))
            } else {
                if let dictionary = response.value as? [String: Any] {
                    ObjectProfiler.shared.updateObject(self, dictionary)
                    self.application.currentUser = self
                    completion(.success)
                } else {
                    completion(.failure(
                        error: LCError(
                            code: .invalidType,
                            reason: "invalid response data type.")))
                }
            }
        }
    }
    
    /// Associate the user with third party auth data synchronously.
    /// - Parameters:
    ///   - authData: The auth data of third party account.
    ///   - platform: The platform of third party account. @see `AuthDataPlatform`.
    ///   - unionID: The union ID of the auth data.
    ///   - unionIDPlatform: The platform of the `unionID`. @see `AuthDataPlatform`.
    ///   - options: @see `AuthDataOptions`.
    public func associate(
        authData: [String: Any],
        platform: AuthDataPlatform,
        unionID: String? = nil,
        unionIDPlatform: AuthDataPlatform? = nil,
        options: AuthDataOptions? = nil)
        throws -> LCBooleanResult
    {
        return try expect { fulfill in
            try self.associate(
                authData: authData,
                platform: platform,
                unionID: unionID,
                unionIDPlatform: unionIDPlatform,
                options: options,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Associate the user with third party auth data asynchronously.
    /// - Parameters:
    ///   - authData: The auth data of third party account.
    ///   - platform: The platform of third party account. @see `AuthDataPlatform`.
    ///   - unionID: The union ID of the auth data.
    ///   - unionIDPlatform: The platform of the `unionID`. @see `AuthDataPlatform`.
    ///   - options: @see `AuthDataOptions`.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public func associate(
        authData: [String: Any],
        platform: AuthDataPlatform,
        unionID: String? = nil,
        unionIDPlatform: AuthDataPlatform? = nil,
        options: AuthDataOptions? = nil,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        throws -> LCRequest
    {
        return try self.associate(
            authData: authData,
            platform: platform,
            unionID: unionID,
            unionIDPlatform: unionIDPlatform,
            options: options,
            completionInBackground: { result in
                completionQueue.async {
                    completion(result)
                }
        })
    }
    
    @discardableResult
    private func associate(
        authData: [String: Any],
        platform: AuthDataPlatform,
        unionID: String?,
        unionIDPlatform: AuthDataPlatform?,
        options: AuthDataOptions?,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        throws -> LCRequest
    {
        guard let objectID = self.objectId?.value else {
            throw LCError(
                code: .notFound,
                reason: "Object ID not found.")
        }
        guard let sessionToken = self.sessionToken?.value else {
            throw LCError(
                code: .notFound,
                reason: "Session Token not found.")
        }
        
        var authData = authData
        if let unionID = unionID {
            authData["unionid"] = unionID
        }
        if let unionIDPlatform = unionIDPlatform {
            authData["platform"] = unionIDPlatform.key
        }
        if let options = options, options.contains(.mainAccount) {
            authData["main_account"] = true
        }
        
        let path: String = "users/\(objectID)"
        let parameters: [String: Any] = ["authData": [platform.key: authData]]
        let headers: [String: String] = [HTTPClient.HeaderFieldName.session: sessionToken]
        
        return self.application.httpClient.request(
            .put, path,
            parameters: parameters,
            headers: headers)
        { response in
            if let error = LCError(response: response) {
                completion(.failure(error: error))
            } else {
                if let dictionary = response.value as? [String: Any] {
                    do {
                        if let originAuthData = self.authData {
                            originAuthData[platform.key] = try LCDictionary(
                                application: self.application,
                                unsafeObject: authData)
                        } else {
                            self.authData = try LCDictionary(
                                application: self.application,
                                unsafeObject: [platform.key: authData])
                        }
                        ObjectProfiler.shared.updateObject(self, dictionary)
                        self.trySaveToLocal()
                        completion(.success)
                    } catch {
                        completion(.failure(
                            error: LCError(
                                error: error)))
                    }
                } else {
                    completion(.failure(
                        error: LCError(
                            code: .invalidType,
                            reason: "invalid response data type.")))
                }
            }
        }
    }
    
    /// Disassociate the user with third party auth data synchronously.
    ///   - platform: The platform of third party account. @see `AuthDataPlatform`.
    public func disassociate(authData platform: AuthDataPlatform) throws -> LCBooleanResult {
        return try expect { fulfill in
            try self.disassociate(
                authData: platform,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Disassociate the user with third party auth data asynchronously.
    /// - Parameters:
    ///   - platform: The platform of third party account. @see `AuthDataPlatform`.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public func disassociate(
        authData platform: AuthDataPlatform,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        throws -> LCRequest
    {
        return try self.disassociate(
            authData: platform,
            completionInBackground: { result in
                completionQueue.async {
                    completion(result)
                }
        })
    }
    
    @discardableResult
    private func disassociate(
        authData platform: AuthDataPlatform,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        throws -> LCRequest
    {
        guard let objectID = self.objectId?.value else {
            throw LCError(
                code: .notFound,
                reason: "Object ID not found.")
        }
        guard let sessionToken = self.sessionToken?.value else {
            throw LCError(
                code: .notFound,
                reason: "Session Token not found.")
        }
        
        let path: String = "users/\(objectID)"
        let parameters: [String: Any] = ["authData.\(platform.key)": [Operation.key: Operation.Name.delete.rawValue]]
        let headers: [String: String] = [HTTPClient.HeaderFieldName.session: sessionToken]
        
        return self.application.httpClient.request(
            .put, path,
            parameters: parameters,
            headers: headers)
        { response in
            if let error = LCError(response: response) {
                completion(.failure(error: error))
            } else {
                if let dictionary = response.value as? [String: Any] {
                    self.authData?.removeValue(forKey: platform.key)
                    ObjectProfiler.shared.updateObject(self, dictionary)
                    self.trySaveToLocal()
                    completion(.success)
                } else {
                    completion(.failure(
                        error: LCError(
                            code: .invalidType,
                            reason: "invalid response data type.")))
                }
            }
        }
    }
    
    override func objectDidSave() {
        super.objectDidSave()
        self.trySaveToLocal()
    }
}
