//
//  LCFileTestCase.swift
//  LeanCloudTests
//
//  Created by Tianyong Tang on 2018/9/20.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCFileTestCase: BaseTestCase {
    
    func testDeinit() {
        var f: LCFile! = LCFile()
        weak var wf = f
        f = nil
        XCTAssertNil(wf)
    }
    
    func testSave() {
        let fileURL = bundleResourceURL(name: "test", ext: "png")
        let application = LCApplication.default
        
        var file1: LCFile! = LCFile(
            application: application,
            payload: .fileURL(fileURL: fileURL))
        XCTAssertTrue(file1.save().isSuccess)
        XCTAssertNotNil(file1.mimeType)
        XCTAssertNotNil(file1.key)
        XCTAssertNotNil(file1.name)
        XCTAssertNotNil(file1.metaData?.size as? LCNumber)
        XCTAssertNotNil(file1.bucket)
        XCTAssertNotNil(file1.provider)
        XCTAssertNotNil(file1.url)
        XCTAssertNotNil(file1.objectId)
        XCTAssertNotNil(file1.createdAt)
        XCTAssertNotNil(file1.save().error)
        
        var file2: LCFile! = LCFile(
            application: application,
            payload: .data(data: try! Data(contentsOf: fileURL)))
        file2.name = "image.png"
        XCTAssertTrue(file2.save().isSuccess)
        XCTAssertNotNil(file2.mimeType)
        XCTAssertNotNil(file2.key)
        XCTAssertNotNil(file2.name)
        XCTAssertNotNil(file2.metaData?.size as? LCNumber)
        XCTAssertNotNil(file2.bucket)
        XCTAssertNotNil(file2.provider)
        XCTAssertNotNil(file2.url)
        XCTAssertNotNil(file2.objectId)
        XCTAssertNotNil(file2.createdAt)
        XCTAssertNotNil(file2.save().error)
        
        var file3: LCFile! = LCFile(
            application: application,
            url: file2.url!)
        XCTAssertTrue(file3.save().isSuccess)
        XCTAssertNotNil(file3.mimeType)
        XCTAssertNotNil(file3.name)
        XCTAssertEqual(file3.metaData?.__source as? LCString, LCString("external"))
        XCTAssertNotNil(file3.url)
        XCTAssertNotNil(file3.objectId)
        XCTAssertNotNil(file3.createdAt)
        XCTAssertNotNil(file3.save().error)
        
        delay()
        
        weak var wFile1 = file1
        weak var wFile2 = file2
        weak var wFile3 = file3
        file1 = nil
        file2 = nil
        file3 = nil
        XCTAssertNil(wFile1)
        XCTAssertNil(wFile2)
        XCTAssertNil(wFile3)
    }
    
    func testSaveAsync() {
        let fileURL = bundleResourceURL(name: "test", ext: "png")
        var file: LCFile! = LCFile(payload: .fileURL(fileURL: fileURL))
        
        expecting { (exp) in
            file.save(progress: { (progress) in
                XCTAssertTrue(Thread.isMainThread)
                print(progress)
            }) { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            }
        }
        
        delay()
        
        weak var wf: LCFile? = file
        file = nil
        XCTAssertNil(wf)
    }
    
    func testSaveOptions() {
        let fileURL = bundleResourceURL(name: "test", ext: "png")
        let file = LCFile(payload: .fileURL(fileURL: fileURL))
        XCTAssertTrue(file.save(options: .keepFileName).isSuccess)
        XCTAssertTrue(file.url!.value.hasSuffix("/test.png"))
    }
    
    func testFetch() {
        let fileURL = bundleResourceURL(name: "test", ext: "png")
        let savedFile = LCFile(payload: .fileURL(fileURL: fileURL))
        XCTAssertTrue(savedFile.save().isSuccess)
        
        let file = LCFile(objectId: savedFile.objectId!)
        XCTAssertTrue(file.fetch().isSuccess)
        XCTAssertEqual(savedFile.mimeType, file.mimeType)
        XCTAssertEqual(savedFile.key, file.key)
        XCTAssertEqual(savedFile.name, file.name)
        XCTAssertEqual(savedFile.metaData?.size as? LCNumber, file.metaData?.size as? LCNumber)
        XCTAssertEqual(savedFile.bucket, file.bucket)
        XCTAssertEqual(savedFile.provider, file.provider)
        XCTAssertEqual(savedFile.url, file.url)
        XCTAssertEqual(savedFile.objectId, file.objectId)
        XCTAssertEqual(savedFile.createdAt, file.createdAt)
    }
    
    func testPointer() {
        let fileURL = bundleResourceURL(name: "test", ext: "png")
        let file = LCFile(payload: .fileURL(fileURL: fileURL))
        XCTAssertTrue(file.save().isSuccess)
        
        let object = self.object()
        object.fileField = file
        XCTAssertTrue(object.save().isSuccess)
        
        let objectShadow = self.object(object.objectId!)
        XCTAssertTrue(objectShadow.fetch().isSuccess)
        
        let shadowFile = objectShadow.fileField as? LCFile
        XCTAssertNotNil(shadowFile)
        XCTAssertEqual(shadowFile?.mimeType, file.mimeType)
        XCTAssertEqual(shadowFile?.key, file.key)
        XCTAssertEqual(shadowFile?.name, file.name)
        XCTAssertEqual(shadowFile?.metaData?.size as? LCNumber, file.metaData?.size as? LCNumber)
        XCTAssertEqual(shadowFile?.bucket, file.bucket)
        XCTAssertEqual(shadowFile?.provider, file.provider)
        XCTAssertEqual(shadowFile?.url, file.url)
        XCTAssertEqual(shadowFile?.objectId, file.objectId)
        XCTAssertEqual(shadowFile?.createdAt, file.createdAt)
        
        object.fileField = LCFile(payload: .fileURL(fileURL: fileURL))
        XCTAssertNotNil(object.save().error)
        object.fileField = LCFile(url: file.url!)
        XCTAssertTrue(object.save().isSuccess)
        
        object.filesField = [
            LCFile(payload: .fileURL(fileURL: fileURL)),
            LCFile(payload: .fileURL(fileURL: fileURL))]
        XCTAssertNotNil(object.save().error)
        object.filesField = [LCFile(url: file.url!), LCFile(url: file.url!)]
        XCTAssertTrue(object.save().isSuccess)
        
        object.fileMapField = ["file1": LCFile(payload: .fileURL(fileURL: fileURL))]
        XCTAssertNotNil(object.save().error)
        object.fileMapField = ["file1": LCFile(url: file.url!)]
        XCTAssertTrue(object.save().isSuccess)
    }
}
