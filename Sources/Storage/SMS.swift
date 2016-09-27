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
public final class LCSMS {
    /**
     Request a short message.

     - parameter mobilePhoneNumber: The mobile phone number where short message will be sent to.
     - parameter parameters:        The request parameters.

     - returns: The result of short message request.
     */
    static func requestShortMessage(mobilePhoneNumber: String, parameters: LCDictionaryConvertible?) -> LCBooleanResult {
        let parameters = parameters?.lcDictionary ?? LCDictionary()

        parameters["mobilePhoneNumber"] = LCString(mobilePhoneNumber)

        let response = RESTClient.request(.post, "requestSmsCode", parameters: parameters.lconValue as? [String: AnyObject])

        return LCBooleanResult(response: response)
    }

    /**
     Request a short message.

     - parameter mobilePhoneNumber: The mobile phone number where short message will be sent to.
     - parameter templateName:      The template name.
     - parameter variables:         The variables used to substitute placeholders in template.

     - returns: The result of short message request.
     */
    public static func requestShortMessage(mobilePhoneNumber: String, templateName: String, variables: LCDictionaryConvertible? = nil) -> LCBooleanResult {
        let parameters = variables?.lcDictionary ?? LCDictionary()

        parameters["template"] = LCString(templateName)

        return requestShortMessage(mobilePhoneNumber: mobilePhoneNumber, parameters: parameters)
    }

    /**
     Request a short message asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where verification code will be sent to.
     - parameter templateName:      The template name.
     - parameter variables:         The variables used to substitute placeholders in template.
     - parameter completion:        The completion callback closure.
     */
    public static func requestShortMessage(mobilePhoneNumber: String, templateName: String, variables: LCDictionaryConvertible? = nil, completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.requestShortMessage(mobilePhoneNumber: mobilePhoneNumber, templateName: templateName, variables: variables) }) { result in
            completion(result)
        }
    }

    /**
     Request a verification code.

     - parameter mobilePhoneNumber: The mobile phone number where verification code will be sent to.
     - parameter applicationName:   The application name. If absent, defaults to application name in web console.
     - parameter operation:         The operation. If absent, defaults to "\u77ed\u4fe1\u9a8c\u8bc1".
     - parameter timeToLive:        The time to live of short message, in minutes. Defaults to 10 minutes.

     - returns: The result of verification code request.
     */
    public static func requestVerificationCode(mobilePhoneNumber: String, applicationName: String? = nil, operation: String? = nil, timeToLive: UInt? = nil) -> LCBooleanResult {
        var parameters: [String: AnyObject] = [:]

        if let operation = operation {
            parameters["op"] = operation as AnyObject?
        }
        if let applicationName = applicationName {
            parameters["name"] = applicationName as AnyObject?
        }
        if let timeToLive = timeToLive {
            parameters["ttl"] = timeToLive as AnyObject?
        }

        return requestShortMessage(mobilePhoneNumber: mobilePhoneNumber, parameters: parameters)
    }

    /**
     Request a verification code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where verification code will be sent to.
     - parameter applicationName:   The application name. If absent, defaults to application name in web console.
     - parameter operation:         The operation. If absent, defaults to "\u77ed\u4fe1\u9a8c\u8bc1".
     - parameter timeToLive:        The time to live of short message, in minutes. Defaults to 10 minutes.
     - parameter completion:        The completion callback closure.
     */
    public static func requestVerificationCode(mobilePhoneNumber: String, applicationName: String? = nil, operation: String? = nil, timeToLive: UInt? = nil, completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.requestVerificationCode(mobilePhoneNumber: mobilePhoneNumber) }) { result in
            completion(result)
        }
    }

    /**
     Request a voice verification code.

     - parameter mobilePhoneNumber: The mobile phone number where verification code will be sent to.

     - returns: The result of verification code request.
     */
    public static func requestVoiceVerificationCode(mobilePhoneNumber: String) -> LCBooleanResult {
        let parameters = ["smsType": "voice"]

        return requestShortMessage(mobilePhoneNumber: mobilePhoneNumber, parameters: parameters)
    }

    /**
     Request a voice verification code asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number where verification code will be sent to.
     - parameter completion:        The completion callback closure.
     */
    public static func requestVoiceVerificationCode(mobilePhoneNumber: String, completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.requestVoiceVerificationCode(mobilePhoneNumber: mobilePhoneNumber) }) { result in
            completion(result)
        }
    }

    /**
     Verify mobile phone number.

     - parameter mobilePhoneNumber: The mobile phone number which you want to verify.
     - parameter verificationCode:  The verification code.

     - returns: The result of verification request.
     */
    public static func verifyMobilePhoneNumber(_ mobilePhoneNumber: String, verificationCode: String) -> LCBooleanResult {
        let endpoint = "verifySmsCode/\(verificationCode)?mobilePhoneNumber=\(mobilePhoneNumber)"
        let response = RESTClient.request(.post, endpoint)

        return LCBooleanResult(response: response)
    }

    /**
     Verify mobile phone number asynchronously.

     - parameter mobilePhoneNumber: The mobile phone number which you want to verify.
     - parameter verificationCode:  The verification code.
     - parameter completion:        The completion callback closure.
     */
    public static func verifyMobilePhoneNumber(_ mobilePhoneNumber: String, verificationCode: String, completion: @escaping (LCBooleanResult) -> Void) {
        RESTClient.asynchronize({ self.verifyMobilePhoneNumber(mobilePhoneNumber, verificationCode: verificationCode) }) { result in
            completion(result)
        }
    }
}
