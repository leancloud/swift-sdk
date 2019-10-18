//
//  LCLocalStorageContextTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2019/4/10.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCLocalStorageTestCase: BaseTestCase {
    
    var application: LCApplication!
    var localStorage: LocalStorageContext {
        return application.localStorageContext!
    }
    
    let tuples: [(LocalStorageContext.Place, LocalStorageContext.Module, LocalStorageContext.File)] = [
        (.systemCaches, .router, .appServer),
        (.systemCaches, .router, .rtmServer),
        (.systemCaches, .push, .installation),
        (.persistentData, .storage, .user),
        (.persistentData, .IM(clientID: UUID().uuidString), .clientRecord),
        (.persistentData, .IM(clientID: UUID().uuidString), .database)
    ]
    
    override func setUp() {
        super.setUp()
        self.application = try! LCApplication(
            id: UUID().uuidString,
            key: UUID().uuidString,
            serverURL: "leancloud.cn")
    }
    
    override func tearDown() {
        [self.application.applicationSupportDirectoryURL,
         self.application.cachesDirectoryURL]
            .forEach { (url) in
                if FileManager.default.fileExists(atPath: url.path) {
                    try! FileManager.default.removeItem(at: url)
                }
        }
        self.application.unregister()
        super.tearDown()
    }
    
    func testInitAndDeinit() {
        var ref: LocalStorageContext? = LocalStorageContext(application: self.application)
        weak var weakRef: LocalStorageContext? = ref
        ref = nil
        XCTAssertNil(weakRef)
    }
    
    func testFileURL() {
        self.tuples.forEach { (place, module, file)  in
            let fileURL = try! self.localStorage.fileURL(
                place: place,
                module: module,
                file: file)
            let systemPath: String
            switch place {
            case .systemCaches:
                systemPath = "Library/Caches/"
            case .persistentData:
                systemPath = "Library/Application Support/"
            }
            XCTAssertTrue(fileURL.path.hasSuffix(systemPath
                + LocalStorageContext.domain + "/"
                + self.localStorage.application.id.md5.lowercased() + "/"
                + module.path + "/"
                + file.name))
            var isDirectory: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(
                atPath: fileURL.deletingLastPathComponent().path,
                isDirectory: &isDirectory))
            XCTAssertTrue(isDirectory.boolValue)
        }
    }
    
    func testSaveAndGet() {
        self.tuples.forEach { (place, module, file) in
            let fileURL = try! self.localStorage.fileURL(
                place: place,
                module: module,
                file: file)
            let saveTable = TestTable(string: UUID().uuidString)
            try! self.localStorage.save(table: saveTable, to: fileURL)
            var isDirectory: ObjCBool = true
            XCTAssertTrue(FileManager.default.fileExists(
                atPath: fileURL.path,
                isDirectory: &isDirectory))
            XCTAssertFalse(isDirectory.boolValue)
            let getTable: TestTable? = try! self.localStorage.table(from: fileURL)
            XCTAssertNotNil(getTable)
            XCTAssertEqual(getTable?.string, saveTable.string)
            try! self.localStorage.clear(file: fileURL)
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: fileURL.path))
        }
    }

}

extension LCLocalStorageTestCase {
    
    struct TestTable: Codable {
        var string: String?
    }
}
