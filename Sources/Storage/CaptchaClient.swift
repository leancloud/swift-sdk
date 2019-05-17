//
//  CaptchaClient.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2019/5/4.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import Foundation

public class LCCaptchaClient {
    
    /// Captcha
    public struct Captcha: Codable {
        public let token: String?
        public let url: String?
        
        enum CodingKeys: String, CodingKey {
            case token = "captcha_token"
            case url = "captcha_url"
        }
    }
    
    /// Captcha Verification
    public struct Verification: Codable {
        public let token: String?
        
        enum CodingKeys: String, CodingKey {
            case token = "validate_token"
        }
    }
    
    /// Request a Captcha.
    ///
    /// - Parameters:
    ///   - application: The application.
    ///   - width: The width of the image.
    ///   - height: The height of the image.
    ///   - completion: success with a captcha.
    /// - Returns: HTTP Request.
    @discardableResult
    public static func requestCaptcha(
        application: LCApplication = LCApplication.default,
        width: Double? = nil,
        height: Double? = nil,
        completion: @escaping (LCGenericResult<Captcha>) -> Void)
        -> LCRequest
    {
        var parameters: [String: Any] = [:]
        if let width = width {
            parameters["width"] = width
        }
        if let height = height {
            parameters["height"] = height
        }
        
        let request = application.httpClient.request(
            .get,
            "requestCaptcha",
            parameters: (parameters.isEmpty ? nil : parameters))
        { response in
            if let error = LCError(response: response) {
                mainQueueAsync {
                    completion(.failure(error: error))
                }
            } else {
                guard let data: Data = response.data else {
                    mainQueueAsync {
                        completion(.failure(error: LCError(code: .notFound, reason: "Response data not found.")))
                    }
                    return
                }
                do {
                    let captcha: Captcha = try JSONDecoder().decode(Captcha.self, from: data)
                    mainQueueAsync {
                        completion(.success(value: captcha))
                    }
                } catch {
                    mainQueueAsync {
                        completion(.failure(error: LCError(error: error)))
                    }
                }
            }
        }
        
        return request
    }
    
    /// Verify a Captcha.
    ///
    /// - Parameters:
    ///   - application: The application.
    ///   - code: The code of the captcha.
    ///   - captchaToken: The token of the captcha.
    ///   - completion: sucess with a captcha verification.
    /// - Returns: HTTP Request.
    @discardableResult
    public static func verifyCaptcha(
        application: LCApplication = LCApplication.default,
        code: String,
        captchaToken: String,
        completion: @escaping (LCGenericResult<Verification>) -> Void)
        -> LCRequest
    {
        let parameters: [String: Any] = [
            "captcha_code": code,
            "captcha_token": captchaToken
        ]
        
        let request = application.httpClient.request(
            .post,
            "verifyCaptcha",
            parameters: parameters)
        { response in
            if let error = LCError(response: response) {
                mainQueueAsync {
                    completion(.failure(error: error))
                }
            } else {
                guard let data: Data = response.data else {
                    mainQueueAsync {
                        completion(.failure(error: LCError(code: .notFound, reason: "Response data not found.")))
                    }
                    return
                }
                do {
                    let verification: Verification = try JSONDecoder().decode(Verification.self, from: data)
                    mainQueueAsync {
                        completion(.success(value: verification))
                    }
                } catch {
                    mainQueueAsync {
                        completion(.failure(error: LCError(error: error)))
                    }
                }
            }
        }
        
        return request
    }
    
}
