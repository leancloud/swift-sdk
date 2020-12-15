//
//  SMSClient.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 7/9/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/// Short Message Service (SMS) Client, you can use it to send short message to mobile phone.
public class LCSMSClient {
    
    // MARK: Request Short Message
    
    /// Request a short message synchronously.
    /// - Parameters:
    ///   - application: The application, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number where short message will be sent to.
    ///   - templateName: The template name.
    ///   - signatureName: The signature name.
    ///   - captchaVerificationToken: The token return by captcha verification for requesting sms.
    ///   - variables: The custom variables.
    public static func requestShortMessage(
        application: LCApplication = .default,
        mobilePhoneNumber: String,
        templateName: String? = nil,
        signatureName: String? = nil,
        captchaVerificationToken: String? = nil,
        variables: LCDictionaryConvertible? = nil)
        -> LCBooleanResult
    {
        let parameters = self.createRequestParameters(
            templateName: templateName,
            signatureName: signatureName,
            captchaVerificationToken: captchaVerificationToken,
            variables: variables)
        return expect { fulfill in
            self.requestShortMessage(
                application: application,
                mobilePhoneNumber: mobilePhoneNumber,
                parameters: parameters,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Request a short message asynchronously.
    /// - Parameters:
    ///   - application: The application, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number where short message will be sent to.
    ///   - templateName: The template name.
    ///   - signatureName: The signature name.
    ///   - captchaVerificationToken: The token return by captcha verification for requesting sms.
    ///   - variables: The custom variables.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func requestShortMessage(
        application: LCApplication = .default,
        mobilePhoneNumber: String,
        templateName: String? = nil,
        signatureName: String? = nil,
        captchaVerificationToken: String? = nil,
        variables: LCDictionaryConvertible? = nil,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let parameters = createRequestParameters(
            templateName: templateName,
            signatureName: signatureName,
            captchaVerificationToken: captchaVerificationToken,
            variables: variables)
        return self.requestShortMessage(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber,
            parameters: parameters,
            completionInBackground: { result in
                completionQueue.async {
                    completion(result)
                }
        })
    }

    @discardableResult
    private static func requestShortMessage(
        application: LCApplication,
        mobilePhoneNumber: String,
        parameters: LCDictionaryConvertible?,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let parameters = parameters?.lcDictionary ?? LCDictionary()
        parameters["mobilePhoneNumber"] = LCString(mobilePhoneNumber)
        return application.httpClient.request(
            .post, "requestSmsCode",
            parameters: parameters.lconValue as? [String: Any])
        { response in
            completion(LCBooleanResult(response: response))
        }
    }

    private static func createRequestParameters(
        templateName: String?,
        signatureName: String?,
        captchaVerificationToken: String?,
        variables: LCDictionaryConvertible?)
        -> LCDictionary
    {
        let parameters = variables?.lcDictionary ?? LCDictionary()
        if let templateName = templateName {
            parameters["template"] = LCString(templateName)
        }
        if let signatureName = signatureName {
            parameters["sign"] = LCString(signatureName)
        }
        if let captchaVerificationToken = captchaVerificationToken {
            parameters["validate_token"] = LCString(captchaVerificationToken)
        }
        return parameters
    }
    
    // MARK: Request Verification Code
    
    /// Request a verification code synchronously.
    /// - Parameters:
    ///   - application: The application, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number where verification code will be sent to.
    ///   - applicationName: The name of application in the short message, default is the name of application in console.
    ///   - operation: The name of operation in the short message, default is "短信验证".
    ///   - timeToLive: The time to live(unit is minute) of the verification code, default is 10 minutes.
    public static func requestVerificationCode(
        application: LCApplication = .default,
        mobilePhoneNumber: String,
        applicationName: String? = nil,
        operation: String? = nil,
        timeToLive: UInt? = nil)
        -> LCBooleanResult
    {
        return expect { fulfill in
            self.requestVerificationCode(
                application: application,
                mobilePhoneNumber: mobilePhoneNumber,
                applicationName: applicationName,
                operation: operation,
                timeToLive: timeToLive,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Request a verification code asynchronously.
    /// - Parameters:
    ///   - application: The application, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number where verification code will be sent to.
    ///   - applicationName: The name of application in the short message, default is the name of application in console.
    ///   - operation: The name of operation in the short message, default is "短信验证".
    ///   - timeToLive: The time to live(unit is minute) of the verification code, default is 10 minutes.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func requestVerificationCode(
        application: LCApplication = .default,
        mobilePhoneNumber: String,
        applicationName: String? = nil,
        operation: String? = nil,
        timeToLive: UInt? = nil,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.requestVerificationCode(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber,
            applicationName: applicationName,
            operation: operation,
            timeToLive: timeToLive,
            completionInBackground: { result in
                completionQueue.async {
                    completion(result)
                }
        })
    }

    @discardableResult
    private static func requestVerificationCode(
        application: LCApplication,
        mobilePhoneNumber: String,
        applicationName: String? = nil,
        operation: String? = nil,
        timeToLive: UInt? = nil,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let parameters = LCDictionary()
        if let operation = operation {
            parameters["op"] = LCString(operation)
        }
        if let applicationName = applicationName {
            parameters["name"] = LCString(applicationName)
        }
        if let timeToLive = timeToLive {
            parameters["ttl"] = LCNumber(Double(timeToLive))
        }
        return self.requestShortMessage(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber,
            parameters: parameters,
            completionInBackground: completion)
    }
    
    // MARK: Request Voice Verification Code
    
    /// Request a voice verification code synchronously.
    /// - Parameters:
    ///   - application: The application, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number be called.
    public static func requestVoiceVerificationCode(
        application: LCApplication = .default,
        mobilePhoneNumber: String)
        -> LCBooleanResult
    {
        return expect { fulfill in
            self.requestVoiceVerificationCode(
                application: application,
                mobilePhoneNumber: mobilePhoneNumber,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Request a voice verification code asynchronously.
    /// - Parameters:
    ///   - application: The application, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number be called.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult
    public static func requestVoiceVerificationCode(
        application: LCApplication = .default,
        mobilePhoneNumber: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.requestVoiceVerificationCode(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber,
            completionInBackground: { result in
                completionQueue.async {
                    completion(result)
                }
        })
    }

    @discardableResult
    private static func requestVoiceVerificationCode(
        application: LCApplication,
        mobilePhoneNumber: String,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.requestShortMessage(
            application: application,
            mobilePhoneNumber: mobilePhoneNumber,
            parameters: LCDictionary(["smsType": "voice"]),
            completionInBackground: completion)
    }
    
    // MARK: Verify Verification Code
    
    /// Verify a verification code synchronously.
    /// - Parameters:
    ///   - application: The application, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number which you want to verify.
    ///   - verificationCode: The verification code which sent to the mobile phone number.
    public static func verifyMobilePhoneNumber(
        application: LCApplication = .default,
        _ mobilePhoneNumber: String,
        verificationCode: String)
        -> LCBooleanResult
    {
        return expect { fulfill in
            self.verifyMobilePhoneNumber(
                application: application,
                mobilePhoneNumber,
                verificationCode: verificationCode,
                completionInBackground: { result in
                    fulfill(result)
            })
        }
    }
    
    /// Verify a verification code asynchronously.
    /// - Parameters:
    ///   - application: The application, default is `LCApplication.default`.
    ///   - mobilePhoneNumber: The mobile phone number which you want to verify.
    ///   - verificationCode: The verification code which sent to the mobile phone number.
    ///   - completionQueue: The queue where `completion` be executed, default is main.
    ///   - completion: Result callback.
    @discardableResult public static func verifyMobilePhoneNumber(
        application: LCApplication = .default,
        _ mobilePhoneNumber: String,
        verificationCode: String,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.verifyMobilePhoneNumber(
            application: application,
            mobilePhoneNumber,
            verificationCode: verificationCode,
            completionInBackground: { result in
                completionQueue.async {
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
        return application.httpClient.request(
            .post, "verifySmsCode/\(verificationCode)",
            parameters: ["mobilePhoneNumber": mobilePhoneNumber])
        { response in
            completion(LCBooleanResult(response: response))
        }
    }
}
