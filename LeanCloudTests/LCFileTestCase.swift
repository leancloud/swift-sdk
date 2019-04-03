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
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
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
    
}
