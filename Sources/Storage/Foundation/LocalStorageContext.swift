//
//  LocalStorageContext.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/9/17.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

class LocalStorageContext {
    
    enum Place {
        case systemCaches
        case persistentData
    }
    
    /*
     This struct is used to record which domain has been deprecated.
     
     !!! Should Never Use Deprecated Domain !!!
     */
    private struct DeprecatedDomain {
        /// due to need a tag to identify objc-sdk and swift-sdk.
        static let domain1 = "LeanCloud"
    }
    
    static let domain: String = "com.leancloud.swift"
    
    enum Module {
        case router
        case push
        case IM(clientID: String)
        
        var path: String {
            switch self {
            case .router:
                return "router"
            case .push:
                return "push"
            case .IM(clientID: let clientID):
                let md5: String = clientID.md5.lowercased()
                return ("IM" as NSString).appendingPathComponent(md5)
            }
        }
    }
    
    enum File: String {
        case appServer = "app_server"
        case rtmServer = "rtm_server"
        case installation = "installation"
        case clientRecord = "client_record"
        case database = "database.sqlite"
        
        var name: String {
            return self.rawValue
        }
    }
    
    let cachesDirectoryPath: URL
    let applicationSupportDirectoryPath: URL
    
    init(applicationID: String) throws {
        let directoryInUserDomain: (FileManager.SearchPathDirectory) throws -> URL = {
            return try FileManager.default.url(
                for: $0,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }
        let systemCachesDirectory: URL = try directoryInUserDomain(.cachesDirectory)
        let systemApplicationSupportDirectory: URL = try directoryInUserDomain(.applicationSupportDirectory)
        
        let appIDMD5: String = applicationID.md5.lowercased()
        
        let appDirectoryPath: (URL) throws -> URL = {
            let pathURL: URL = $0
                .appendingPathComponent(LocalStorageContext.domain, isDirectory: true)
                .appendingPathComponent(appIDMD5, isDirectory: true)
            try FileManager.default.createDirectory(
                at: pathURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return pathURL
        }
        self.cachesDirectoryPath = try appDirectoryPath(systemCachesDirectory)
        self.applicationSupportDirectoryPath = try appDirectoryPath(systemApplicationSupportDirectory)
    }
    
    func fileURL(place: Place, module: Module, file: File) throws -> URL {
        var rootDirectory: URL
        switch place {
        case .systemCaches:
            rootDirectory = self.cachesDirectoryPath
        case .persistentData:
            rootDirectory = self.applicationSupportDirectoryPath
        }
        let directoryURL = rootDirectory.appendingPathComponent(module.path, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directoryURL.appendingPathComponent(file.name)
    }
    
    func save<T: Codable>(table: T, to fileURL: URL, encoder: JSONEncoder = JSONEncoder()) throws {
        let filePath = fileURL.path
        let data: Data = try encoder.encode(table)
        let tmpFileURL: URL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try data.write(to: tmpFileURL)
        if FileManager.default.fileExists(atPath: filePath) {
            try FileManager.default.replaceItem(
                at: fileURL,
                withItemAt: tmpFileURL,
                backupItemName: nil,
                resultingItemURL: nil
            )
        } else {
            try FileManager.default.moveItem(
                atPath: tmpFileURL.path,
                toPath: filePath
            )
        }
    }
    
    func table<T: Codable>(from fileURL: URL, decoder: JSONDecoder = JSONDecoder()) throws -> T? {
        let filePath = fileURL.path
        guard
            FileManager.default.fileExists(atPath: filePath),
            let data = FileManager.default.contents(atPath: filePath)
            else
        {
            return nil
        }
        return try decoder.decode(T.self, from: data)
    }
    
    func clear(file fileURL: URL) throws {
        let filePath = fileURL.path
        if FileManager.default.fileExists(atPath: filePath) {
            try FileManager.default.removeItem(atPath: filePath)
        }
    }
    
}
