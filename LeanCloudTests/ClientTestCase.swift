//
//  ClientTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2018/11/28.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class ClientTestCase: BaseTestCase {

    func testClientOpenClose() {
        
        let client = try! LCClient(id: String(#function[..<#function.index(of: "(")!]))
        
        for _ in 0..<3 {
            
            let exp = self.expectation(description: "client open success")
            exp.expectedFulfillmentCount = 2
            exp.assertForOverFulfill = true
            
            client.open { (result) in
                
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(result.error)
                exp.fulfill()
                
                client.close() { (result) in
                
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertNil(result.error)
                    exp.fulfill()
                }
            }
            
            self.waitForExpectations(timeout: 600)
        }
    }
    
    func testClientSessionConflict() {
        
        let id = String(#function[..<#function.index(of: "(")!])
        let tag = "tag"
        
        let application1 = LCApplication(id: LCApplication.default.id, key: LCApplication.default.key)
        let deviceToken1 = UUID().uuidString
        application1.currentInstallation.set(deviceToken: deviceToken1, apnsTeamId: "")
        let delegator1 = ClientDelegator()
        let client1 = try! LCClient(id: id, tag: tag, delegate: delegator1, application: application1)
        
        let application2 = LCApplication(id: LCApplication.default.id, key: LCApplication.default.key)
        let deviceToken2 = UUID().uuidString
        application2.currentInstallation.set(deviceToken: deviceToken2, apnsTeamId: "")
        let delegator2 = ClientDelegator()
        let client2 = try! LCClient(id: id, tag: tag, delegate: delegator2, application: application2)
        
        let exp1 = self.expectation(description: "client1 open success")
        
        client1.open { (result) in
            
            XCTAssertNil(result.error)
            exp1.fulfill()
        }
        
        self.wait(for: [exp1], timeout: 600)
        
        let exp2 = self.expectation(description: "client2 open success & kick client1 success")
        exp2.expectedFulfillmentCount = 2
        exp2.assertForOverFulfill = true
        
        delegator1.didCloseSession = { (client, error) in
            
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(client === client1)
            XCTAssertEqual(error.code, 4111)
            exp2.fulfill()
        }
        
        client2.open { (result) in
            
            XCTAssertNil(result.error)
            exp2.fulfill()
        }
        
        self.wait(for: [exp2], timeout: 600)
        
        let exp3 = self.expectation(description: "client1 resume with deviceToken1 fail, and set deviceToken2 then resume success")
        exp3.expectedFulfillmentCount = 2
        exp3.assertForOverFulfill = true
        
        client1.open(action: .resume) { (result) in
            
            XCTAssertEqual(result.error?.code, 4111)
            exp3.fulfill()
            
            application1.currentInstallation.set(deviceToken: deviceToken2, apnsTeamId: "")
            client1.open(action: .resume) { (result) in
                
                XCTAssertNil(result.error)
                exp3.fulfill()
            }
        }
        
        self.wait(for: [exp3], timeout: 600)
    }
    
    func testClientReportDeviceToken() {
        
        let client = try! LCClient(id: String(#function[..<#function.index(of: "(")!]))
        
        let exp = self.expectation(description: "client report device token success")
        exp.expectedFulfillmentCount = 2
        exp.assertForOverFulfill = true
        
        client.open { (result) in
            
            XCTAssertNil(result.error)
            exp.fulfill()
            
            client.installation.set(deviceToken: UUID().uuidString, apnsTeamId: "")
        }
        
        let _ = NotificationCenter.default.addObserver(forName: LCClient.TestReportDeviceTokenNotification, object: client, queue: OperationQueue.main) { (notification) in
            
            let result = notification.userInfo?["result"] as! Connection.CommandCallback.Result
            switch result {
            case .error(let error):
                XCTFail("\(error)")
            case .inCommand(let command):
                XCTAssertEqual(command.cmd, .report)
                XCTAssertEqual(command.op, .uploaded)
            }
            exp.fulfill()
        }
        
        self.waitForExpectations(timeout: 600)
    }

}

class ClientDelegator: NSObject, LCClientDelegate {
    
    var didOpenSession: ((LCClient) -> Void)?
    func client(didOpenSession client: LCClient) {
        self.didOpenSession?(client)
    }
    
    var didBecomeResumeSession: ((LCClient) -> Void)?
    func client(didBecomeResumeSession client: LCClient) {
        self.didBecomeResumeSession?(client)
    }
    
    var didPauseSession: ((LCClient, LCError) -> Void)?
    func client(_ client: LCClient, didPauseSession error: LCError) {
        self.didPauseSession?(client, error)
    }
    
    var didCloseSession: ((LCClient, LCError) -> Void)?
    func client(_ client: LCClient, didCloseSession error: LCError) {
        self.didCloseSession?(client, error)
    }
    
}
