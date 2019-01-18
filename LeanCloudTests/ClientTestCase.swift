//
//  ClientTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2018/11/28.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class LCClientTestCase: BaseTestCase {
    
    var uuid: String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    
    class Delegator: LCClientDelegate {
        
        var clientEvent: ((_ client: LCClient, _ event: LCClientEvent) -> Void)?
        
        func client(_ client: LCClient, event: LCClientEvent) {
            clientEvent?(client, event)
        }
        
        var conversationEvent: ((_ client: LCClient, _ conversation: LCConversation, _ event: LCConversationEvent) -> Void)?
        
        func client(_ client: LCClient, conversation: LCConversation, event: LCConversationEvent) {
            conversationEvent?(client, conversation, event)
        }
        
    }

    func testClientOpenAndClose() {
        
        let client: LCClient = try! LCClient(ID: uuid)
        let count: Int = 3
        
        for _ in 0..<count {
            
            let exp = expectation(description: "client open success")
            exp.expectedFulfillmentCount = 3
            
            client.open { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(result.error)
                exp.fulfill()
                client.open { (result) in
                    XCTAssertNotNil(result.error)
                    exp.fulfill()
                    client.close() { (result) in
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertNil(result.error)
                        exp.fulfill()
                    }
                }
            }
            
            waitForExpectations(timeout: timeout, handler: nil)
        }
    }
    
    func testClientSessionConflict() {
        
        let clientID: String = uuid
        let tag: String = "tag"
        
        let application1: LCApplication = LCApplication(
            id: LCApplication.default.id,
            key: LCApplication.default.key
        )
        application1.currentInstallation.set(
            deviceToken: uuid,
            apnsTeamId: ""
        )
        let delegator1: Delegator = Delegator()
        let client1: LCClient = try! LCClient(
            ID: clientID,
            tag: tag,
            delegate: delegator1,
            application: application1
        )
        
        let exp1 = expectation(description: "client1 open success")
        
        client1.open { (result) in
            XCTAssertNil(result.error)
            exp1.fulfill()
        }
        
        wait(for: [exp1], timeout: timeout)
        
        let application2: LCApplication = LCApplication(
            id: LCApplication.default.id,
            key: LCApplication.default.key
        )
        application2.currentInstallation.set(
            deviceToken: uuid,
            apnsTeamId: ""
        )
        let delegator2: Delegator = Delegator()
        let client2: LCClient = try! LCClient(
            ID: clientID,
            tag: tag,
            delegate: delegator2,
            application: application2
        )
        
        let exp2 = expectation(description: "client2 open success & kick client1 success")
        exp2.expectedFulfillmentCount = 2
        
        delegator1.clientEvent = { client, event in
            XCTAssertTrue(Thread.isMainThread)
            if client === client1,
                case let .sessionDidClose(error: error) = event {
                XCTAssertEqual(
                    error.code,
                    LCError.ServerErrorCode.sessionConflict.rawValue
                )
                exp2.fulfill()
            }
        }
        client2.open { (result) in
            XCTAssertNil(result.error)
            exp2.fulfill()
        }
        
        wait(for: [exp2], timeout: timeout)
        
        let exp3 = expectation(description: "client1 resume with deviceToken1 fail, and set deviceToken2 then resume success")
        exp3.expectedFulfillmentCount = 2
        
        client1.open(options: []) { (result) in
            XCTAssertEqual(
                result.error?.code,
                LCError.ServerErrorCode.sessionConflict.rawValue
            )
            application1.currentInstallation.set(
                deviceToken: application2.currentInstallation.deviceToken!.value,
                apnsTeamId: ""
            )
            client1.open(options: []) { (result) in
                XCTAssertNil(result.error)
                exp3.fulfill()
            }
            exp3.fulfill()
        }
        
        wait(for: [exp3], timeout: timeout)
    }
    
    func testClientReportDeviceToken() {
        
        let client: LCClient = try! LCClient(ID: uuid)
        
        let exp = expectation(description: "client report device token success")
        exp.expectedFulfillmentCount = 2
        
        client.open { (result) in
            XCTAssertNil(result.error)
            client.installation.set(deviceToken: self.uuid, apnsTeamId: "")
            exp.fulfill()
        }
        let _ = NotificationCenter.default.addObserver(forName: LCClient.TestReportDeviceTokenNotification, object: client, queue: OperationQueue.main) { (notification) in
            let result = notification.userInfo?["result"] as! Connection.CommandCallback.Result
            XCTAssertEqual(result.command?.cmd, .report)
            XCTAssertEqual(result.command?.op, .uploaded)
            exp.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
    }

}
