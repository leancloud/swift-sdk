//
//  LCApplicationTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2019/5/7.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCApplicationTestCase: BaseTestCase {

    func testClearLocalStorage() {
        for url in [LCApplication.default.localStorageContext!.applicationSupportDirectoryPath,
                    LCApplication.default.localStorageContext!.cachesDirectoryPath]
        {
            if FileManager.default.fileExists(atPath: url.path) {
                try! FileManager.default.removeItem(at: url)
            }
        }
    }

}
