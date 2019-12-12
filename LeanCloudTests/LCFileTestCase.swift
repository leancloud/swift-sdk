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
    
    func testInitDeinit() {
        var f: LCFile! = LCFile()
        weak var wf = f
        f = nil
        XCTAssertNil(wf)
    }
    
    func testSave() {
        let fileURL = bundleResourceURL(name: "test", ext: "png")
        
        var file1: LCFile! = LCFile(payload: .fileURL(fileURL: fileURL))
        XCTAssertTrue(file1.save().isSuccess)
        XCTAssertNotNil(file1.mimeType)
        XCTAssertNotNil(file1.key)
        XCTAssertNotNil(file1.name)
        XCTAssertNotNil(file1.metaData?.size as? LCNumber)
        XCTAssertNotNil(file1.bucket)
        XCTAssertNotNil(file1.provider)
        XCTAssertNotNil(file1.url)
        XCTAssertNotNil(file1.objectId)
        
        var file2: LCFile! = LCFile(payload: .data(data: try! Data(contentsOf: fileURL)))
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
        
        var file3: LCFile! = LCFile(url: file2.url!)
        XCTAssertTrue(file3.save().isSuccess)
        XCTAssertNotNil(file3.mimeType)
        XCTAssertNotNil(file3.name)
        XCTAssertEqual(file3.metaData?.__source as? LCString, LCString("external"))
        XCTAssertNotNil(file3.url)
        XCTAssertNotNil(file3.objectId)
        
        XCTAssertNotNil(file1.save().error)
        XCTAssertNotNil(file2.save().error)
        XCTAssertNotNil(file3.save().error)
        
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
    
    func upload(payload: LCFile.Payload) {
        let file = LCFile(payload: payload)

        var result: LCBooleanResult?
        var progress: Double?

        _ = file.save(
            progress: { value in
                progress = value
            },
            completion: { aResult in
                result = aResult
            })

        busywait { result != nil }

        switch result! {
        case .success:
            break
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }

        XCTAssertNotNil(file.objectId)
        XCTAssertEqual(progress, 1)

        XCTAssertTrue(file.delete().isSuccess)
    }

    func testUploadData() {
        if let data = "Hello".data(using: .utf8) {
            upload(payload: .data(data: data))
        } else {
            XCTFail("Malformed data")
        }
    }

    func testUploadFile() {
        let bundle = Bundle(for: type(of: self))

        if let fileURL = bundle.url(forResource: "test", withExtension: "zip") {
            upload(payload: .fileURL(fileURL: fileURL))
        } else {
            XCTFail("File not found")
        }
    }

    func testUploadURL() {
        guard let url = URL(string: "https://example.com/image.png") else {
            XCTFail("Bad file URL")
            return
        }

        let file = LCFile(url: url)

        file.name = "image.png"
        file.mimeType = "image/png"

        XCTAssertTrue(file.save().isSuccess)

        let shadow = LCFile(objectId: file.objectId!)

        XCTAssertTrue(shadow.fetch().isSuccess)

        XCTAssertEqual(shadow.name, "image.png")
        XCTAssertEqual(shadow.mimeType, "image/png")
    }

    func testFilePointer() {
        let file = LCFile(url: "https://example.com/image.png")

        XCTAssertTrue(file.save().isSuccess)
        XCTAssertNotNil(file.objectId)

        let object = TestObject()

        object.fileField = file

        XCTAssertTrue(object.save().isSuccess)
        XCTAssertNotNil(object.objectId)

        let shadow = TestObject(objectId: object.objectId!)

        XCTAssertNil(shadow.fileField)
        XCTAssertTrue(shadow.fetch().isSuccess)
        XCTAssertNotNil(shadow.fileField)

        XCTAssertEqual(shadow.fileField, file)
    }
    
    func testThumbnailURL() {
        [bundleResourceURL(name: "test", ext: "jpg"),
         bundleResourceURL(name: "test", ext: "png")]
            .forEach { (url) in
                let file = LCFile(payload: .fileURL(fileURL: url))
                let thumbnails: [LCFile.Thumbnail] = [
                    .scale(0.5),
                    .size(width: 100, height: 100)]
                thumbnails.forEach { (thumbnail) in
                    XCTAssertNil(file.thumbnailURL(thumbnail))
                }
                XCTAssertTrue(file.save().isSuccess)
                thumbnails.forEach { (thumbnail) in
                    XCTAssertNotNil(UIImage(data: (try! Data(contentsOf: file.thumbnailURL(thumbnail)!))))
                }
        }
    }
    
    func testObjectPointFile() {
        do {
            let file = LCFile(
                payload: .fileURL(
                    fileURL: bundleResourceURL(name: "test", ext: "jpg")))
            XCTAssertTrue(file.save().isSuccess)
            
            let object = LCObject(className: "AssociateFile")
            try object.set("image", value: file)
            XCTAssertTrue(object.save().isSuccess)
            
            let fetchObject = LCObject(className: "AssociateFile", objectId: object.objectId!)
            XCTAssertTrue(fetchObject.fetch().isSuccess)
            XCTAssertTrue(fetchObject["image"] is LCFile)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testObjectPointNewFile() {
        let object1 = TestObject()
        object1.fileField = LCFile(url: "https://example.com/image.png")
        XCTAssertTrue(object1.save().isSuccess)
        
        let file = LCFile(objectId: object1.fileField!.objectId!)
        XCTAssertTrue(file.fetch().isSuccess)
        XCTAssertNotNil(file.metaData)
        XCTAssertNotNil(file.mimeType)
        XCTAssertNotNil(file.name)
        
        let object2 = TestObject()
        object2.fileField = LCFile(
            payload: .fileURL(
                fileURL: bundleResourceURL(name: "test", ext: "jpg")))
        XCTAssertNotNil(object2.save().error)
    }
}
