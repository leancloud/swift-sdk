//
//  IMMessage.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2018/12/26.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation
import AVFoundation
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// IM Message
open class IMMessage {
    
    /// Message IO Type.
    ///
    /// - `in`: The message which the current client received.
    /// - out: The message which the current client sent.
    public enum IOType {
        case `in`
        case out
    }
    
    /// @see `IOType`.
    public var ioType: IOType {
        if
            let fromClientID: String = self.fromClientID,
            let currentClientID: String = self.currentClientID,
            fromClientID == currentClientID
        {
            return .out
        } else {
            return .in
        }
    }
    
    /// The ID of the client which sent this message.
    public private(set) var fromClientID: IMClient.Identifier?
    
    /// The ID of the current client.
    public private(set) var currentClientID: IMClient.Identifier?
    
    /// Message Status.
    public enum Status: Int {
        case failed     = -1
        case none       = 0
        case sending    = 1
        case sent       = 2
        case delivered  = 3
        case read       = 4
    }
    
    /// @see `Status`.
    public var status: Status {
        let currentStatus = self.underlyingStatus
        if currentStatus == .sent {
            if let _ = self.readTimestamp {
                return .read
            } else if let _ = self.deliveredTimestamp {
                return .delivered
            } else {
                return currentStatus
            }
        } else {
            return currentStatus
        }
    }
    private(set) var underlyingStatus: Status = .none
    
    /// The ID of this message.
    public private(set) var ID: String?
    
    /// The ID of the conversation which this message belong to.
    public private(set) var conversationID: String?
    
    /// The sent timestamp of this message. measurement is millisecond.
    public private(set) var sentTimestamp: Int64?
    
    /// The sent date of this message.
    public var sentDate: Date? {
        return IMClient.date(fromMillisecond: sentTimestamp)
    }
    
    /// The delivered timestamp of this message. measurement is millisecond.
    public var deliveredTimestamp: Int64?
    
    /// The delivered date of this message.
    public var deliveredDate: Date? {
        return IMClient.date(fromMillisecond: deliveredTimestamp)
    }
    
    /// The read timestamp of this message. measurement is millisecond.
    public var readTimestamp: Int64?
    
    /// The read date of this message.
    public var readDate: Date? {
        return IMClient.date(fromMillisecond: readTimestamp)
    }
    
    /// The reason of the message being patched.
    public struct PatchedReason {
        public let code: Int?
        public let reason: String?
    }
    
    /// The patched timestamp of this message. measurement is millisecond.
    public internal(set) var patchedTimestamp: Int64?
    
    /// The patched date of this message.
    public var patchedDate: Date? {
        return IMClient.date(fromMillisecond: patchedTimestamp)
    }
    
    /// Feature: @all.
    public var isAllMembersMentioned: Bool?
    
    /// Feature: @members.
    public var mentionedMembers: [String]?
    
    /// Indicates whether the current client has been @.
    public var isCurrentClientMentioned: Bool {
        if self.ioType == .out {
            return false
        } else {
            if let allMentioned: Bool = self.isAllMembersMentioned,
                allMentioned {
                return true
            }
            if let clientID: String = self.currentClientID,
                let mentionedMembers: [String] = self.mentionedMembers {
                return mentionedMembers.contains(clientID)
            }
            return false
        }
    }
    
    /// Message Content.
    ///
    /// - string: string content.
    /// - data: binary content.
    public enum Content {
        case string(String)
        case data(Data)
        
        public var string: String? {
            switch self {
            case .string(let str):
                return str
            default:
                return nil
            }
        }
        
        public var data: Data? {
            switch self {
            case .data(let data):
                return data
            default:
                return nil
            }
        }
    }
    
    /// @see `Content`.
    public fileprivate(set) var content: Content?
    
    /// Set content for message.
    ///
    /// - Parameter content: @see `Content`.
    /// - Throws: `IMCategorizedMessage` not support this function.
    public func set(content: Content) throws {
        if self is IMCategorizedMessage {
            throw LCError(
                code: .inconsistency,
                reason:"\(type(of: self))'s content can't be set directly"
            )
        } else {
            self.content = content
        }
    }
    
    public required init() {}
    
    static func instance(
        application: LCApplication,
        isTransient: Bool,
        conversationID: String,
        currentClientID: IMClient.Identifier,
        fromClientID: IMClient.Identifier?,
        timestamp: Int64,
        patchedTimestamp: Int64?,
        messageID: String,
        content: Content?,
        isAllMembersMentioned: Bool?,
        mentionedMembers: [String]?,
        status: Status = .sent)
        -> IMMessage
    {
        var message = IMMessage()
        let messageTypeKey: String = IMCategorizedMessage.ReservedKey.type.rawValue
        if let string: String = content?.string, string.contains(messageTypeKey) {
            do {
                if let rawData: [String: Any] = try string.jsonObject(),
                    let typeNumber: Int = rawData[messageTypeKey] as? Int,
                    let messageType: IMCategorizedMessage.Type = IMCategorizedMessageTypeMap[typeNumber]
                {
                    let categorizedMessage = messageType.init()
                    categorizedMessage.decoding(rawData: rawData, application: application)
                    message = categorizedMessage
                }
            } catch {
                Logger.shared.error(error)
            }
        }
        message.isTransient = isTransient
        message.conversationID = conversationID
        message.sentTimestamp = timestamp
        message.patchedTimestamp = patchedTimestamp
        message.ID = messageID
        message.content = content
        message.isAllMembersMentioned = isAllMembersMentioned
        message.mentionedMembers = mentionedMembers
        message.fromClientID = fromClientID
        message.currentClientID = currentClientID
        message.underlyingStatus = status
        return message
    }
    
    var isTransient: Bool = false
    var notTransientMessage: Bool {
        return !self.isTransient
    }
    
    var isWill: Bool = false
    var notWillMessage: Bool {
        return !self.isWill
    }
    
    /// ref: https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md#客户端发起-3
    /// parameter: `dt`
    var dToken: String? = nil
    
    var sendingTimestamp: Int64? = nil
    
    var breakpoint: Bool = false
    
    func setup(clientID: String, conversationID: String) {
        self.fromClientID = clientID
        self.currentClientID = clientID
        self.conversationID = conversationID
    }
    
    func update(status newStatus: IMMessage.Status, ID: String? = nil, timestamp: Int64? = nil) {
        assert(newStatus != .delivered && newStatus != .read)
        self.underlyingStatus = newStatus
        if newStatus == .sent {
            self.ID = ID
            self.sentTimestamp = timestamp
        }
    }
    
    var isSent: Bool {
        switch self.status {
        case .sent, .delivered, .read:
            return true
        default:
            return false
        }
    }
    
}

var IMCategorizedMessageTypeMap: [Int: IMCategorizedMessage.Type] = [
    IMCategorizedMessage.ReservedType.none.rawValue: IMCategorizedMessage.self,
    IMCategorizedMessage.ReservedType.text.rawValue: IMTextMessage.self,
    IMCategorizedMessage.ReservedType.image.rawValue: IMImageMessage.self,
    IMCategorizedMessage.ReservedType.audio.rawValue: IMAudioMessage.self,
    IMCategorizedMessage.ReservedType.video.rawValue: IMVideoMessage.self,
    IMCategorizedMessage.ReservedType.location.rawValue: IMLocationMessage.self,
    IMCategorizedMessage.ReservedType.file.rawValue: IMFileMessage.self,
    IMCategorizedMessage.ReservedType.recalled.rawValue: IMRecalledMessage.self
]

/// IM Message Categorizing Protocol
public protocol IMMessageCategorizing: class {
    
    /// Message Type is Int Type
    typealias MessageType = Int
    
    /// The type of the categorized message,
    /// The zero and negative number is reserved for default categorized message,
    /// Any other categorized message should use positive number.
    static var messageType: MessageType { get }
    
}

/// IM Categorized Message
open class IMCategorizedMessage: IMMessage, IMMessageCategorizing {
    
    /// Reserved message type.
    ///
    /// - none: none.
    /// - text: text.
    /// - image: image.
    /// - audio: audio.
    /// - video: video.
    /// - location: location.
    /// - file: file.
    /// - recalled: recalled.
    public enum ReservedType: MessageType {
        case none = 0
        case text = -1
        case image = -2
        case audio = -3
        case video = -4
        case location = -5
        case file = -6
        case recalled = -127
    }
    
    enum ReservedKey: String {
        case type = "_lctype"
        case text = "_lctext"
        case attributes = "_lcattrs"
        case file = "_lcfile"
        case location = "_lcloc"
    }
    
    enum FileKey: String {
        case objId = "objId"
        case url = "url"
        case metaData = "metaData"
        case width = "width"
        case height = "height"
        case duration = "duration"
        case size = "size"
        case format = "format"
    }
    
    enum LocationKey: String {
        case latitude = "latitude"
        case longitude = "longitude"
    }
    
    /// Any categorized message should be registered at first.
    ///
    /// - Throws: if `lcType` is not a positive number.
    public static func register() throws {
        let type: Int = self.messageType
        guard type > 0 else {
            throw LCError(
                code: .inconsistency,
                reason: "The value of the customized message's type should be a positive integer"
            )
        }
        IMCategorizedMessageTypeMap[type] = self
    }
    
    /// The type of message.
    open class var messageType: MessageType {
        return ReservedType.none.rawValue
    }
    
    public required init() {
        super.init()
    }
    
    public init(
        application: LCApplication = LCApplication.default,
        data: Data,
        format: String? = nil)
    {
        super.init()
        let payload = LCFile.Payload.data(data: data)
        self.file = LCFile(application: application, payload: payload)
        self.setFileFormat(format: format)
    }
    
    public init(
        application: LCApplication = LCApplication.default,
        filePath: String,
        format: String? = nil)
    {
        super.init()
        let fileURL = URL(fileURLWithPath: filePath)
        let payload = LCFile.Payload.fileURL(fileURL: fileURL)
        self.file = LCFile(application: application, payload: payload)
        self.setFileFormat(format: format)
    }
    
    public init(
        application: LCApplication = LCApplication.default,
        url: URL,
        format: String? = nil)
    {
        super.init()
        self.file = LCFile(application: application, url: url)
        self.setFileFormat(format: format)
    }

    @available(*, unavailable)
    public override func set(content: IMMessage.Content) throws {
        try super.set(content: content)
    }
    
    var rawData: [String: Any] = [:]
    
    /// Get and set value via subscript syntax.
    public subscript(key: String) -> Any? {
        set {
            self.rawData[key] = newValue
        }
        get {
            return self.rawData[key]
        }
    }
    
    /// The text info.
    public var text: String?
    
    /// The attributes info.
    public var attributes: [String: Any]?
    
    /// The file object.
    public var file: LCFile?
    
    private(set) var fileMetaData: [String: Any]?
    
    /// The location data.
    public var location: LCGeoPoint?
    
    fileprivate func decoding(rawData: [String: Any], application: LCApplication) {
        if let text: String = rawData[ReservedKey.text.rawValue] as? String {
            self.text = text
        }
        if let attributes: [String: Any] = rawData[ReservedKey.attributes.rawValue] as? [String: Any] {
            self.attributes = attributes
        }
        if let locationRawData: [String: Any] = rawData[ReservedKey.location.rawValue] as? [String: Any],
            let latitude: Double = locationRawData[LocationKey.latitude.rawValue] as? Double,
            let longitude: Double = locationRawData[LocationKey.longitude.rawValue] as? Double
        {
            self.location = LCGeoPoint(latitude: latitude, longitude: longitude)
        }
        if let fileRawData: [String: Any] = rawData[ReservedKey.file.rawValue] as? [String: Any],
            let objectID: String = fileRawData[FileKey.objId.rawValue] as? String,
            let URLString: String = fileRawData[FileKey.url.rawValue] as? String
        {
            let file = LCFile(application: application, objectId: objectID)
            file.url = LCString(URLString)
            self.file = file
            self.fileMetaData = (fileRawData[FileKey.metaData.rawValue] as? [String: Any])
        }
        self.rawData = rawData
    }
    
    func tryEncodingFileMetaData() {
        guard
            let file = self.file,
            file.hasObjectId
            else
        { return }
        var shouldRemovedTempFileURL: URL? = nil
        defer {
            if let tempFileURL: URL = shouldRemovedTempFileURL {
                do {
                    try FileManager.default.removeItem(at: tempFileURL)
                } catch {
                    Logger.shared.error(error)
                }
            }
        }
        var metaData: [String: Any] = [:]
        // set size
        if let size: Double = file.metaData?[FileKey.size.rawValue]?.doubleValue {
            metaData[FileKey.size.rawValue] = size
        }
        // set format
        var tempFilePathExtension: String? = nil
        if let format: String = file.metaData?[FileKey.format.rawValue]?.stringValue {
            tempFilePathExtension = format
            metaData[FileKey.format.rawValue] = format
        } else if let format: String = (file.name?.value as NSString?)?.pathExtension ?? (file.url?.value as NSString?)?.pathExtension,
            !format.isEmpty {
            tempFilePathExtension = format
            metaData[FileKey.format.rawValue] = format
        }
        if (self is IMImageMessage) {
            // set width & height
            if let fileOriginMetaData: LCDictionary = file.metaData,
                let width: Double = fileOriginMetaData[FileKey.width.rawValue]?.doubleValue,
                let height: Double = fileOriginMetaData[FileKey.height.rawValue]?.doubleValue
            {
                metaData[FileKey.width.rawValue] = width
                metaData[FileKey.height.rawValue] = height
            } else if let payload: LCFile.Payload = file.payload {
                var imageData: Data? = nil
                switch payload {
                case .fileURL(fileURL: let fileURL):
                    let filePath: String = fileURL.path
                    if FileManager.default.fileExists(atPath: filePath) {
                        imageData = FileManager.default.contents(atPath: filePath)
                    }
                case .data(data: let data):
                    imageData = data
                }
                if let data: Data = imageData {
                    var width: Double? = nil
                    var height: Double? = nil
                    #if os(iOS) || os(tvOS) || os(watchOS)
                    if let image: UIImage = UIImage(data: data) {
                        width = Double(image.size.width * image.scale)
                        height = Double(image.size.height * image.scale)
                    }
                    #elseif os(macOS)
                    if let image: NSImage = NSImage(data: data) {
                        width = Double(image.size.width)
                        height = Double(image.size.height)
                    }
                    #endif
                    if let w: Double = width, let h: Double = height {
                        metaData[FileKey.width.rawValue] = w
                        metaData[FileKey.height.rawValue] = h
                    }
                }
            }
        } else if (self is IMAudioMessage) || (self is IMVideoMessage) {
            // set duration
            if let duration: Double = file.metaData?[FileKey.duration.rawValue]?.doubleValue {
                metaData[FileKey.duration.rawValue] = duration
            } else {
                var avURL: URL? = nil
                if let payload: LCFile.Payload = file.payload {
                    switch payload {
                    case .fileURL(fileURL: let fileURL):
                        avURL = fileURL
                    case .data(data: let data):
                        var nextLoop: Bool = false
                        repeat {
                            var pathComponent: String = UUID().uuidString
                            if let format: String = tempFilePathExtension {
                                pathComponent = "\(pathComponent).\(format)"
                            }
                            let tempFilePath: String = (NSTemporaryDirectory() as NSString).appendingPathComponent(pathComponent)
                            if FileManager.default.fileExists(atPath: tempFilePath) {
                                nextLoop = true
                            } else {
                                if FileManager.default.createFile(atPath: tempFilePath, contents: data) {
                                    avURL = URL(fileURLWithPath: tempFilePath)
                                    shouldRemovedTempFileURL = avURL
                                }
                                nextLoop = false
                            }
                        } while nextLoop
                    }
                } else if let fileURLString: String = file.url?.value {
                    avURL = URL(string: fileURLString)
                }
                if let fileURL: URL = avURL {
                    #if !os(watchOS)
                    let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
                    let URLAsset = AVURLAsset(url: fileURL, options: options)
                    let duration: Double = URLAsset.duration.seconds
                    metaData[FileKey.duration.rawValue] = duration
                    #endif
                }
            }
        }
        if !metaData.isEmpty {
            do {
                self.fileMetaData = try metaData.jsonObject()
            } catch {
                Logger.shared.error(error)
            }
        }
    }
    
    func encodingMessageContent() throws {
        self.rawData[ReservedKey.type.rawValue] = type(of: self).messageType
        if let text: String = self.text {
            self.rawData[ReservedKey.text.rawValue] = text
        }
        if let attributes: [String: Any] = self.attributes {
            self.rawData[ReservedKey.attributes.rawValue] = attributes
        }
        if let file: LCFile = self.file,
            let objectID: String = file.objectId?.value,
            let url: String = file.url?.value
        {
            var fileRawData: [String: Any] = [
                FileKey.objId.rawValue: objectID,
                FileKey.url.rawValue: url
            ]
            if let metaData: [String: Any] = self.fileMetaData {
                fileRawData[FileKey.metaData.rawValue] = metaData
            }
            self.rawData[ReservedKey.file.rawValue] = fileRawData
        }
        if let location: LCGeoPoint = self.location {
            let locationRawData: [String: Any] = [
                LocationKey.latitude.rawValue: location.latitude,
                LocationKey.longitude.rawValue: location.longitude
            ]
            self.rawData[ReservedKey.location.rawValue] = locationRawData
        }
        let data: Data = try JSONSerialization.data(withJSONObject: self.rawData)
        if let realJSONObject: [String: Any] = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.rawData = realJSONObject
        }
        if let contentString: String = String(data: data, encoding: .utf8) {
            self.content = .string(contentString)
        }
    }
    
    fileprivate func decodingFileMetaData<T>(with key: FileKey) -> T? {
        return self.fileMetaData?[key.rawValue] as? T
    }
    
    private func setFileFormat(format: String?) {
        guard let format = format, let file = self.file else {
            return
        }
        let key = FileKey.format.rawValue
        let value = LCString(format)
        if let metaData: LCDictionary = file.metaData {
            metaData[key] = value
        } else {
            file.metaData = LCDictionary([key: value])
        }
    }
    
}

/// IM Text Message
public class IMTextMessage: IMCategorizedMessage {
    
    public class override var messageType: MessageType {
        return ReservedType.text.rawValue
    }
    
    public required init() {
        super.init()
    }
    
    public init(text: String) {
        super.init()
        self.text = text
    }
    
    @available(*, unavailable)
    public override init(application: LCApplication = LCApplication.default, data: Data, format: String? = nil) {
        super.init(application: application, data: data, format: format)
    }
    
    @available(*, unavailable)
    public override init(application: LCApplication = LCApplication.default, filePath: String, format: String? = nil) {
        super.init(application: application, filePath: filePath, format: format)
    }
    
    @available(*, unavailable)
    public override init(application: LCApplication = LCApplication.default, url: URL, format: String? = nil) {
        super.init(application: application, url: url, format: format)
    }
    
}

/// IM Image Message
public class IMImageMessage: IMCategorizedMessage {
    
    public class override var messageType: MessageType {
        return ReservedType.image.rawValue
    }
    
    /// The width of image.
    public var width: Double? {
        return self.decodingFileMetaData(with: .width)
    }
    
    /// The height of image.
    public var height: Double? {
        return self.decodingFileMetaData(with: .height)
    }
    
    /// The data size of image.
    public var size: Double? {
        return self.decodingFileMetaData(with: .size)
    }
    
    /// The format of image.
    public var format: String? {
        return self.decodingFileMetaData(with: .format)
    }
    
    /// The URL of image.
    public var url: URL? {
        if let urlString: String = self.file?.url?.value,
            let url: URL = URL(string: urlString) {
            return url
        } else {
            return nil
        }
    }
    
}

/// IM Audio Message
public class IMAudioMessage: IMCategorizedMessage {
    
    public class override var messageType: MessageType {
        return ReservedType.audio.rawValue
    }
    
    /// The duration of audio.
    public var duration: Double? {
        return self.decodingFileMetaData(with: .duration)
    }
    
    /// The data size of audio.
    public var size: Double? {
        return self.decodingFileMetaData(with: .size)
    }
    
    /// The format of audio.
    public var format: String? {
        return self.decodingFileMetaData(with: .format)
    }
    
    /// The URL of audio.
    public var url: URL? {
        if let urlString: String = self.file?.url?.value,
            let url: URL = URL(string: urlString) {
            return url
        } else {
            return nil
        }
    }
    
}

/// IM Video Message
public class IMVideoMessage: IMCategorizedMessage {
    
    public class override var messageType: MessageType {
        return ReservedType.video.rawValue
    }
    
    /// The duration of video.
    public var duration: Double? {
        return self.decodingFileMetaData(with: .duration)
    }
    
    /// The data size of video.
    public var size: Double? {
        return self.decodingFileMetaData(with: .size)
    }
    
    /// The format of video.
    public var format: String? {
        return self.decodingFileMetaData(with: .format)
    }
    
    /// The URL of video.
    public var url: URL? {
        if let urlString: String = self.file?.url?.value,
            let url: URL = URL(string: urlString) {
            return url
        } else {
            return nil
        }
    }
    
}

/// IM File Message
public class IMFileMessage: IMCategorizedMessage {
    
    public class override var messageType: MessageType {
        return ReservedType.file.rawValue
    }
    
    /// The data size of file.
    public var size: Double? {
        return self.decodingFileMetaData(with: .size)
    }
    
    /// The format of file.
    public var format: String? {
        return self.decodingFileMetaData(with: .format)
    }
    
    /// The URL of file.
    public var url: URL? {
        if let urlString: String = self.file?.url?.value,
            let url: URL = URL(string: urlString) {
            return url
        } else {
            return nil
        }
    }
    
}

/// IM Location Message
public class IMLocationMessage: IMCategorizedMessage {
    
    public class override var messageType: MessageType {
        return ReservedType.location.rawValue
    }
    
    public required init() {
        super.init()
    }
    
    public init(latitude: Double, longitude: Double) {
        super.init()
        self.location = LCGeoPoint(latitude: latitude, longitude: longitude)
    }
    
    @available(*, unavailable)
    public override init(application: LCApplication = LCApplication.default, data: Data, format: String? = nil) {
        super.init(application: application, data: data, format: format)
    }
    
    @available(*, unavailable)
    public override init(application: LCApplication = LCApplication.default, filePath: String, format: String? = nil) {
        super.init(application: application, filePath: filePath, format: format)
    }
    
    @available(*, unavailable)
    public override init(application: LCApplication = LCApplication.default, url: URL, format: String? = nil) {
        super.init(application: application, url: url, format: format)
    }
    
    /// The latitude of location.
    public var latitude: Double? {
        return self.location?.latitude
    }
    
    /// The longitude of location.
    public var longitude: Double? {
        return self.location?.longitude
    }
    
}

/// IM Recalled Message
public class IMRecalledMessage: IMCategorizedMessage {
    
    public class override var messageType: MessageType {
        return ReservedType.recalled.rawValue
    }
    
    public required init() {
        super.init()
    }
    
    @available(*, unavailable)
    public override init(application: LCApplication = LCApplication.default, data: Data, format: String? = nil) {
        super.init(application: application, data: data, format: format)
    }
    
    @available(*, unavailable)
    public override init(application: LCApplication = LCApplication.default, filePath: String, format: String? = nil) {
        super.init(application: application, filePath: filePath, format: format)
    }
    
    @available(*, unavailable)
    public override init(application: LCApplication = LCApplication.default, url: URL, format: String? = nil) {
        super.init(application: application, url: url, format: format)
    }
    
}
