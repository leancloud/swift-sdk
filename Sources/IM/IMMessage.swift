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
    
    public enum IOType {
        case `in`
        case out
    }
    
    public final var ioType: IOType {
        if
            let fromClientID: String = self.fromClientID,
            let localClientID: String = self.localClientID,
            fromClientID == localClientID
        {
            return .out
        } else {
            return .in
        }
    }
    
    public final private(set) var fromClientID: String?
    
    private(set) var localClientID: String?
    
    public enum Status {
        case none
        case sending
        case sent
        case delivered
        case read
        case failed
    }
    
    public final var status: Status {
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
    private var underlyingStatus: Status = .none
    
    public final private(set) var ID: String?
    
    public final private(set) var conversationID: String?
    
    public final private(set) var sentTimestamp: Int64?
    public final var sentDate: Date? {
        return IMClient.date(fromMillisecond: sentTimestamp)
    }
    
    public final var deliveredTimestamp: Int64?
    public final var deliveredDate: Date? {
        return IMClient.date(fromMillisecond: deliveredTimestamp)
    }
    
    public final var readTimestamp: Int64?
    public final var readDate: Date? {
        return IMClient.date(fromMillisecond: readTimestamp)
    }
    
    public struct PatchedReason {
        public let code: Int?
        public let reason: String?
    }
    
    public final internal(set) var patchedTimestamp: Int64?
    public final var patchedDate: Date? {
        return IMClient.date(fromMillisecond: patchedTimestamp)
    }
    
    public final var isAllMembersMentioned: Bool?
    
    public final var mentionedMembers: [String]?
    
    public final var isCurrentClientMentioned: Bool {
        if self.ioType == .out {
            return false
        } else {
            if self.isAllMembersMentioned == true {
                return true
            }
            if let id: String = self.localClientID,
                self.mentionedMembers?.contains(id) == true {
                return true
            }
            return false
        }
    }
    
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
    
    public final fileprivate(set) var content: Content?
    
    public final func set(content: Content) throws {
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
        isTransient: Bool,
        conversationID: String,
        localClientID: String,
        fromClientID: String?,
        timestamp: Int64,
        patchedTimestamp: Int64?,
        messageID: String,
        content: Content?,
        isAllMembersMentioned: Bool?,
        mentionedMembers: [String]?)
        -> IMMessage
    {
        var message = IMMessage()
        do {
            let lcTypeKey: String = IMCategorizedMessage.ReservedKey.type.rawValue
            if let string: String = content?.string,
                string.contains(lcTypeKey),
                let rawData: [String: Any] = try string.jsonObject(),
                let typeNumber: Int = rawData[lcTypeKey] as? Int,
                let messageClass: IMCategorizedMessage.Type = LCCategorizedMessageMap[typeNumber]
            {
                let categorizedMessage = messageClass.init()
                categorizedMessage.decoding(with: rawData)
                message = categorizedMessage
            }
        } catch {
            Logger.shared.verbose(error)
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
        message.localClientID = localClientID
        message.underlyingStatus = .sent
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
    
    func setup(clientID: String, conversationID: String) {
        self.fromClientID = clientID
        self.localClientID = clientID
        self.conversationID = conversationID
    }
    
    func update(status newStatus: IMMessage.Status, ID: String? = nil, timestamp: Int64? = nil) {
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

private var LCCategorizedMessageMap: [Int: IMCategorizedMessage.Type] = [
    IMCategorizedMessage.ReservedType.none.rawValue: IMCategorizedMessage.self,
    IMCategorizedMessage.ReservedType.text.rawValue: IMTextMessage.self,
    IMCategorizedMessage.ReservedType.image.rawValue: IMImageMessage.self,
    IMCategorizedMessage.ReservedType.audio.rawValue: IMAudioMessage.self,
    IMCategorizedMessage.ReservedType.video.rawValue: IMVideoMessage.self,
    IMCategorizedMessage.ReservedType.location.rawValue: IMLocationMessage.self,
    IMCategorizedMessage.ReservedType.file.rawValue: IMFileMessage.self,
    IMCategorizedMessage.ReservedType.recalled.rawValue: IMRecalledMessage.self
]

public protocol IMMessageCategorizing {
    
    typealias MessageType = Int
    
    var type: MessageType { get }
    
}

open class IMCategorizedMessage: IMMessage, IMMessageCategorizing {
    
    enum ReservedType: MessageType {
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
    
    public static func register() throws {
        let type: Int = self.init().type
        guard type > 0 else {
            throw LCError(
                code: .inconsistency,
                reason: "The value of the customized message's type should be a positive integer"
            )
        }
        LCCategorizedMessageMap[type] = self
    }
    
    public var type: MessageType {
        return ReservedType.none.rawValue
    }
    
    public required init() { super.init() }
    
    var rawData: [String: Any] = [:]
    
    public final subscript(key: String) -> Any? {
        set {
            self.rawData[key] = newValue
        }
        get {
            return self.rawData[key]
        }
    }
    
    public final var text: String?
    
    public final var attributes: [String: Any]?
    
    public final var file: LCFile?
    
    internal private(set) var fileMetaData: [String: Any]?
    
    public final var location: LCGeoPoint?
    
    fileprivate func decoding(with rawData: [String: Any]) {
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
            let file = LCFile(objectId: objectID)
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
        self.rawData[ReservedKey.type.rawValue] = self.type
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
    
}

public final class IMTextMessage: IMCategorizedMessage {
    
    public override var type: MessageType {
        return ReservedType.text.rawValue
    }
    
}

public final class IMImageMessage: IMCategorizedMessage {
    
    public override var type: MessageType {
        return ReservedType.image.rawValue
    }
    
    public final var width: Double? {
        return self.decodingFileMetaData(with: .width)
    }
    
    public final var height: Double? {
        return self.decodingFileMetaData(with: .height)
    }
    
    public final var size: Double? {
        return self.decodingFileMetaData(with: .size)
    }
    
    public final var format: String? {
        return self.decodingFileMetaData(with: .format)
    }
    
    public final var url: URL? {
        if let urlString: String = self.file?.url?.value,
            let url: URL = URL(string: urlString) {
            return url
        } else {
            return nil
        }
    }
    
}

public final class IMAudioMessage: IMCategorizedMessage {
    
    public override var type: MessageType {
        return ReservedType.audio.rawValue
    }
    
    public final var duration: Double? {
        return self.decodingFileMetaData(with: .duration)
    }
    
    public final var size: Double? {
        return self.decodingFileMetaData(with: .size)
    }
    
    public final var format: String? {
        return self.decodingFileMetaData(with: .format)
    }
    
    public final var url: URL? {
        if let urlString: String = self.file?.url?.value,
            let url: URL = URL(string: urlString) {
            return url
        } else {
            return nil
        }
    }
    
}

public final class IMVideoMessage: IMCategorizedMessage {
    
    public override var type: MessageType {
        return ReservedType.video.rawValue
    }
    
    public final var duration: Double? {
        return self.decodingFileMetaData(with: .duration)
    }
    
    public final var size: Double? {
        return self.decodingFileMetaData(with: .size)
    }
    
    public final var format: String? {
        return self.decodingFileMetaData(with: .format)
    }
    
    public final var url: URL? {
        if let urlString: String = self.file?.url?.value,
            let url: URL = URL(string: urlString) {
            return url
        } else {
            return nil
        }
    }
    
}

public final class IMFileMessage: IMCategorizedMessage {
    
    public override var type: MessageType {
        return ReservedType.file.rawValue
    }
    
    public final var size: Double? {
        return self.decodingFileMetaData(with: .size)
    }
    
    public final var format: String? {
        return self.decodingFileMetaData(with: .format)
    }
    
    public final var url: URL? {
        if let urlString: String = self.file?.url?.value,
            let url: URL = URL(string: urlString) {
            return url
        } else {
            return nil
        }
    }
    
}

public final class IMLocationMessage: IMCategorizedMessage {
    
    public override var type: MessageType {
        return ReservedType.location.rawValue
    }
    
    public final var latitude: Double? {
        return self.location?.latitude
    }
    
    public final var longitude: Double? {
        return self.location?.longitude
    }
    
}

public final class IMRecalledMessage: IMCategorizedMessage {
    
    public override var type: MessageType {
        return ReservedType.recalled.rawValue
    }
    
}
