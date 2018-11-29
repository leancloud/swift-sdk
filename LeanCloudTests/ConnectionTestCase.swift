//
//  ConnectionTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2018/11/3.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class ConnectionTestCase: BaseTestCase {
    
    lazy var delegateQueueSpecificKey = DispatchSpecificKey<Int>()
    lazy var delegateQueueSpecificValue = Int.random(in: 1...999)
    lazy var delegateQueue = { () -> DispatchQueue in
        let queue = DispatchQueue(label: "delegate.queue")
        queue.setSpecific(key: delegateQueueSpecificKey, value: delegateQueueSpecificValue)
        return queue
    }()
    
    lazy var timerQueueSpecificKey = DispatchSpecificKey<Int>()
    lazy var timerQueueSpecificValue = Int.random(in: 1...999)
    lazy var timerQueue = { () -> DispatchQueue in
        let queue = DispatchQueue(label: "timer.queue")
        queue.setSpecific(key: timerQueueSpecificKey, value: timerQueueSpecificValue)
        return queue
    }()
    
    lazy var commandCallbackQueueSpecificKey = DispatchSpecificKey<Int>()
    lazy var commandCallbackQueueSpecificValue = Int.random(in: 1...999)
    lazy var commandCallbackQueue = { () -> DispatchQueue in
        let queue = DispatchQueue(label: "command.callback.queue")
        queue.setSpecific(key: commandCallbackQueueSpecificKey, value: commandCallbackQueueSpecificValue)
        return queue
    }()
    
    let timerTimeIntervalError: TimeInterval = 3
    
    func testTimerPingTimeout() {
        
        let interval: TimeInterval = 5
        let expectation = self.expectation(description: "Get ping sent callback")
        
        let timer = Connection.Timer(timerQueue: timerQueue, commandCallbackQueue: commandCallbackQueue, pingTimeout: interval) { timer in
            XCTAssertEqual(DispatchQueue.getSpecific(key: self.timerQueueSpecificKey), self.timerQueueSpecificValue)
            if timer.lastPingSentTimestamp != 0 {
                let timeout: TimeInterval = Date().timeIntervalSince1970 - timer.lastPingSentTimestamp
                XCTAssertTrue(timeout < timer.pingTimeout + self.timerTimeIntervalError)
                XCTAssertTrue(timeout > timer.pingTimeout - self.timerTimeIntervalError)
                expectation.fulfill()
            }
        }
        
        self.waitForExpectations(timeout: interval * 2, handler: nil)
        
        timer.cancel()
    }
    
    func testTimerPingpongInterval() {
        
        let interval: TimeInterval = 5
        let expectation = self.expectation(description: "Get ping sent callback")
        
        let timer = Connection.Timer(timerQueue: timerQueue, commandCallbackQueue: commandCallbackQueue, pingpongInterval: interval) { timer in
            XCTAssertEqual(DispatchQueue.getSpecific(key: self.timerQueueSpecificKey), self.timerQueueSpecificValue)
            self.timerQueue.async {
                timer.lastPongReceivedTimestamp = Date().timeIntervalSince1970
            }
            if timer.lastPongReceivedTimestamp != 0 {
                let pingpongInterval: TimeInterval = Date().timeIntervalSince1970 - timer.lastPongReceivedTimestamp
                XCTAssertTrue(pingpongInterval < timer.pingpongInterval + self.timerTimeIntervalError)
                XCTAssertTrue(pingpongInterval > timer.pingpongInterval - self.timerTimeIntervalError)
                expectation.fulfill()
            }
        }

        self.waitForExpectations(timeout: interval * 2, handler: nil)
        
        timer.cancel()
    }
    
    func testTimerCheckCommandCallback() {
        
        let interval: TimeInterval = 5
        let expectation = self.expectation(description: "Get command callback")
        expectation.expectedFulfillmentCount = 3
        
        let timer = Connection.Timer(timerQueue: timerQueue, commandCallbackQueue: commandCallbackQueue) { _ in }
        timerQueue.async {
            let commandCallbackInsertTimestamp: TimeInterval = Date().timeIntervalSince1970
            // test callback timeout 1
            let index1: UInt16 = 1
            let commandTTL1: TimeInterval = interval
            timer.insert(commandCallback: Connection.CommandCallback(closure: { (result) in
                XCTAssertEqual(DispatchQueue.getSpecific(key: self.commandCallbackQueueSpecificKey), self.commandCallbackQueueSpecificValue)
                switch result {
                case .error(let error):
                    let interval: TimeInterval = Date().timeIntervalSince1970 - commandCallbackInsertTimestamp
                    XCTAssertTrue(interval < commandTTL1 + self.timerTimeIntervalError)
                    XCTAssertTrue(interval > commandTTL1 - self.timerTimeIntervalError)
                    XCTAssertEqual(error.code, LCError.InternalErrorCode.commandTimeout.rawValue)
                case .inCommand(_):
                    XCTFail()
                }
                self.timerQueue.async {
                    XCTAssertEqual(timer.commandIndexSequence.contains(index1), false)
                    XCTAssertNil(timer.commandCallbackCollection[index1])
                    expectation.fulfill()
                }
            }, timeToLive: commandTTL1), index: index1)
            // test callback timeout 2
            let index2: UInt16 = 2
            let commandTTL2: TimeInterval = interval * 2
            timer.insert(commandCallback: Connection.CommandCallback(closure: { (result) in
                XCTAssertEqual(DispatchQueue.getSpecific(key: self.commandCallbackQueueSpecificKey), self.commandCallbackQueueSpecificValue)
                switch result {
                case .error(let error):
                    let interval: TimeInterval = Date().timeIntervalSince1970 - commandCallbackInsertTimestamp
                    XCTAssertTrue(interval < commandTTL2 + self.timerTimeIntervalError)
                    XCTAssertTrue(interval > commandTTL2 - self.timerTimeIntervalError)
                    XCTAssertEqual(error.code, LCError.InternalErrorCode.commandTimeout.rawValue)
                case .inCommand(_):
                    XCTFail()
                }
                self.timerQueue.async {
                    XCTAssertEqual(timer.commandIndexSequence.contains(index2), false)
                    XCTAssertNil(timer.commandCallbackCollection[index2])
                    expectation.fulfill()
                }
            }, timeToLive: commandTTL2), index: index2)
            // test callback succeeded
            let index3: UInt16 = 3
            timer.insert(commandCallback: Connection.CommandCallback(closure: { (result) in
                XCTAssertEqual(DispatchQueue.getSpecific(key: self.commandCallbackQueueSpecificKey), self.commandCallbackQueueSpecificValue)
                switch result {
                case .error(_):
                    XCTFail()
                case .inCommand(let command):
                    XCTAssertTrue(command.i == index3)
                }
                self.timerQueue.async {
                    XCTAssertEqual(timer.commandIndexSequence.contains(index3), false)
                    XCTAssertNil(timer.commandCallbackCollection[index3])
                    expectation.fulfill()
                }
            }, timeToLive: interval * 6), index: index3)
            timer.handle(callbackCommand: {
                var command = IMGenericCommand()
                command.i = Int32(index3)
                return command
            }())
        }
        
        self.waitForExpectations(timeout: interval * 6, handler: nil)
        
        timer.cancel()
    }
    
    func testTimerCancel() {
        
        let timeout: TimeInterval = 30
        let expectation = self.expectation(description: "Get command callback")
        
        let timer = Connection.Timer(timerQueue: timerQueue, commandCallbackQueue: commandCallbackQueue) { _ in }
        timerQueue.async {
            timer.insert(commandCallback: Connection.CommandCallback(closure: { (result) in
                XCTAssertEqual(DispatchQueue.getSpecific(key: self.commandCallbackQueueSpecificKey), self.commandCallbackQueueSpecificValue)
                switch result {
                case .error(let error):
                    XCTAssertEqual(error.code, LCError.InternalErrorCode.connectionLost.rawValue)
                case .inCommand(_):
                    XCTFail()
                }
                expectation.fulfill()
            }, timeToLive: timeout), index: 1)
            timer.cancel()
        }

        self.waitForExpectations(timeout: timeout, handler: nil)
    }
    
    func testConnectionDeinit() {
        
        var connection: Connection? = Connection(application: LCApplication.default, lcimProtocol: .protobuf1)
        
        connection = nil
        
        XCTAssertNil(connection)
    }

}

class ConnectionDelegator: ConnectionDelegate {
    
    var inConnecting: ((Connection) -> Void)?
    func connection(inConnecting connection: Connection) {
        inConnecting?(connection)
    }
    
    var didConnect: ((Connection) -> Void)?
    func connection(didConnect connection: Connection) {
        didConnect?(connection)
    }
    
    var didDisconnect: ((Connection, LCError) -> Void)?
    func connection(_ connection: Connection, didDisconnect error: LCError) {
        didDisconnect?(connection, error)
    }
    
    var didReceiveCommand: ((Connection, IMGenericCommand) -> Void)?
    func connection(_ connection: Connection, didReceiveCommand inCommand: IMGenericCommand) {
        didReceiveCommand?(connection, inCommand)
    }
    
}
