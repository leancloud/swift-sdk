//
//  SMSClient.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 7/9/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 Short message service (SMS) client.

 You can use this class to send short message to mobile phone.
 */
public final class LCSMSClient {
    /**
     Request a short message.

     - parameter mobilePhoneNumber: The mobile phone number where short message will be sent to.
     - parameter parameters:        The request parameters.

     - returns: The result of short message request.
     */
    private static func requestShortMessage(
        application: LCApplication,
        mobilePhoneNumber: String,
        parameters: LCDictionaryConvertible?)
        -> LCBooleanResult
    {
        return expect { fulfill in
            requestShortMessage(application: application, mobilePhoneNumber: mobilePhoneNumber, parameters: parameters, completionInBackground: { result in
                fulfill(result)
            })
        }
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

        let request = application.httpClient.request(.post, "requestSmsCode", parameters: parameters.lconValue as? [String: Any]) { response in
            completion(LCBooleanResult(response: response))
        }

        return request
    }

    private static func createRequestParameters(
        templateName: String,
        signatureName: String,
        captchaVerificationToken: String?,
        variables: LCDictionaryConvertible?)
        -> LCDictionary
    {
        let parameters = variables?.lcDictionary ?? LCDictionary()

        parameters["template"] = templateName.lcString /* template is a reserved name. */
        parameters["sign"] = signatureName.lcString
        if let captchaVerificationToken = captchaVerificationToken {
            parameters["validate_token"] = captchaVerificationToken.lcString
        }

        return parameters
    }

    /**
     Request a short message.

     - parameter mobilePhoneNumber: The mobile phone number where short message will be sent to.
     - parameter templateName:      The template name.
     - parameter variables:         The variables used to substitute placeholders in template.

     - returns: The result of short message request.
     */
    public static func requestShortMessage(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        templateName: String = "Register_Notice",
        signatureName: String = "LeanCloud",
        captchaVerificationToken: String? = nil,
        variables: LCDictionaryConvertible? = nil)
        -> LCBooleanResult
    {
        let parameters = createRequestParameters(
            templateName: templateName,
            signatureName: signatureName,
            captchaVerificationToken: captchaVerificationToken,
            variables: variables
        )

        return expect { fulfill in
            requestShortMessage(application: application, mobilePhoneNumber: mobilePhoneNumber, parameters: parameters, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Request a short message asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where verification code will be sent to.
     - parameter templateName:      The template name.
     - parameter variables:         The variables used to substitute placeholders in template.
     - parameter completion:        The completion callback closure.
     */
    public static func requestShortMessage(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        templateName: String = "Register_Notice",
        signatureName: String = "LeanCloud",
        captchaVerificationToken: String? = nil,
        variables: LCDictionaryConvertible? = nil,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let parameters = createRequestParameters(
            templateName: templateName,
            signatureName: signatureName,
            captchaVerificationToken: captchaVerificationToken,
            variables: variables
        )

        return requestShortMessage(application: application, mobilePhoneNumber: mobilePhoneNumber, parameters: parameters, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    /**
     Request a verification code.

     - parameter mobilePhoneNumber: The mobile phone number where verification code will be sent to.
     - parameter applicationName:   The application name. If absent, defaults to application name in web console.
     - parameter operation:         The operation. If absent, defaults to "\u77ed\u4fe1\u9a8c\u8bc1".
     - parameter timeToLive:        The time to live of short message, in minutes. Defaults to 10 minutes.

     - returns: The result of verification code request.
     */
    public static func requestVerificationCode(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        applicationName: String? = nil,
        operation: String? = nil,
        timeToLive: UInt? = nil)
        -> LCBooleanResult
    {
        return expect { fulfill in
            requestVerificationCode(application: application, mobilePhoneNumber: mobilePhoneNumber, applicationName: applicationName, operation: operation, timeToLive: timeToLive, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Request a verification code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where verification code will be sent to.
     - parameter applicationName:   The application name. If absent, defaults to application name in web console.
     - parameter operation:         The operation. If absent, defaults to "\u77ed\u4fe1\u9a8c\u8bc1".
     - parameter timeToLive:        The time to live of short message, in minutes. Defaults to 10 minutes.
     - parameter completion:        The completion callback closure.
     */
    public static func requestVerificationCode(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        applicationName: String? = nil,
        operation: String? = nil,
        timeToLive: UInt? = nil,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return requestVerificationCode(application: application, mobilePhoneNumber: mobilePhoneNumber, applicationName: applicationName, operation: operation, timeToLive: timeToLive, completionInBackground: { result in
            mainQueueAsync {
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
            parameters.op = operation
        }
        if let applicationName = applicationName {
            parameters.name = applicationName
        }
        if let timeToLive = timeToLive {
            parameters.ttl = timeToLive
        }

        return requestShortMessage(application: application, mobilePhoneNumber: mobilePhoneNumber, parameters: parameters, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    /**
     Request a voice verification code.

     - parameter mobilePhoneNumber: The mobile phone number where verification code will be sent to.

     - returns: The result of verification code request.
     */
    public static func requestVoiceVerificationCode(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String)
        -> LCBooleanResult
    {
        return expect { fulfill in
            requestVoiceVerificationCode(application: application, mobilePhoneNumber: mobilePhoneNumber, completionInBackground: { result in
                fulfill(result)
            })
        }
    }

    /**
     Request a voice verification code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where verification code will be sent to.
     - parameter completion:        The completion callback closure.
     */
    public static func requestVoiceVerificationCode(
        application: LCApplication = LCApplication.default,
        mobilePhoneNumber: String,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return requestVoiceVerificationCode(application: application, mobilePhoneNumber: mobilePhoneNumber, completionInBackground: { result in
            mainQueueAsync {
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
        let parameters = LCDictionary(["smsType": "voice"])

        return requestShortMessage(application: application, mobilePhoneNumber: mobilePhoneNumber, parameters: parameters, completionInBackground: { result in
            mainQueueAsync {
                completion(result)
            }
        })
    }

    /**
     Verify mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number which you want to verify.
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
     Verify mobile phone number asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number which you want to verify.
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
        let verificationCode = verificationCode.urlPathEncoded
        let mobilePhoneNumber = mobilePhoneNumber.urlQueryEncoded
        let endpoint = "verifySmsCode/\(verificationCode)?mobilePhoneNumber=\(mobilePhoneNumber)"

        let request = application.httpClient.request(.post, endpoint) { response in
            completion(LCBooleanResult(response: response))
        }

        return request
    }
}
