//
//  Installation.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/10/12.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud installation type.
 */
public class LCInstallation: LCObject {

    /// The badge of installation.
    @objc dynamic public var badge: LCNumber?

    /// The time zone of installtion.
    @objc dynamic public var timeZone: LCString?

    /// The channels of installation, which contains client ID of IM.
    @objc dynamic public var channels: LCArray?

    /// The type of device.
    @objc dynamic public var deviceType: LCString?

    /// The device token used to push notification.
    @objc dynamic public private(set) var deviceToken: LCString?

    /// The device profile. You can use this property to select one from mutiple push certificates or configurations.
    @objc dynamic public var deviceProfile: LCString?

    /// The installation ID of device, it's mainly for Android device.
    @objc dynamic public var installationId: LCString?

    /// The APNs topic of installation.
    @objc dynamic public var apnsTopic: LCString?

    /// The APNs Team ID of installation.
    @objc dynamic public private(set) var apnsTeamId: LCString?

    public final override class func objectClassName() -> String {
        return "_Installation"
    }

    public required init() {
        super.init()

        self.timeZone = NSTimeZone.system.identifier.lcString
        
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            self.apnsTopic = bundleIdentifier.lcString
        }
        
        #if os(iOS)
        self.deviceType = "ios"
        #elseif os(macOS)
        self.deviceType = "macos"
        #elseif os(watchOS)
        self.deviceType = "watchos"
        #elseif os(tvOS)
        self.deviceType = "tvos"
        #endif
    }

    /**
     Set required properties for installation.

     - parameter deviceToken: The device token.
     - parameter deviceProfile: The device profile.
     - parameter apnsTeamId: The Team ID of your Apple Developer Account.
     */
    public func set(
        deviceToken: LCDeviceTokenConvertible,
        apnsTeamId: LCStringConvertible)
    {
        self.deviceToken = deviceToken.lcDeviceToken
        self.apnsTeamId = apnsTeamId.lcString
    }

    override func preferredBatchRequest(method: HTTPClient.Method, path: String, internalId: String) throws -> [String : Any]? {
        switch method {
        case .post, .put:
            var request: [String: Any] = [:]

            request["method"] = HTTPClient.Method.post.rawValue
            request["path"] = try HTTPClient.default.getBatchRequestPath(object: self, method: .post)

            if var body = dictionary.lconValue as? [String: Any] {
                body["__internalId"] = internalId

                body.removeValue(forKey: "createdAt")
                body.removeValue(forKey: "updatedAt")

                request["body"] = body
            }

            return request
        default:
            return nil
        }
    }

    override func validateBeforeSaving() throws {
        try super.validateBeforeSaving()

        guard let _ = deviceToken else {
            throw LCError(code: .inconsistency, reason: "Installation device token not found.")
        }
        guard let _ = apnsTeamId else {
            throw LCError(code: .inconsistency, reason: "Installation APNs team ID not found.")
        }
    }

    override func objectDidSave() {
        super.objectDidSave()

        let application = LCApplication.default

        if application.currentInstallation == self {
            application.storageContextCache.installation = self
        }
    }

}

extension LCApplication {

    public var currentInstallation: LCInstallation {
        return lc_lazyload("currentInstallation", .OBJC_ASSOCIATION_RETAIN) {
            storageContextCache.installation ?? LCInstallation()
        }
    }

}


public protocol LCDeviceTokenConvertible {

    var lcDeviceToken: LCString { get }

}

extension String: LCDeviceTokenConvertible {

    public var lcDeviceToken: LCString {
        return lcString
    }

}

extension NSString: LCDeviceTokenConvertible {

    public var lcDeviceToken: LCString {
        return (self as String).lcDeviceToken
    }

}

extension Data: LCDeviceTokenConvertible {

    public var lcDeviceToken: LCString {
        let string = map { String(format: "%02.2hhx", $0) }.joined()

        return LCString(string)
    }

}

extension NSData: LCDeviceTokenConvertible {

    public var lcDeviceToken: LCString {
        return (self as Data).lcDeviceToken
    }

}
