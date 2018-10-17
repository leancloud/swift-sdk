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
public final class LCInstallation: LCObject {

    /// The badge of installation.
    @objc public dynamic var badge: LCNumber?

    /// The time zone of installtion.
    @objc public dynamic var timeZone: LCString?

    /// The channels of installation, which contains client ID of IM.
    @objc public dynamic var channels: LCArray?

    /// The type of device.
    @objc public dynamic var deviceType: LCString?

    /// The device token used to push notification.
    @objc public dynamic var deviceToken: LCString?

    /// The device profile. You can use this property to select one from mutiple push certificates or configurations.
    @objc public dynamic var deviceProfile: LCString?

    /// The installation ID of device, it's mainly for Android device.
    @objc public dynamic var installationId: LCString?

    /// The APNs topic of installation.
    @objc public dynamic var apnsTopic: LCString?

    /// The APNs Team ID of installation.
    @objc public dynamic var apnsTeamId: LCString?

    public override class func objectClassName() -> String {
        return "_Installation"
    }

    public required init() {
        super.init()

        initialize()
    }

    func initialize() {
        timeZone = NSTimeZone.system.identifier.lcString

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            apnsTopic = bundleIdentifier.lcString
        }

        #if os(iOS)
        deviceType = "ios"
        #elseif os(macOS)
        deviceType = "macos"
        #elseif os(watchOS)
        deviceType = "watchos"
        #elseif os(tvOS)
        deviceType = "tvos"
        #elseif os(Linux)
        deviceType = "linux"
        #elseif os(FreeBSD)
        deviceType = "freebsd"
        #elseif os(Android)
        deviceType = "android"
        #elseif os(PS4)
        deviceType = "ps4"
        #elseif os(Windows)
        deviceType = "windows"
        #elseif os(Cygwin)
        deviceType = "cygwin"
        #elseif os(Haiku)
        deviceType = "haiku"
        #endif
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
