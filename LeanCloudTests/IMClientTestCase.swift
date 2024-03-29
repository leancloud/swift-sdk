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
    
    func testInit() {
        do {
            let invalidID: String = Array<String>.init(repeating: "a", count: 65).joined()
            let _ = try IMClient(ID: invalidID, options: [])
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        
        do {
            let invalidTag: String = "default"
            let _ = try IMClient(ID: uuid, tag: invalidTag, options: [])
            XCTFail()
        } catch {
            XCTAssertTrue(error is LCError)
        }
        
        do {
            let _ = try IMClient(ID: uuid, options: [])
            let _ = try IMClient(ID: uuid, tag: uuid, options: [])
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testInitWithUser() {
        let user = LCUser()
        user.username = UUID().uuidString.lcString
        user.password = UUID().uuidString.lcString
        
        XCTAssertTrue(user.signUp().isSuccess)
        
        do {
            let client = try IMClient(user: user, options: [])
            XCTAssertNotNil(client.user)
            XCTAssertEqual(client.ID, user.objectId?.stringValue)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testDeinit() {
        var client: IMClient? = try! IMClient(ID: uuid, tag: uuid, options: [])
        weak var wClient: IMClient? = client
        client = nil
        delay()
        XCTAssertNil(wClient)
    }
    
    func testOpenAndClose() {
        let client: IMClient = try! IMClient(ID: uuid, options: [])
        
        expecting { (exp) in
            client.open(completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertNotNil(client.sessionToken)
                XCTAssertNotNil(client.sessionTokenExpiration)
                XCTAssertNil(client.openingOptions)
                XCTAssertNil(client.openingCompletion)
                XCTAssertEqual(client.sessionState, .opened)
                XCTAssertNotNil(client.connectionDelegator.delegate)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.open { (result) in
                XCTAssertTrue(result.isFailure)
                XCTAssertNotNil(result.error)
                exp.fulfill()
            }
        }
        
        expecting { (exp) in
            client.close() { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertNil(client.sessionToken)
                XCTAssertNil(client.sessionTokenExpiration)
                XCTAssertNil(client.openingOptions)
                XCTAssertNil(client.openingCompletion)
                XCTAssertEqual(client.sessionState, .closed)
                XCTAssertNil(client.connectionDelegator.delegate)
                exp.fulfill()
            }
        }
    }
    
    func testOpenWithSignature() {
        let user = LCUser()
        user.username = self.uuid.lcString
        user.password = self.uuid.lcString
        XCTAssertTrue(user.signUp().isSuccess)
        
        guard let objectID = user.objectId?.value,
              let sessionToken = user.sessionToken?.value else {
                  XCTFail()
                  return
              }
        
        var clientFromUser: IMClient! = try! IMClient(
            user: user,
            options: [])
        expecting { (exp) in
            clientFromUser.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        clientFromUser = nil
        delay()
        
        let signatureDelegator = SignatureDelegator()
        signatureDelegator.sessionToken = sessionToken
        let clientFromID = try! IMClient(
            ID: objectID,
            options: [],
            signatureDelegate: signatureDelegator)
        expecting { (exp) in
            clientFromID.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
    }
    
    func testDelegateEvent() {
        let client: IMClient = try! IMClient(ID: uuid, options: [])
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
        if let fileURL = LCApplication.default.currentInstallationFileURL,
           FileManager.default.fileExists(atPath: fileURL.path) {
            try! FileManager.default.removeItem(at: fileURL)
        }
        
        let clientID: String = uuid
        let tag: String = "tag"
        
        let installation1 = LCApplication.default.currentInstallation
        installation1.set(
            deviceToken: uuid,
            apnsTeamId: "LeanCloud")
        
        let delegator1: Delegator = Delegator()
        let client1: IMClient = try! IMClient(
            ID: clientID,
            tag: tag,
            options: [],
            delegate: delegator1)
        
        expecting { (exp) in
            client1.open { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            }
        }
        
        RTMConnectionManager.default
            .imProtobuf1Registry.removeAll()
        RTMConnectionManager.default
            .imProtobuf3Registry.removeAll()
        LCApplication.default._currentInstallation = nil
        
        let installation2 = LCApplication.default.currentInstallation
        installation2.set(
            deviceToken: uuid,
            apnsTeamId: "LeanCloud")
        
        let delegator2: Delegator = Delegator()
        let client2: IMClient = try! IMClient(
            ID: clientID,
            tag: tag,
            options: [],
            delegate: delegator2)
        
        expecting(
            description: "client2 open success & kick client1 success",
            count: 2)
        { (exp) in
            delegator1.clientEvent = { client, event in
                switch event {
                case let .sessionDidClose(error: error):
                    XCTAssertEqual(
                        error.code,
                        LCError.ServerErrorCode.sessionConflict.rawValue)
                    exp.fulfill()
                default:
                    break
                }
            }
            client2.open { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            }
        }
        
        expecting(
            description: "client1 resume with deviceToken1 fail, and set deviceToken2 then resume success",
            count: 3)
        { (exp) in
            client1.open(options: []) { (result) in
                XCTAssertEqual(
                    result.error?.code,
                    LCError.ServerErrorCode.sessionConflict.rawValue)
                exp.fulfill()
                client1.open(options: [.reconnect]) { (result) in
                    XCTAssertEqual(
                        result.error?.code,
                        LCError.ServerErrorCode.sessionConflict.rawValue)
                    exp.fulfill()
                    installation1.set(
                        deviceToken: installation2.deviceToken!.value,
                        apnsTeamId: "LeanCloud"
                    )
                    self.delay()
                    client1.open(options: []) { (result) in
                        XCTAssertTrue(result.isSuccess)
                        XCTAssertNil(result.error)
                        exp.fulfill()
                    }
                }
            }
        }
        
        if let fileURL = LCApplication.default.currentInstallationFileURL,
           FileManager.default.fileExists(atPath: fileURL.path) {
            try! FileManager.default.removeItem(at: fileURL)
        }
    }
    
    func testDeviceTokenObserving() {
        let deviceToken = uuid
        
        LCApplication.default.currentInstallation.set(
            deviceToken: deviceToken,
            apnsTeamId: "LeanCloud")
        XCTAssertTrue(LCApplication.default.currentInstallation.save().isSuccess)
        XCTAssertEqual(LCApplication.default.currentInstallation.deviceToken?.value, deviceToken)
        
        let clientID = uuid
        let tag = "tag"
        
        for i in 0...1 {
            if i == 1 {
                LCApplication.default._currentInstallation = nil
            }
            expecting { (exp) in
                let client = try! IMClient(ID: clientID, tag: tag, options: [])
                client.open { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    XCTAssertEqual(client.currentDeviceToken, deviceToken)
                    exp.fulfill()
                }
            }
        }
    }
    
    func testSessionTokenExpired() {
        let delegator = Delegator()
        let client = try! IMClient(
            ID: self.uuid,
            options: [],
            delegate: delegator)
        
        expecting { (exp) in
            client.open { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            }
        }
        
        client.sessionToken = self.uuid
        client.sessionTokenExpiration = Date(timeIntervalSinceNow: 36000)
        
        var ob: NSObjectProtocol?
        expecting(
            description: "Pause -> Resume -> First-Reopen Then session token expired, Final Second-Reopen success",
            count: 4)
        { (exp) in
            delegator.clientEvent = { c, event in
                XCTAssertTrue(c === client)
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
            ob = NotificationCenter.default.addObserver(
                forName: IMClient.TestSessionTokenExpiredNotification,
                object: client,
                queue: .main
            ) { (notification) in
                XCTAssertEqual(
                    (notification.userInfo?["error"] as? LCError)?.code,
                    LCError.ServerErrorCode.sessionTokenExpired.rawValue)
                exp.fulfill()
            }
            client.connection.disconnect()
            client.connection.connect()
        }
        if let ob = ob {
            NotificationCenter.default.removeObserver(ob)
        }
    }
    
    func testReportDeviceToken() {
        let application = LCApplication.default
        let currentDeviceToken = application.currentInstallation.deviceToken?.value
        let client: IMClient = try! IMClient(application: application, ID: uuid, options: [])
        delay()
        XCTAssertEqual(currentDeviceToken, client.currentDeviceToken)
        
        let exp = expectation(description: "client report device token success")
        exp.expectedFulfillmentCount = 2
        let otherDeviceToken: String = uuid
        let ob = NotificationCenter.default.addObserver(forName: IMClient.TestReportDeviceTokenNotification, object: client, queue: OperationQueue.main) { (notification) in
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
        NotificationCenter.default.removeObserver(ob)
    }
    
    func testSessionQuery() {
        let client1: IMClient = try! IMClient(ID: uuid, options: [])
        let client2: IMClient = try! IMClient(ID: uuid, options: [])
        
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
    
#if canImport(GRDB)
    func testPrepareLocalStorage() {
        expecting { (exp) in
            let notUseLocalStorageClient = try! IMClient(ID: uuid, options: [])
            do {
                try notUseLocalStorageClient.prepareLocalStorage(completion: { (_) in })
                XCTFail()
            } catch {
                XCTAssertTrue(error is LCError)
            }
            exp.fulfill()
        }
        
        let client = try! IMClient(ID: uuid)
        
        expecting { (exp) in
            try! client.prepareLocalStorage(completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
    }
    
    func testGetAndLoadStoredConversations() {
        expecting { (exp) in
            let notUseLocalStorageClient = try! IMClient(ID: uuid, options: [])
            do {
                try notUseLocalStorageClient.getAndLoadStoredConversations(completion: { (_) in })
                XCTFail()
            } catch {
                XCTAssertTrue(error is LCError)
            }
            exp.fulfill()
        }
        
        let client = try! IMClient(ID: uuid)
        
        expecting { (exp) in
            try! client.prepareLocalStorage(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            try! client.getAndLoadStoredConversations(completion: { (result) in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                XCTAssertEqual(result.value?.count, 0)
                XCTAssertTrue(client.convCollection.isEmpty)
                exp.fulfill()
            })
        }
        
        expecting { (exp) in
            client.open(completion: { (result) in
                XCTAssertTrue(result.isSuccess)
                XCTAssertNil(result.error)
                exp.fulfill()
            })
        }
        
        for _ in 0...1 {
            var conv: IMConversation!
            
            expecting { (exp) in
                try! client.createConversation(clientIDs: [uuid], completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    conv = result.value
                    exp.fulfill()
                })
            }
            
            delay(seconds: 0.1)
            
            expecting { (exp) in
                try! conv.refresh(completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    exp.fulfill()
                })
            }
            
            delay(seconds: 0.1)
            
            expecting { (exp) in
                let message = IMMessage()
                try! message.set(content: .string("test"))
                try! conv.send(message: message, completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    exp.fulfill()
                })
            }
        }
        
        let checker: (IMClient.StoredConversationOrder) -> Void = { order in
            self.expecting { (exp) in
                try! client.getAndLoadStoredConversations(order: order, completion: { (result) in
                    XCTAssertTrue(result.isSuccess)
                    XCTAssertNil(result.error)
                    XCTAssertEqual(result.value?.count, 2)
                    switch order {
                    case let .lastMessageSentTimestamp(descending: descending):
                        let firstTimestamp = result.value?.first?.lastMessage?.sentTimestamp
                        let lastTimestamp = result.value?.last?.lastMessage?.sentTimestamp
                        if descending {
                            XCTAssertGreaterThanOrEqual(firstTimestamp!, lastTimestamp!)
                        } else {
                            XCTAssertGreaterThanOrEqual(lastTimestamp!, firstTimestamp!)
                        }
                    case let .createdTimestamp(descending: descending):
                        let firstTimestamp = result.value?.first?.createdAt?.timeIntervalSince1970
                        let lastTimestamp = result.value?.last?.createdAt?.timeIntervalSince1970
                        if descending {
                            XCTAssertGreaterThanOrEqual(firstTimestamp!, lastTimestamp!)
                        } else {
                            XCTAssertGreaterThanOrEqual(lastTimestamp!, firstTimestamp!)
                        }
                    case let .updatedTimestamp(descending: descending):
                        let firstTimestamp = result.value?.first?.updatedAt?.timeIntervalSince1970
                        let lastTimestamp = result.value?.last?.updatedAt?.timeIntervalSince1970
                        if descending {
                            XCTAssertGreaterThanOrEqual(firstTimestamp!, lastTimestamp!)
                        } else {
                            XCTAssertGreaterThanOrEqual(lastTimestamp!, firstTimestamp!)
                        }
                    }
                    exp.fulfill()
                })
            }
        }
        
        checker(.lastMessageSentTimestamp(descending: true))
        checker(.lastMessageSentTimestamp(descending: false))
        checker(.updatedTimestamp(descending: true))
        checker(.updatedTimestamp(descending: false))
        checker(.createdTimestamp(descending: true))
        checker(.createdTimestamp(descending: false))
        
        XCTAssertEqual(client.convCollection.count, 2)
    }
#endif
}

extension IMClientTestCase {
    
    class Delegator: IMClientDelegate {
        
        var clientEvent: ((_ client: IMClient, _ event: IMClientEvent) -> Void)? = nil
        
        func client(_ client: IMClient, event: IMClientEvent) {
            self.clientEvent?(client, event)
        }
        
        var conversationEvent: ((_ client: IMClient, _ conversation: IMConversation, _ event: IMConversationEvent) -> Void)? = nil
        
        var messageEvent: ((_ client: IMClient, _ conversation: IMConversation, _ event: IMMessageEvent) -> Void)? = nil
        
        func client(_ client: IMClient, conversation: IMConversation, event: IMConversationEvent) {
            if
                case let .message(event: mEvent) = event,
                let messageEventClosure = self.messageEvent
            {
                messageEventClosure(client, conversation, mEvent)
            } else {
                self.conversationEvent?(client, conversation, event)
            }
        }
        
        func reset() {
            self.clientEvent = nil
            self.conversationEvent = nil
            self.messageEvent = nil
        }
    }
    
    class SignatureDelegator: IMSignatureDelegate {
        
        var sessionToken: String?
        
        func getOpenSignature(client: IMClient, completion: @escaping (IMSignature) -> Void) {
            guard let sessionToken = self.sessionToken else {
                XCTFail()
                return
            }
            _ = client.application.httpClient.request(
                url: client.application.v2router.route(
                    path: "rtm/clients/sign",
                    module: .api)!,
                method: .get,
                parameters: ["session_token": sessionToken])
            { (response) in
                guard let value = response.value as? [String: Any],
                      let client_id = value["client_id"] as? String,
                      client_id == client.ID,
                      let signature = value["signature"] as? String,
                      let timestamp = value["timestamp"] as? Int64,
                      let nonce = value["nonce"] as? String else {
                          XCTFail()
                          return
                      }
                completion(IMSignature(
                    signature: signature,
                    timestamp: timestamp,
                    nonce: nonce))
            }
        }
        
        func client(_ client: IMClient, action: IMSignature.Action, signatureHandler: @escaping (IMClient, IMSignature?) -> Void) {
            XCTAssertTrue(Thread.isMainThread)
            switch action {
            case .open:
                self.getOpenSignature(client: client) { (signature) in
                    signatureHandler(client, signature)
                }
            default:
                XCTFail()
            }
        }
    }
}
