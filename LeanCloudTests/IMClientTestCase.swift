//
//  IMClientTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2018/11/28.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class IMClientTestCase: RTMBaseTestCase {
    
    func testDeinit() {
        do {
            let invalidID: String = Array<String>.init(repeating: "a", count: 65).joined()
            let _ = try IMClient(ID: invalidID)
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        
        do {
            let invalidTag: String = "default"
            let _ = try IMClient(ID: "aaaaaa", tag: invalidTag)
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        
        do {
            var client: IMClient? = try IMClient(ID: "qweasd", tag: "mobile")
            XCTAssertNotNil(client?.deviceTokenObservation)
            XCTAssertNotNil(client?.fallbackUDID)
            client = nil
            XCTAssertNil(client)
        } catch {
            XCTFail()
        }
    }

    func testOpenAndClose() {
        let client: IMClient = try! IMClient(ID: uuid)
        
        for _ in 0..<3 {
            let exp = expectation(description: "open and close")
            exp.expectedFulfillmentCount = 3
            client.open { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertNotNil(client.sessionToken)
                XCTAssertNotNil(client.sessionTokenExpiration)
                XCTAssertNil(client.openingOptions)
                XCTAssertNil(client.openingCompletion)
                XCTAssertEqual(client.sessionState, .opened)
                exp.fulfill()
                client.open { (result) in
                    XCTAssertNotNil(result.error)
                    exp.fulfill()
                    client.close() { (result) in
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertTrue(result.isSuccess)
                        XCTAssertNil(result.error)
                        XCTAssertNil(client.sessionToken)
                        XCTAssertNil(client.sessionTokenExpiration)
                        XCTAssertNil(client.openingOptions)
                        XCTAssertNil(client.openingCompletion)
                        XCTAssertEqual(client.sessionState, .closed)
                        exp.fulfill()
                    }
                }
            }
            waitForExpectations(timeout: timeout, handler: nil)
        }
    }
    
    func testDelegateEvent() {
        let client: IMClient = try! IMClient(ID: uuid)
        let delegator: Delegator = Delegator()
        client.delegate = delegator
        
        let openExp = expectation(description: "open")
        client.open { (r) in
            XCTAssertTrue(r.isSuccess)
            openExp.fulfill()
        }
        wait(for: [openExp], timeout: timeout)
        
        let pauseExp = expectation(description: "pause")
        delegator.clientEvent = { c, e in
            XCTAssertTrue(Thread.isMainThread)
            if c === client,
                case .sessionDidPause(error: _) = e {
                XCTAssertEqual(client.sessionState, .paused)
                pauseExp.fulfill()
            }
        }
        client.connection.disconnect()
        wait(for: [pauseExp], timeout: timeout)
        
        let reopenExp = expectation(description: "resuming and reopen")
        reopenExp.expectedFulfillmentCount = 2
        reopenExp.assertForOverFulfill = true
        delegator.clientEvent = { c, e in
            XCTAssertTrue(Thread.isMainThread)
            if c === client {
                switch e {
                case .sessionDidResume:
                    XCTAssertEqual(client.sessionState, .resuming)
                    reopenExp.fulfill()
                case .sessionDidOpen:
                    XCTAssertEqual(client.sessionState, .opened)
                    reopenExp.fulfill()
                default:
                    XCTFail()
                }
            }
        }
        client.connection.connect()
        wait(for: [reopenExp], timeout: timeout)
    }
    
    func testSessionConflict() {
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
        XCTAssertTrue(application1.currentInstallation.save().isSuccess)
        let delegator1: Delegator = Delegator()
        let client1: IMClient = try! IMClient(
            ID: clientID,
            tag: tag,
            delegate: delegator1,
            application: application1
        )
        
        let exp1 = expectation(description: "client1 open success")
        client1.open { (result) in
            XCTAssertTrue(result.isSuccess)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: timeout)
        
        RTMConnectionRefMap_protobuf1.removeAll()
        RTMConnectionRefMap_protobuf3.removeAll()
        delay()
        
        let application2: LCApplication = LCApplication(
            id: LCApplication.default.id,
            key: LCApplication.default.key
        )
        application2.currentInstallation.set(
            deviceToken: uuid,
            apnsTeamId: ""
        )
        XCTAssertTrue(application2.currentInstallation.save().isSuccess)
        let delegator2: Delegator = Delegator()
        let client2: IMClient = try! IMClient(
            ID: clientID,
            tag: tag,
            delegate: delegator2,
            application: application2
        )
        
        let exp2 = expectation(description: "client2 open success & kick client1 success")
        exp2.expectedFulfillmentCount = 2
        delegator1.clientEvent = { client, event in
            if client === client1 {
                switch event {
                case let .sessionDidClose(error: error):
                    XCTAssertEqual(error.code, LCError.ServerErrorCode.sessionConflict.rawValue)
                    exp2.fulfill()
                default:
                    break
                }
            }
        }
        client2.open { (result) in
            XCTAssertTrue(result.isSuccess)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: timeout)
        
        let exp3 = expectation(description: "client1 resume with deviceToken1 fail, and set deviceToken2 then resume success")
        exp3.expectedFulfillmentCount = 2
        client1.open(options: []) { (result) in
            XCTAssertEqual(result.error?.code, LCError.ServerErrorCode.sessionConflict.rawValue)
            client1.serialQueue.async {
                application1.currentInstallation.set(
                    deviceToken: application2.currentInstallation.deviceToken!.value,
                    apnsTeamId: ""
                )
                application1.currentInstallation.save({ (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    client1.serialQueue.async {
                        client1.open(options: []) { (result) in
                            XCTAssertNil(result.error)
                            exp3.fulfill()
                        }
                    }
                })
            }
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: timeout)
    }
    
    func testSessionTokenExpired() {
        let client: IMClient = try! IMClient(ID: uuid)
        let delegator: Delegator = Delegator()
        client.delegate = delegator
        
        let openExp = expectation(description: "open")
        client.open { (result) in
            XCTAssertTrue(result.isSuccess)
            openExp.fulfill()
        }
        wait(for: [openExp], timeout: timeout)
        
        client.change(sessionToken: uuid, sessionTokenExpiration: Date(timeIntervalSinceNow: 36000))
        
        let exp = expectation(description: "Pause, Resume, First Reopen Then Session Token Expired and Second Reopen Success")
        exp.expectedFulfillmentCount = 4
        exp.assertForOverFulfill = true
        delegator.clientEvent = { c, event in
            if c === client {
                switch event {
                case .sessionDidPause(error: _):
                    exp.fulfill()
                case .sessionDidResume:
                    exp.fulfill()
                case .sessionDidOpen:
                    exp.fulfill()
                default:
                    XCTFail()
                }
            }
        }
        let _ = NotificationCenter.default.addObserver(
            forName: IMClient.TestSessionTokenExpiredNotification,
            object: client,
            queue: OperationQueue.main
        ) { (notification) in
            let error = notification.userInfo?["error"] as? LCError
            XCTAssertEqual(
                error?.code,
                LCError.ServerErrorCode.sessionTokenExpired.rawValue
            )
            exp.fulfill()
        }
        client.connection.disconnect()
        client.connection.connect()
        wait(for: [exp], timeout: timeout)
    }
    
    func testReportDeviceToken() {
        let application = LCApplication.default
        let currentDeviceToken = application.currentInstallation.deviceToken?.value
        let client: IMClient = try! IMClient(ID: uuid, application: application)
        XCTAssertEqual(currentDeviceToken, client.currentDeviceToken)
        
        let exp = expectation(description: "client report device token success")
        exp.expectedFulfillmentCount = 2
        let otherDeviceToken: String = uuid
        let _ = NotificationCenter.default.addObserver(forName: IMClient.TestReportDeviceTokenNotification, object: client, queue: OperationQueue.main) { (notification) in
            let result = notification.userInfo?["result"] as? RTMConnection.CommandCallback.Result
            XCTAssertEqual(result?.command?.cmd, .report)
            XCTAssertEqual(result?.command?.op, .uploaded)
            exp.fulfill()
        }
        client.open { (result) in
            XCTAssertTrue(result.isSuccess)
            client.installation.set(deviceToken: otherDeviceToken, apnsTeamId: "")
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
        XCTAssertEqual(otherDeviceToken, client.currentDeviceToken)
    }
    
    func testSessionQuery() {
        let client1: IMClient = try! IMClient(ID: uuid)
        let client2: IMClient = try! IMClient(ID: uuid)
        
        let openExp1 = expectation(description: "open")
        client1.open { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            openExp1.fulfill()
        }
        wait(for: [openExp1], timeout: timeout)
        
        do {
            try client1.queryOnlineClients(clientIDs: []) { (_) in }
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        do {
            var set: Set<String> = []
            for _ in 0...20 {
                set.insert(uuid)
            }
            try client1.queryOnlineClients(clientIDs: set) { (_) in }
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        
        let queryExp1 = expectation(description: "query")
        try! client1.queryOnlineClients(clientIDs: [client2.ID], completion: { (result) in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.count, 0)
            queryExp1.fulfill()
        })
        wait(for: [queryExp1], timeout: timeout)
        
        let openExp2 = expectation(description: "open")
        client2.open { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            openExp2.fulfill()
        }
        wait(for: [openExp2], timeout: timeout)
        
        let queryExp2 = expectation(description: "query")
        try! client1.queryOnlineClients(clientIDs: [client2.ID], completion: { (result) in
            XCTAssertTrue(result.isSuccess)
            XCTAssertNil(result.error)
            XCTAssertEqual(result.value?.count, 1)
            XCTAssertEqual(result.value?.first, client2.ID)
            queryExp2.fulfill()
        })
        wait(for: [queryExp2], timeout: timeout)
    }

}

extension IMClientTestCase {
    
    class Delegator: IMClientDelegate {
        var clientEvent: ((_ client: IMClient, _ event: IMClientEvent) -> Void)? = nil
        func client(_ client: IMClient, event: IMClientEvent) {
            clientEvent?(client, event)
        }
        var conversationEvent: ((_ client: IMClient, _ conversation: IMConversation, _ event: IMConversationEvent) -> Void)? = nil
        var messageEvent: ((_ client: IMClient, _ conversation: IMConversation, _ event: IMMessageEvent) -> Void)? = nil
        func client(_ client: IMClient, conversation: IMConversation, event: IMConversationEvent) {
            if case let .message(event: mEvent) = event,
                let messageEventClosure = messageEvent {
                messageEventClosure(client, conversation, mEvent)
            } else {
                conversationEvent?(client, conversation, event)
            }
        }
    }
    
}
