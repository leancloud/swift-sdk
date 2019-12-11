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
    
    func testSave() {
        let fileURL = bundleResourceURL(name: "test", ext: "png")
        XCTAssertTrue(LCFile(payload: .fileURL(fileURL: fileURL)).save().isSuccess)
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
