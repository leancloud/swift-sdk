//
//  LocalStorage.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/9/17.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

class LocalStorageContext {
    static let domain: String = "com.leancloud.swift"
    
    enum Place {
        case systemCaches
        case persistentData
        
        var searchPathDirectory: FileManager.SearchPathDirectory {
            switch self {
            case .systemCaches:
                return .cachesDirectory
            case .persistentData:
                return .applicationSupportDirectory
            }
        }
    }
    
    enum Module {
        case router
        case storage
        case push
        case IM(clientID: String)
        
        var path: String {
            switch self {
            case .router:
                return "router"
            case .storage:
                return "storage"
            case .push:
                return "push"
            case .IM(clientID: let clientID):
                return ("IM" as NSString)
                    .appendingPathComponent(
                        clientID.md5.lowercased())
            }
        }
    }
    
    enum File: String {
        // App Router Data
        case appServer = "app_server"
        // RTM Router Data
        case rtmServer = "rtm_server"
        // Application's Current User
        case user = "user"
        // Application's Current Installation
        case installation = "installation"
        // IMClient's local data
        case clientRecord = "client_record"
        // Database for IMConversation and IMMessage
        case database = "database.sqlite"
        
        var name: String {
            return self.rawValue
        }
    }
    
    let application: LCApplication
    
    init(application: LCApplication) {
        self.application = application
    }
    
    func fileURL(place: Place, module: Module, file: File) throws -> URL {
        let moduleDirectoryURL = (
            try FileManager.default.url(
                for: place.searchPathDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true))
            .appendingPathComponent(
                LocalStorageContext.domain,
                isDirectory: true)
            .appendingPathComponent(
                self.application.id.md5.lowercased(),
                isDirectory: true)
            .appendingPathComponent(
                module.path,
                isDirectory: true)
        try FileManager.default.createDirectory(
            at: moduleDirectoryURL,
            withIntermediateDirectories: true)
        return moduleDirectoryURL.appendingPathComponent(
            file.name)
    }
    
    func save<T: Codable>(table: T, to fileURL: URL, encoder: JSONEncoder = JSONEncoder()) throws {
        let tempFileURL: URL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(Utility.compactUUID)
        try (try encoder.encode(table))
            .write(to: tempFileURL)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.replaceItem(
                at: fileURL,
                withItemAt: tempFileURL,
                backupItemName: nil,
                resultingItemURL: nil)
        } else {
            try FileManager.default.moveItem(
                atPath: tempFileURL.path,
                toPath: fileURL.path)
        }
    }
    
    func table<T: Codable>(from fileURL: URL, decoder: JSONDecoder = JSONDecoder()) throws -> T? {
        guard FileManager.default.fileExists(atPath: fileURL.path),
            let data = FileManager.default.contents(atPath: fileURL.path) else {
                return nil
        }
        return try decoder.decode(T.self, from: data)
    }
    
    func clear(file fileURL: URL) throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(atPath: fileURL.path)
        }
    }
    
}
