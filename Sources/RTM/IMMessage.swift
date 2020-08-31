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
    public enum IOType {
        case `in`
        case out
    }
    
    /// @see `IOType`.
    public var ioType: IOType {
        if let fromClientID = self.fromClientID,
            let currentClientID = self.currentClientID {
            return fromClientID == currentClientID ? .out : .in
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
        return IMClient.date(fromMillisecond: self.sentTimestamp)
    }
    
    /// The delivered timestamp of this message. measurement is millisecond.
    public var deliveredTimestamp: Int64?
    
    /// The delivered date of this message.
    public var deliveredDate: Date? {
        return IMClient.date(
            fromMillisecond: self.deliveredTimestamp)
    }
    
    /// The read timestamp of this message. measurement is millisecond.
    public var readTimestamp: Int64?
    
    /// The read date of this message.
    public var readDate: Date? {
        return IMClient.date(
            fromMillisecond: self.readTimestamp)
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
        return IMClient.date(
            fromMillisecond: self.patchedTimestamp)
    }
    
    /// Feature: @all.
    public var isAllMembersMentioned: Bool?
    
    /// Feature: @members.
    public var mentionedMembers: [String]?
    
    /// Indicates whether the current client has been @.
    public var isCurrentClientMentioned: Bool {
        if self.ioType == .in {
            if let allMentioned = self.isAllMembersMentioned,
                allMentioned {
                return true
            }
            if let clientID = self.currentClientID,
                let mentionedMembers = self.mentionedMembers,
                mentionedMembers.contains(clientID) {
                return true
            }
        }
        return false
    }
    
    /// Message Content.
    public enum Content {
        case string(String)
        case data(Data)
        
        public var string: String? {
            switch self {
            case let .string(v): return v
            default: return nil
            }
        }
        
        public var data: Data? {
            switch self {
            case let .data(v): return v
            default: return nil
            }
        }
    }
    
    /// @see `Content`.
    public internal(set) var content: Content?
    
    /// Set content for message.
    /// - Parameter content: @see `Content`.
    public func set(content: Content) throws {
        if self is IMCategorizedMessage {
            throw LCError(
                code: .inconsistency,
                reason:"content of `\(type(of: self))` can not be set directly.")
        } else {
            self.content = content
        }
    }
    
    public required init() {}
    
    static func instance(
        application: LCApplication,
        conversationID: String,
        currentClientID: IMClient.Identifier,
        fromClientID: IMClient.Identifier?,
        timestamp: Int64?,
        patchedTimestamp: Int64?,
        messageID: String?,
        content: Content?,
        isAllMembersMentioned: Bool? = nil,
        mentionedMembers: [String]? = nil,
        underlyingStatus: Status = .sent,
        isTransient: Bool = false)
        -> IMMessage
    {
        var message = IMMessage()
        if let stringContent = content?.string,
            stringContent.contains(IMCategorizedMessage.ReservedKey.type.rawValue) {
            do {
                if let rawData: [String: Any] = try stringContent.jsonObject(),
                    let typeNumber = rawData[IMCategorizedMessage.ReservedKey.type.rawValue] as? Int,
                    let messageType = IMCategorizedMessageTypeMap[typeNumber] {
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
        message.underlyingStatus = underlyingStatus
        return message
    }
    
    /// Whether the message is transient.
    public internal(set) var isTransient: Bool = false
    
    var isWill: Bool = false
    
    /// ref: https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md#消息
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
            assert(ID != nil && timestamp != nil)
            self.ID = ID
            self.sentTimestamp = timestamp
        }
    }
}

extension IMMessage {
    
    public func padding(unsafeFlutterObject: Any) {
        guard let data = unsafeFlutterObject as? [String: Any] else {
            return
        }
        if let conversationId = data["conversationId"] as? String {
            self.conversationID = conversationId
        }
        if let messageId = data["id"] as? String {
            self.ID = messageId
        }
        if let from = data["from"] as? String {
            self.fromClientID = from
        }
        if let timestamp = data["timestamp"] as? Int {
            self.sentTimestamp = Int64(timestamp)
        }
        if let ackAt = data["ackAt"] as? Int {
            self.deliveredTimestamp = Int64(ackAt)
        }
        if let readAt = data["readAt"] as? Int {
            self.readTimestamp = Int64(readAt)
        }
        if let _ = self.ID,
            let _ = self.sentTimestamp {
            self.underlyingStatus = .sent
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
        case name = "name"
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
    public static func register() throws {
        guard self.messageType > 0 else {
            throw LCError(
                code: .inconsistency,
                reason: "the value of message type should be a positive integer.")
        }
        IMCategorizedMessageTypeMap[self.messageType] = self
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
        let file = LCFile(
            application: application,
            payload: .data(
                data: data))
        self.file = file
        self.setFormatForFile(format: format, file: file)
    }
    
    public init(
        application: LCApplication = LCApplication.default,
        filePath: String,
        format: String? = nil)
    {
        super.init()
        let file = LCFile(
            application: application,
            payload: .fileURL(
                fileURL: URL(fileURLWithPath: filePath)))
        self.file = file
        self.setFormatForFile(format: format, file: file)
    }
    
    public init(
        application: LCApplication = LCApplication.default,
        url: URL,
        format: String? = nil)
    {
        super.init()
        let file = LCFile(
            application: application,
            url: url)
        self.file = file
        self.setFormatForFile(format: format, file: file)
    }

    @available(*, unavailable)
    public override func set(content: IMMessage.Content) throws {
        try super.set(content: content)
    }
    
    public internal(set) var rawData: [String: Any] = [:]
    
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
    
    /// The location data.
    public var location: LCGeoPoint?
    
    private(set) var fileMetaData: [String: Any]?
    
    fileprivate func decoding(rawData: [String: Any], application: LCApplication) {
        self.text = rawData[ReservedKey.text.rawValue] as? String
        self.attributes = rawData[ReservedKey.attributes.rawValue] as? [String: Any]
        if let fileData = rawData[ReservedKey.file.rawValue] as? [String: Any],
            let objectID = fileData[FileKey.objId.rawValue] as? String,
            let urlString = fileData[FileKey.url.rawValue] as? String {
            let file = LCFile(application: application, objectId: objectID)
            file.url = LCString(urlString)
            self.file = file
            self.fileMetaData = fileData[FileKey.metaData.rawValue] as? [String: Any]
        }
        if let locationData = rawData[ReservedKey.location.rawValue] as? [String: Any],
            let latitude = locationData[LocationKey.latitude.rawValue] as? Double,
            let longitude = locationData[LocationKey.longitude.rawValue] as? Double {
            self.location = LCGeoPoint(latitude: latitude, longitude: longitude)
        }
        self.rawData = rawData
    }
    
    fileprivate func decodingFileMetaData<T>(with key: FileKey) -> T? {
        return self.fileMetaData?[key.rawValue] as? T
    }
    
    func encodingMessageContent(application: LCApplication) throws {
        if type(of: self).messageType == ReservedType.none.rawValue,
            let _ = self.rawData[ReservedKey.type.rawValue] {
            /*
             For being compatible with Flutter Plugin SDK,
             DO NOT overwrite value of `_lctype` if it exists.
             */
        } else {
            self.rawData[ReservedKey.type.rawValue] = type(of: self).messageType
        }
        self.rawData[ReservedKey.text.rawValue] = self.text
        self.rawData[ReservedKey.attributes.rawValue] = self.attributes
        if let file = self.file,
            let objectID = file.objectId?.value,
            let url = file.url?.value {
            guard file.application === application else {
                throw LCError(
                    code: .inconsistency,
                    reason: "`file.application` !== `client.application`, they should be the same instance.")
            }
            var fileData: [String: Any] = [
                FileKey.objId.rawValue: objectID,
                FileKey.url.rawValue: url]
            if let metaData = try self.fileMetaData(from: file) {
                fileData[FileKey.metaData.rawValue] = metaData
                self.fileMetaData = metaData
            }
            self.rawData[ReservedKey.file.rawValue] = fileData
        } else {
            self.rawData[ReservedKey.file.rawValue] = nil
        }
        if let location = self.location {
            self.rawData[ReservedKey.location.rawValue] = [
                LocationKey.latitude.rawValue: location.latitude,
                LocationKey.longitude.rawValue: location.longitude]
        } else {
            self.rawData[ReservedKey.location.rawValue] = nil
        }
        let data = try JSONSerialization.data(withJSONObject: self.rawData)
        if let rawData = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.rawData = rawData
        }
        if let contentString = String(data: data, encoding: .utf8) {
            self.content = .string(contentString)
        }
    }
    
    private func setFormatForFile(format: String?, file: LCFile) {
        guard let format = format else {
            return
        }
        if let metaData = file.metaData {
            metaData[FileKey.format.rawValue] = LCString(format)
        } else {
            file.metaData = LCDictionary([FileKey.format.rawValue: format])
        }
    }
    
    private func fileMetaData(from file: LCFile) throws -> [String: Any]? {
        guard file.hasObjectId else {
            return nil
        }
        var metaData: [String: Any] = [:]
        if let name = file.name?.value {
            metaData[FileKey.name.rawValue] = name
        }
        if let size = file.metaData?[FileKey.size.rawValue]?.doubleValue {
            metaData[FileKey.size.rawValue] = size
        }
        if let format = file.metaData?[FileKey.format.rawValue]?.stringValue {
            metaData[FileKey.format.rawValue] = format
        } else if let format = (file.name?.value as NSString?)?.pathExtension
            ?? (file.url?.value as NSString?)?.pathExtension,
            !format.isEmpty {
            metaData[FileKey.format.rawValue] = format
        }
        if (self is IMImageMessage) {
            if let tuple = self.imageWidthHeight(from: file) {
                metaData[FileKey.width.rawValue] = tuple.width
                metaData[FileKey.height.rawValue] = tuple.height
            }
        } else if (self is IMAudioMessage) || (self is IMVideoMessage) {
            if let duration = try self.mediaDuration(
                from: file,
                format: metaData[FileKey.format.rawValue] as? String) {
                metaData[FileKey.duration.rawValue] = duration
            }
        }
        return metaData.isEmpty ? nil : (try metaData.jsonObject())
    }
    
    private func imageWidthHeight(from file: LCFile) -> (width: Double, height: Double)? {
        var tuple: (Double, Double)?
        if let metaData = file.metaData,
            let width = metaData[FileKey.width.rawValue]?.doubleValue,
            let height = metaData[FileKey.height.rawValue]?.doubleValue {
            tuple = (width, height)
        } else if let payload = file.payload {
            var imageData: Data?
            switch payload {
            case let .fileURL(fileURL: fileURL):
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    imageData = FileManager.default.contents(atPath: fileURL.path)
                }
            case let .data(data: data):
                imageData = data
            }
            if let data = imageData {
                #if os(iOS) || os(tvOS) || os(watchOS)
                if let image = UIImage(data: data) {
                    tuple = (Double(image.size.width * image.scale),
                             Double(image.size.height * image.scale))
                }
                #elseif os(macOS)
                if let image = NSImage(data: data) {
                    tuple = (Double(image.size.width),
                             Double(image.size.height))
                }
                #endif
            }
        }
        return tuple
    }
    
    private func mediaDuration(from file: LCFile, format: String?) throws -> Double? {
        var mediaDuration: Double?
        if let duration = file.metaData?[FileKey.duration.rawValue]?.doubleValue {
            mediaDuration = duration
        } else {
            var mediaURL: URL?
            var localTempFileURL: URL?
            if let payload = file.payload {
                switch payload {
                case let .fileURL(fileURL: fileURL):
                    mediaURL = fileURL
                case let .data(data: data):
                    var pathComponent = Utility.compactUUID
                    if let format = format {
                        pathComponent = "\(pathComponent).\(format)"
                    }
                    let tempFilePath = (NSTemporaryDirectory() as NSString)
                        .appendingPathComponent(pathComponent)
                    if FileManager.default.createFile(atPath: tempFilePath, contents: data) {
                        mediaURL = URL(fileURLWithPath: tempFilePath)
                        localTempFileURL = mediaURL
                    }
                }
            } else if let fileURLString = file.url?.value {
                mediaURL = URL(string: fileURLString)
            }
            if let mediaURL = mediaURL {
                if #available(iOS 7, macOS 10.9, tvOS 9, watchOS 6, *) {
                    mediaDuration = AVURLAsset(url: mediaURL).duration.seconds
                }
            }
            if let localTempFileURL = localTempFileURL {
                try FileManager.default.removeItem(at: localTempFileURL)
            }
        }
        return mediaDuration
    }
}

/// IM Text Message
open class IMTextMessage: IMCategorizedMessage {
    
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
open class IMImageMessage: IMCategorizedMessage {
    
    public class override var messageType: MessageType {
        return ReservedType.image.rawValue
    }
    
    /// The name of image.
    public var name: String? {
        return self.decodingFileMetaData(with: .name)
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
        if let urlString = self.file?.url?.value {
            return URL(string: urlString)
        } else {
            return nil
        }
    }
}

/// IM Audio Message
open class IMAudioMessage: IMCategorizedMessage {
    
    public class override var messageType: MessageType {
        return ReservedType.audio.rawValue
    }
    
    /// The name of audio.
    public var name: String? {
        return self.decodingFileMetaData(with: .name)
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
        if let urlString = self.file?.url?.value {
            return URL(string: urlString)
        } else {
            return nil
        }
    }
}

/// IM Video Message
open class IMVideoMessage: IMCategorizedMessage {
    
    public class override var messageType: MessageType {
        return ReservedType.video.rawValue
    }
    
    /// The name of video.
    public var name: String? {
        return self.decodingFileMetaData(with: .name)
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
        if let urlString = self.file?.url?.value {
            return URL(string: urlString)
        } else {
            return nil
        }
    }
}

/// IM File Message
open class IMFileMessage: IMCategorizedMessage {
    
    public class override var messageType: MessageType {
        return ReservedType.file.rawValue
    }
    
    /// The name of file.
    public var name: String? {
        return self.decodingFileMetaData(with: .name)
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
        if let urlString = self.file?.url?.value {
            return URL(string: urlString)
        } else {
            return nil
        }
    }
}

/// IM Location Message
open class IMLocationMessage: IMCategorizedMessage {
    
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
open class IMRecalledMessage: IMCategorizedMessage {
    
    /// Indicating whether this message was generated by recalling message function.
    public internal(set) var isRecall: Bool = false
    
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
    
    override func encodingMessageContent(application: LCApplication) throws {
        let rawData = [ReservedKey.type.rawValue: type(of: self).messageType]
        let data = try JSONSerialization.data(withJSONObject: rawData)
        if let rawData = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.rawData = rawData
        }
        if let contentString = String(data: data, encoding: .utf8) {
            self.content = .string(contentString)
        }
    }
}

extension IMDirectCommand {
    
    var lcMessageContent: IMMessage.Content? {
        /* always check `binaryMsg` firstly */
        if self.hasBinaryMsg {
            return .data(self.binaryMsg)
        } else if self.hasMsg {
            return .string(self.msg)
        }
        return nil
    }
}

extension IMUnreadTuple {
    
    var lcMessageContent: IMMessage.Content? {
        /* always check `binaryMsg` firstly */
        if self.hasBinaryMsg {
            return .data(self.binaryMsg)
        } else if self.hasData {
            return .string(self.data)
        }
        return nil
    }
}

extension IMPatchItem {
    
    var lcMessageContent: IMMessage.Content? {
        /* always check `binaryMsg` firstly */
        if self.hasBinaryMsg {
            return .data(self.binaryMsg)
        } else if self.hasData {
            return .string(self.data)
        }
        return nil
    }
}

extension IMLogItem {
    
    var lcMessageContent: IMMessage.Content? {
        if self.hasData {
            /* always check `binaryMsg` firstly */
            if self.hasBin, self.bin {
                if let data = Data(base64Encoded: self.data) {
                    return .data(data)
                }
            } else {
                return .string(self.data)
            }
        }
        return nil
    }
}
