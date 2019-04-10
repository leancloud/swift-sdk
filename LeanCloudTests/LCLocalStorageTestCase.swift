//
//  LCLocalStorageTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2019/4/10.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCLocalStorageTestCase: BaseTestCase {
    
    func testInitAndDeinit() {
        var instance: LocalStorageContext!
        
        do {
            let applicationID: String = "test"
            instance = try LocalStorageContext(applicationID: applicationID)
            
            print(instance.applicationSupportDirectoryPath.path)
            print(instance.cachesDirectoryPath.path)
            
            XCTAssertTrue(instance.applicationSupportDirectoryPath.path.contains("Library/Application Support"))
            XCTAssertTrue(instance.cachesDirectoryPath.path.contains("Library/Caches"))
            XCTAssertTrue(instance.applicationSupportDirectoryPath.path.contains(LocalStorageContext.domain))
            XCTAssertTrue(instance.cachesDirectoryPath.path.contains(LocalStorageContext.domain))
            XCTAssertTrue(instance.applicationSupportDirectoryPath.path.contains(applicationID.md5.lowercased()))
            XCTAssertTrue(instance.cachesDirectoryPath.path.contains(applicationID.md5.lowercased()))
            
            var objcBool: ObjCBool = false
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: instance.applicationSupportDirectoryPath.path, isDirectory: &objcBool))
            XCTAssertTrue(objcBool.boolValue)
            
            objcBool = false
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: instance.cachesDirectoryPath.path, isDirectory: &objcBool))
            XCTAssertTrue(objcBool.boolValue)
        } catch {
            XCTFail("\(error)")
        }
        
        weak var weakRef: LocalStorageContext? = instance
        instance = nil
        XCTAssertNil(weakRef)
    }
    
    func testFileURL() {
        let localStorage = try! LocalStorageContext(applicationID: "test")
        
        let clientID = "clientID"
        let persistentPath = try! localStorage.fileURL(place: .persistentData, module: .IM(clientID: clientID), file: .clientRecord).path
        print(persistentPath)
        XCTAssertTrue(persistentPath.contains("Library/Application Support"))
        XCTAssertTrue(persistentPath.contains("IM"))
        XCTAssertTrue(persistentPath.contains(clientID.md5.lowercased()))
        XCTAssertTrue(persistentPath.contains(LocalStorageContext.File.clientRecord.name))
        
        let systemCachesPath = try! localStorage.fileURL(place: .systemCaches, module: .push, file: .installation).path
        print(systemCachesPath)
        XCTAssertTrue(systemCachesPath.contains("Library/Caches"))
        XCTAssertTrue(systemCachesPath.contains(LocalStorageContext.Module.push.path))
        XCTAssertTrue(systemCachesPath.contains(LocalStorageContext.File.installation.name))
    }
    
    func testSaveAndGet() {
        let localStorage = try! LocalStorageContext(applicationID: "test")
        
        let persistentURL = try! localStorage.fileURL(place: .persistentData, module: .IM(clientID: "clientID"), file: .clientRecord)
        
        let testCodable = TestCodable(string: "string")
        
        try! localStorage.save(table: testCodable, to: persistentURL)
        
        var objcBool: ObjCBool = true
        XCTAssertTrue(FileManager.default.fileExists(atPath: persistentURL.path, isDirectory: &objcBool))
        XCTAssertFalse(objcBool.boolValue)
        
        let table: TestCodable? = try! localStorage.table(from: persistentURL)
        XCTAssertEqual(table?.string, "string")
    }

}

extension LCLocalStorageTestCase {
    
    struct TestCodable: Codable {
        
        var string: String?
    }
    
}
