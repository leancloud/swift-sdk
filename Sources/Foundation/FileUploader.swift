//
//  FileUploader.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/9/19.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation
import Alamofire

#if canImport(MobileCoreServices)
import MobileCoreServices
#endif

/**
 File uploader.
 */
class FileUploader {
    let file: LCFile
    let payload: LCFile.Payload
    let options: LCFile.Options

    init(file: LCFile, payload: LCFile.Payload, options: LCFile.Options) {
        self.file = file
        self.payload = payload
        self.options = options
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        self.session = Session(
            configuration: configuration,
            startRequestsImmediately: false)
    }

    /// Session manager for uploading file.
    private let session: Alamofire.Session

    /**
     File tokens.
     */
    private struct FileTokens {

        /**
         File hosting provider.
         */
        enum Provider: String {

            case qiniu
            case qcloud
            case s3

        }

        let provider: Provider

        let uploadingURLString: String

        let token: String

        let mimeType: String?
        
        let key: String?
        
        init(plainTokens: LCDictionary) throws {
            guard
                let providerString = plainTokens["provider"]?.stringValue,
                let provider = Provider(rawValue: providerString)
            else {
                throw LCError(code: .malformedData, reason: "Unknown file hosting provider.")
            }

            guard let uploadingURLString = plainTokens["upload_url"]?.stringValue else {
                throw LCError(code: .malformedData, reason: "Uploading URL not found.")
            }

            guard let token = plainTokens["token"]?.stringValue else {
                throw LCError(code: .malformedData, reason: "Uploading token not found.")
            }

            let mimeType = plainTokens["mime_type"]?.stringValue
            self.key = plainTokens["key"]?.stringValue
            self.provider = provider
            self.uploadingURLString = uploadingURLString
            self.token = token
            self.mimeType = mimeType
        }

    }

    /**
     File attributes.
     */
    struct FileAttributes {

        /// File payload.
        let payload: LCFile.Payload

        /// File name.
        let name: String?

        /// File size.
        let size: UInt64

        /// File mime type.
        let mimeType: String

        /// The default MIME type.
        private static let defaultMIMEType = "application/octet-stream"

        /**
         Inspect file attributes.

         - parameter file: The file to be uploaded.
         - parameter payload: The file payload to be uploaded.
         */
        init(file: LCFile, payload: LCFile.Payload) throws {
            let filename = file.name?.value
            let mimeType = file.mimeType?.value

            switch payload {
            case .data(let data):
                self.name = filename ?? Utility.compactUUID
                self.size = UInt64(data.count)

                if let mimeType = mimeType {
                    self.mimeType = mimeType
                } else if let mimeType = FileAttributes.getMIMEType(filename: name) {
                    self.mimeType = mimeType
                } else {
                    self.mimeType = FileAttributes.defaultMIMEType
                }
            case .fileURL(let fileURL):
                let filename = filename ?? fileURL.lastPathComponent

                self.name = filename
                self.size = try FileAttributes.getFileSize(fileURL: fileURL)

                // It might be a bit odd that, unlike name, we detect MIME type from fileURL firstly.
                if let mimeType = mimeType {
                    self.mimeType = mimeType
                } else if let mimeType = try FileAttributes.getMIMEType(fileURL: fileURL) {
                    self.mimeType = mimeType
                } else if let mimeType = FileAttributes.getMIMEType(filename: name) {
                    self.mimeType = mimeType
                } else {
                    self.mimeType = FileAttributes.defaultMIMEType
                }
            }

            self.payload = payload
        }

        static private func validate<T>(fileURL url: URL, body: (URL) throws -> T) throws -> T {
            let fileManager = FileManager.default

            guard fileManager.isReadableFile(atPath: url.path) else {
                throw LCError(code: .notFound, reason: "File not found.")
            }

            return try body(url)
        }

        static private func getFileSize(fileURL url: URL) throws -> UInt64 {
            return try validate(fileURL: url) { url in
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

                guard let fileSize = attributes[.size] as? UInt64 else {
                    throw LCError(code: .notFound, reason: "Failed to get file size.")
                }

                return fileSize
            }
        }

        static private func getMIMEType(filenameExtension: String) -> String? {
            if filenameExtension.isEmpty {
                return nil
            }
            #if canImport(MobileCoreServices)
            if let uti = UTTypeCreatePreferredIdentifierForTag(
                kUTTagClassFilenameExtension, filenameExtension as CFString, nil)?
                .takeRetainedValue(),
                let mimeType = UTTypeCopyPreferredTagWithClass(
                    uti, kUTTagClassMIMEType)?
                    .takeRetainedValue() {
                return mimeType as String
            }
            #endif
            return nil
        }

        static func getMIMEType(filename: String?) -> String? {
            guard let filename = filename else {
                return nil
            }

            let filenameExtension = (filename as NSString).pathExtension
            let mimeType = getMIMEType(filenameExtension: filenameExtension)

            return mimeType
        }

        static private func getMIMEType(fileURL url: URL) throws -> String? {
            return try validate(fileURL: url) { url in
                getMIMEType(filenameExtension: url.pathExtension)
            }
        }

    }

    private func createTouchParameters(file: LCFile, attributes: FileAttributes) -> [String: Any] {
        var parameters: [String: Any]

        // Fuse file properties into parameters.

        if let properties = file.dictionary.jsonValue as? [String: Any] {
            parameters = properties
        } else {
            parameters = [:]
        }

        // Add extra file related attributes to parameters.

        if let name = attributes.name {
            parameters["name"] = name
        }
        parameters["mime_type"] = attributes.mimeType
        if self.options.contains(.keepFileName)
            || self.file.keepFileName {
            parameters["keep_file_name"] = true
        }

        var metaData: [String: Any] = (file.metaData?.jsonValue as? [String: Any]) ?? [:]
        metaData.merge(["size": attributes.size]) { (current, _) in current }

        parameters["metaData"] = metaData
        parameters.removeValue(forKey: "__type")
        parameters.removeValue(forKey: "className")

        return parameters
    }

    private struct TouchResult {

        let plainTokens: LCDictionary

        let typedTokens: FileTokens

    }

    private func touch(
        parameters: [String: Any],
        completion: @escaping (LCGenericResult<TouchResult>) -> Void) -> LCRequest
    {
        return self.file.application.httpClient.request(.post, "fileTokens", parameters: parameters) { response in
            let dictionaryResult = LCValueResult<LCDictionary>(response: response)

            switch dictionaryResult {
            case .success(let plainTokens):
                do {
                    let typedTokens = try FileTokens(plainTokens: plainTokens)
                    let value = TouchResult(plainTokens: plainTokens, typedTokens: typedTokens)
                    completion(.success(value: value))
                } catch let error {
                    completion(.failure(error: LCError(error: error)))
                }
            case .failure(let error):
                completion(.failure(error: error))
            }
        }
    }

    private func writeToQiniu(
        tokens: FileTokens,
        attributes: FileAttributes,
        progressQueue: DispatchQueue,
        progress: ((Double) -> Void)?,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        let token = tokens.token

        let payload  = self.payload
        let mimeType = attributes.mimeType
        let fileName = attributes.name

        var tokenData: Data
        var resourceKeyData: Data

        do {
            if let aKeyData = tokens.key?.data(using: .utf8) {
                resourceKeyData = aKeyData
            } else {
                throw LCError(code: .malformedData, reason: "Invalid resource key.")
            }

            if let aTokenData = token.data(using: .utf8) {
                tokenData = aTokenData
            } else {
                throw LCError(code: .malformedData, reason: "Invalid uploading token.")
            }
        } catch let error {
            return self.file.application.httpClient.request(error: error) { result in
                completion(result)
            }
        }
        
        let multipartFormData: (MultipartFormData) -> Void = { multipartFormData in
            /*
             Qiniu multipart format:
             https://developer.qiniu.com/kodo/manual/1272/form-upload
             */
            multipartFormData.append(tokenData, withName: "token")
            multipartFormData.append(resourceKeyData, withName: "key")
            
            switch payload {
            case .data(let data):
                multipartFormData.append(data, withName: "file", fileName: fileName, mimeType: mimeType)
            case .fileURL(let fileURL):
                multipartFormData.append(fileURL, withName: "file", fileName: fileName ?? fileURL.lastPathComponent, mimeType: mimeType)
            }
        }
         
        let request = self.session
            .upload(
                multipartFormData: multipartFormData,
                to: tokens.uploadingURLString,
                method: .post)
            .validate()
        if let progress = progress {
            request.uploadProgress(queue: progressQueue) {
                progress($0.fractionCompleted)
            }
        }
        request.response(
            queue: self.file.application.httpClient
                .defaultCompletionConcurrentQueue)
        { (response) in
            if let error = response.error {
                completion(.failure(error: LCError(error: error)))
            } else {
                completion(.success)
            }
        }
        
        let sequenceRequest = LCSequenceRequest()
        sequenceRequest.setCurrentRequest(request)
        request.resume()

        return sequenceRequest
    }

    private func writeToQCloud(
        tokens: FileTokens,
        attributes: FileAttributes,
        progressQueue: DispatchQueue,
        progress: ((Double) -> Void)?,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        let payload  = self.payload
        let mimeType = attributes.mimeType
        let fileName = attributes.name
        
        let multipartFormData: (MultipartFormData) -> Void = { multipartFormData in
            switch payload {
            case .data(let data):
                multipartFormData.append(data, withName: "filecontent", fileName: fileName, mimeType: mimeType)
            case .fileURL(let fileURL):
                multipartFormData.append(fileURL, withName: "filecontent", fileName: fileName ?? fileURL.lastPathComponent, mimeType: mimeType)
            }
            
            multipartFormData.append("upload".data(using: .utf8)!, withName: "op")
        }

        let request = self.session
            .upload(
                multipartFormData: multipartFormData,
                to: tokens.uploadingURLString,
                method: .post,
                headers: HTTPHeaders(["Authorization": tokens.token]))
            .validate()
        if let progress = progress {
            request.uploadProgress(queue: progressQueue) {
                progress($0.fractionCompleted)
            }
        }
        request.response(
            queue: self.file.application.httpClient
                .defaultCompletionConcurrentQueue)
        { response in
            if let error = response.error {
                completion(.failure(error: LCError(error: error)))
            } else {
                completion(.success)
            }
        }
        
        let sequenceRequest = LCSequenceRequest()
        sequenceRequest.setCurrentRequest(request)
        request.resume()

        return sequenceRequest
    }

    private func writeToS3(
        tokens: FileTokens,
        attributes: FileAttributes,
        progressQueue: DispatchQueue,
        progress: ((Double) -> Void)?,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        let uploadingURLString = tokens.uploadingURLString

        var headers: [String: String] = [:]

        headers["Content-Type"] = attributes.mimeType
        headers["Content-Length"] = String(attributes.size)
        headers["Cache-Control"] = "public, max-age=31536000"

        let uploadRequest: UploadRequest
        
        switch payload {
        case .data(let data):
            uploadRequest = self.session.upload(data, to: uploadingURLString, method: .put, headers: HTTPHeaders(headers))
        case .fileURL(let fileURL):
            uploadRequest = self.session.upload(fileURL, to: uploadingURLString, method: .put, headers: HTTPHeaders(headers))
        }

        uploadRequest.validate()
        if let progress = progress {
            uploadRequest.uploadProgress(queue: progressQueue) {
                progress($0.fractionCompleted)
            }
        }
        uploadRequest.response(
            queue: self.file.application.httpClient
                .defaultCompletionConcurrentQueue)
        { response in
            if let error = response.error {
                completion(.failure(error: LCError(error: error)))
            } else {
                completion(.success)
            }
        }

        let request = LCSingleRequest(request: uploadRequest)
        uploadRequest.resume()

        return request
    }

    private func write(
        tokens: FileTokens,
        attributes: FileAttributes,
        progressQueue: DispatchQueue,
        progress: ((Double) -> Void)?,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        switch tokens.provider {
        case .qiniu:
            return writeToQiniu(
                tokens: tokens,
                attributes: attributes,
                progressQueue: progressQueue,
                progress: progress,
                completion: completion)
        case .qcloud:
            return writeToQCloud(
                tokens: tokens,
                attributes: attributes,
                progressQueue: progressQueue,
                progress: progress,
                completion: completion)
        case .s3:
            return writeToS3(
                tokens: tokens,
                attributes: attributes,
                progressQueue: progressQueue,
                progress: progress,
                completion: completion)
        }
    }

    private func feedback(
        result: LCBooleanResult,
        tokens: FileTokens)
    {
        var parameters: [String: Any] = [:]

        parameters["token"] = tokens.token

        switch result {
        case .success:
            parameters["result"] = true
        case .failure:
            parameters["result"] = false
        }

        _ = self.file.application.httpClient.request(.post, "fileCallback", parameters: parameters) { response in
            /* Ignore response of file feedback. */
        }
    }

    private func close(
        result: LCBooleanResult,
        tokens: LCDictionary,
        touchParameters: [String: Any])
    {
        switch result {
        case .success:
            let properties = LCDictionary(tokens)

            // Touch parameters are also part of propertise.
            do {
                let dictionary = try LCDictionary(application: self.file.application, unsafeObject: touchParameters)

                dictionary.forEach { (key, value) in
                    properties.set(key, value)
                }
            } catch let error {
                Logger.shared.error(error)
            }

            // Remove security-sensitive and pointless information.
            properties.removeValue(forKey: "token")
            properties.removeValue(forKey: "access_key")
            properties.removeValue(forKey: "access_token")
            properties.removeValue(forKey: "upload_url")

            properties.forEach { element in
                file.update(element.key, element.value)
            }
        case .failure:
            break
        }
    }

    /**
     Upload file in background.

     - parameter progress: The progress handler.
     - parameter completion: The completion handler.

     - returns: The upload request.
     */
    func upload(
        progressQueue: DispatchQueue,
        progress: ((Double) -> Void)?,
        completion: @escaping (LCBooleanResult) -> Void) -> LCRequest
    {
        let httpClient: HTTPClient = self.file.application.httpClient
        
        // If objectId exists, we think that the file has already been uploaded.
        if let _ = file.objectId {
            return httpClient.request(object: LCBooleanResult.success) { result in
                completion(result)
            }
        }

        var attributes: FileAttributes

        do {
            attributes = try FileAttributes(file: file, payload: payload)
        } catch let error {
            return httpClient.request(error: error) { result in
                completion(result)
            }
        }

        let sequenceRequest = LCSequenceRequest()
        let touchParameters = createTouchParameters(file: file, attributes: attributes)

        // Before upload resource, we have to touch file first.
        let touchRequest = touch(parameters: touchParameters) { result in
            switch result {
            case .success(let value):
                let plainTokens = value.plainTokens
                let typedTokens = value.typedTokens

                // If file is touched, write resource to third-party file provider.
                let writeRequest = self.write(
                    tokens: typedTokens,
                    attributes: attributes,
                    progressQueue: progressQueue,
                    progress: progress)
                { result in
                    self.close(result: result, tokens: plainTokens, touchParameters: touchParameters)
                    self.feedback(result: result, tokens: typedTokens)
                    completion(result)
                }
                sequenceRequest.setCurrentRequest(writeRequest)
            case .failure(let error):
                completion(.failure(error: error))
            }
        }

        sequenceRequest.setCurrentRequest(touchRequest)

        return sequenceRequest
    }

}
