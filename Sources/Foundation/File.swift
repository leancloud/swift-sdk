//
//  File.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/9/19.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/// LeanCloud File Type
public class LCFile: LCObject {
    
    public final override class func objectClassName() -> String {
        return "_File"
    }

    /// The file URL.
    @objc public dynamic var url: LCString?

    /**
     The file key.

     It's the resource key of third-party file hosting provider.
     It may be nil for some providers.
     */
    @objc public dynamic var key: LCString?

    /// The file name.
    @objc public dynamic var name: LCString?

    /// The file meta data.
    @objc public dynamic var metaData: LCDictionary?

    /// The file hosting provider.
    @objc public dynamic var provider: LCString?

    /// The file bucket.
    @objc public dynamic var bucket: LCString?

    /**
     The MIME type of file.

     For uploading, you can use this property to explictly set MIME type of file content.

     It's an alias of property 'mime_type'.
     */
    public var mimeType: LCString? {
        get {
            return self["mime_type"] as? LCString
        }
        set {
            self["mime_type"] = newValue
        }
    }
    
    /// File Payload.
    public enum Payload {
        /// File content represented by `Data`.
        case data(data: Data)
        /// File content represented by `URL`. it is the path to a local file.
        case fileURL(fileURL: URL)
    }
    
    /// @see `Payload`.
    public private(set) var payload: Payload?
    
    // MARK: Init
    
    /// Create a file using default application.
    public required init() {
        super.init()
    }
    
    /// Create a file using a application.
    /// - Parameter application: The application which this file belong to.
    public required init(application: LCApplication) {
        super.init(application: application)
    }
    
    /// Create a file with a URL.
    /// - Parameters:
    ///   - application: The application which this file belong to. default is default application.
    ///   - url: The location of a resource on a remote server.
    public convenience init(
        application: LCApplication = .default,
        url: LCStringConvertible)
    {
        self.init(application: application)
        self.url = url.lcString
    }
    
    /// Create a file from payload.
    /// - Parameters:
    ///   - application: The application which this file belong to. default is default application.
    ///   - payload: @see `Payload`.
    public convenience init(
        application: LCApplication = .default,
        payload: Payload)
    {
        self.init(application: application)
        self.payload = payload
    }
    
    // MARK: Save
    
    /// If set it to `true`, then will use "/\(LCFile.name)" as URL suffix when creating file from payload. default is `false`.
    public var keepFileName: Bool = false
    
    /// Save Options
    public struct Options: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /// Using "/\(LCFile.name)" as URL suffix when creating file from payload.
        public static let keepFileName = Options(rawValue: 1 << 0)
    }
    
    /// Save file synchronously.
    /// - Parameter options: @see `LCFile.Options`, default is none.
    public func save(options: LCFile.Options = []) -> LCBooleanResult {
        return expect { fulfill in
            self.save(
                options: options,
                progressOn: .main,
                progress: nil)
            { result in
                fulfill(result)
            }
        }
    }
    
    /// Save file asynchronously.
    /// - Parameter options: @see `LCFile.Options`, default is none.
    /// - Parameter progressQueue: The queue where the progress be called. default is main.
    /// - Parameter progress: The progress of saving.
    /// - Parameter completionQueue: The queue where the completion be called. default is main.
    /// - Parameter completion: The callback of result.
    @discardableResult
    public func save(
        options: LCFile.Options = [],
        progressQueue: DispatchQueue = .main,
        progress: ((Double) -> Void)? = nil,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.save(
            options: options,
            progressOn: progressQueue,
            progress: progress)
        { result in
            completionQueue.async {
                completion(result)
            }
        }
    }

    func paddingInfo(remoteURL: LCString) {
        if let metaData = self.metaData {
            metaData["__source"] = "external"
        } else {
            self.metaData = LCDictionary(["__source": "external"])
        }
        if self.name == nil {
            self.name = LCString((remoteURL.value as NSString).lastPathComponent)
        }
        if self.mimeType == nil {
            if let mimeType = FileUploader.FileAttributes.getMIMEType(filename: self.name?.value) {
                self.mimeType = LCString(mimeType)
            }
        }
    }
    
    @discardableResult
    private func save(
        options: LCFile.Options,
        progressOn queue: DispatchQueue,
        progress: ((Double) -> Void)?,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        let httpClient: HTTPClient = self.application.httpClient
        guard self.objectId == nil else {
            return httpClient.request(
                error: LCError(
                    code: .inconsistency,
                    reason: "Can not update file after it has been saved."),
                completionHandler: completion)
        }
        if let payload = self.payload {
            return FileUploader(
                file: self,
                payload: payload,
                options: options).upload(
                    progressQueue: queue,
                    progress: progress,
                    completion: { result in
                        self.handleUploadResult(result, completion: completion)
                })
        } else if let remoteURL = self.url {
            self.paddingInfo(remoteURL: remoteURL)
            var parameters = dictionary.jsonValue as? [String: Any]
            parameters?.removeValue(forKey: "__type")
            parameters?.removeValue(forKey: "className")
            return httpClient.request(
                .post, "files",
                parameters: parameters)
            { response in
                self.handleSaveResult(
                    LCValueResult<LCDictionary>(response: response),
                    completion: completion)
            }
        } else {
            return httpClient.request(
                error: LCError(
                    code: .notFound,
                    reason: "No payload or URL to save."),
                completionHandler: completion)
        }
    }
    
    private func handleUploadResult(
        _ result: LCBooleanResult,
        completion: (LCBooleanResult) -> Void)
    {
        switch result {
        case .success:
            discardChanges()
        case .failure:
            break
        }
        completion(result)
    }
    
    private func handleSaveResult(
        _ result: LCValueResult<LCDictionary>,
        completion: (LCBooleanResult) -> Void)
    {
        switch result {
        case .success(let dictionary):
            dictionary.forEach { (key, value) in
                update(key, value)
            }
            discardChanges()
            completion(.success)
        case .failure(let error):
            completion(.failure(error: error))
        }
    }
    
    // MARK: Unavailable
    
    @available(*, unavailable)
    public override class func save(_ objects: [LCObject], options: [LCObject.SaveOption] = []) -> LCBooleanResult {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override class func save(_ objects: [LCObject], options: [LCObject.SaveOption] = [], completionQueue: DispatchQueue = .main, completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func save(options: [LCObject.SaveOption] = []) -> LCBooleanResult {
        fatalError("not support")
    }
    
    @available(*, unavailable)
    public override func save(options: [LCObject.SaveOption] = [], completionQueue: DispatchQueue = .main, completion: @escaping (LCBooleanResult) -> Void) -> LCRequest {
        fatalError("not support")
    }
}

extension LCFile {
    // MARK: Qiniu
    
    /// Parameters of Thumbnail.
    public enum Thumbnail {
        case scale(Double)
        case size(width: Double, height: Double)
    }
    
    /// Get the Thumbnail URL.
    /// @note: only work on Qiniu URL.
    /// - Parameter thumbnail: @see `Thumbnail`.
    public func thumbnailURL(_ thumbnail: Thumbnail) -> URL? {
        guard let fileURLString = self.url?.value else {
            return nil
        }
        var path = "?imageMogr2/thumbnail/"
        switch thumbnail {
        case let .scale(scale):
            path += "!\(scale * 100)p"
        case let .size(width: width, height: height):
            path += "\(width)x\(height)!"
        }
        return URL(string: fileURLString + path)
    }
}
