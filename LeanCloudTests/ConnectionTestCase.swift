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
        
        var endTestPingTimeout: Bool = false
        let timer = Connection.Timer(timerQueue: timerQueue, commandCallbackQueue: commandCallbackQueue, pingTimeout: 5) { timer in
            XCTAssertEqual(DispatchQueue.getSpecific(key: self.timerQueueSpecificKey), self.timerQueueSpecificValue)
            if timer.lastPingSentTimestamp != 0 {
                let timeout: TimeInterval = Date().timeIntervalSince1970 - timer.lastPingSentTimestamp
                print(timeout)
                XCTAssertTrue(timeout < timer.pingTimeout + self.timerTimeIntervalError)
                XCTAssertTrue(timeout > timer.pingTimeout - self.timerTimeIntervalError)
                endTestPingTimeout = true
            }
        }
        self.busywait(interval: 1) { () -> Bool in
            return endTestPingTimeout
        }
        
        timer.cancel()
    }
    
    func testTimerPingpongInterval() {
        
        var endTestPingPong: Bool = false
        let timer = Connection.Timer(timerQueue: timerQueue, commandCallbackQueue: commandCallbackQueue, pingpongInterval: 5) { timer in
            XCTAssertEqual(DispatchQueue.getSpecific(key: self.timerQueueSpecificKey), self.timerQueueSpecificValue)
            self.timerQueue.async {
                timer.lastPongReceivedTimestamp = Date().timeIntervalSince1970
            }
            if timer.lastPongReceivedTimestamp != 0 {
                let pingpongInterval: TimeInterval = Date().timeIntervalSince1970 - timer.lastPongReceivedTimestamp
                print(pingpongInterval)
                XCTAssertTrue(pingpongInterval < timer.pingpongInterval + self.timerTimeIntervalError)
                XCTAssertTrue(pingpongInterval > timer.pingpongInterval - self.timerTimeIntervalError)
                endTestPingPong = true
            }
        }
        self.busywait(interval: 1) { () -> Bool in
            return endTestPingPong
        }
        
        timer.cancel()
    }
    
    func testTimerCheckCommandCallback() {
        
        var endTestCommandTimeout: Int = 0
        let timer = Connection.Timer(timerQueue: timerQueue, commandCallbackQueue: commandCallbackQueue) { _ in }
        timerQueue.async {
            let commandCallbackInsertTimestamp: TimeInterval = Date().timeIntervalSince1970
            // test callback timeout 1
            let index1: UInt16 = 1
            let commandTTL1: TimeInterval = 5
            timer.insert(commandCallback: Connection.CommandCallback(closure: { (result) in
                XCTAssertEqual(DispatchQueue.getSpecific(key: self.commandCallbackQueueSpecificKey), self.commandCallbackQueueSpecificValue)
                switch result {
                case .error(_):
                    let interval: TimeInterval = Date().timeIntervalSince1970 - commandCallbackInsertTimestamp
                    print(interval)
                    XCTAssertTrue(interval < commandTTL1 + self.timerTimeIntervalError)
                    XCTAssertTrue(interval > commandTTL1 - self.timerTimeIntervalError)
                case .inCommand(_):
                    XCTFail()
                }
                self.timerQueue.async {
                    XCTAssertEqual(timer.commandIndexSequence.contains(index1), false)
                    XCTAssertNil(timer.commandCallbackCollection[index1])
                    endTestCommandTimeout += 1
                }
            }, timeToLive: commandTTL1), index: index1)
            // test callback timeout 2
            let index2: UInt16 = 2
            let commandTTL2: TimeInterval = 10
            timer.insert(commandCallback: Connection.CommandCallback(closure: { (result) in
                XCTAssertEqual(DispatchQueue.getSpecific(key: self.commandCallbackQueueSpecificKey), self.commandCallbackQueueSpecificValue)
                switch result {
                case .error(_):
                    let interval: TimeInterval = Date().timeIntervalSince1970 - commandCallbackInsertTimestamp
                    print(interval)
                    XCTAssertTrue(interval < commandTTL2 + self.timerTimeIntervalError)
                    XCTAssertTrue(interval > commandTTL2 - self.timerTimeIntervalError)
                case .inCommand(_):
                    XCTFail()
                }
                self.timerQueue.async {
                    XCTAssertEqual(timer.commandIndexSequence.contains(index2), false)
                    XCTAssertNil(timer.commandCallbackCollection[index2])
                    endTestCommandTimeout += 1
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
                    endTestCommandTimeout += 1
                }
            }, timeToLive: 30), index: index3)
            timer.handle(callbackCommand: {
                var command = IMGenericCommand()
                command.i = Int32(index3)
                return command
            }())
        }
        self.busywait(interval: 1) { () -> Bool in
            return endTestCommandTimeout == 3
        }
        
        timer.cancel()
    }
    
    func testTimerCancel() {
        
        var endTestCancelTimer: Bool = false
        let timer = Connection.Timer(timerQueue: timerQueue, commandCallbackQueue: commandCallbackQueue) { _ in }
        timerQueue.async {
            timer.insert(commandCallback: Connection.CommandCallback(closure: { (result) in
                XCTAssertEqual(DispatchQueue.getSpecific(key: self.commandCallbackQueueSpecificKey), self.commandCallbackQueueSpecificValue)
                switch result {
                case .error(_):
                    break
                case .inCommand(_):
                    XCTFail()
                }
                endTestCancelTimer = true
            }, timeToLive: 30), index: 1)
            timer.cancel()
        }
        self.busywait(interval: 1) { () -> Bool in
            return endTestCancelTimer
        }
    }
    
    func testConnection() {
        
        let application = LCApplication.default
        let clientId1 = String(#function[..<#function.index(of: "(")!]) + "1"
        let clientId2 = String(#function[..<#function.index(of: "(")!]) + "2"
        
        var endTestConnect: Int = 0
        let delegator = ConnectionDelegator()
        let connection = Connection(application: application, delegate: delegator, lcimProtocol: .protobuf1, customRTMServer: "wss://rtm51.leancloud.cn", delegateQueue: delegateQueue)
        delegator.connectionInConnectingClosure = { (connection) in
            XCTAssertEqual(DispatchQueue.getSpecific(key: self.delegateQueueSpecificKey), self.delegateQueueSpecificValue)
            endTestConnect += 1
        }
        delegator.connectionDidConnectClosure = { (connection) in
            XCTAssertEqual(DispatchQueue.getSpecific(key: self.delegateQueueSpecificKey), self.delegateQueueSpecificValue)
            endTestConnect += 1
        }
        connection.connect()
        self.busywait() { () -> Bool in
            return endTestConnect == 2
        }
        
        var endTestSendCommand: Bool = false
        connection.send(command: {
            var sessionCommand = IMSessionCommand()
            sessionCommand.deviceToken = UUID().uuidString
            sessionCommand.ua = "swift-sdk/\(LeanCloud.version)"
            var command = IMGenericCommand()
            command.cmd = .session
            command.op = .open
            command.appID = application.id
            command.peerID = clientId1
            command.sessionMessage = sessionCommand
            print(command.debugDescription)
            return command
        }()) { (result) in
            XCTAssertEqual(DispatchQueue.getSpecific(key: self.delegateQueueSpecificKey), self.delegateQueueSpecificValue)
            switch result {
            case .inCommand(let command):
                print(command.debugDescription)
                XCTAssertTrue(command.hasSessionMessage)
                XCTAssertTrue(command.sessionMessage.hasSt)
                XCTAssertTrue(command.sessionMessage.hasStTtl)
            case .error(_):
                XCTFail()
            }
            endTestSendCommand = true
        }
        self.busywait() { () -> Bool in
            return endTestSendCommand
        }
        
        var endTestCreateConversation: Int = 0
        delegator.connectionDidReceiveCommandClosure = { (connection, command) in
            XCTAssertEqual(DispatchQueue.getSpecific(key: self.delegateQueueSpecificKey), self.delegateQueueSpecificValue)
            if command.cmd == .conv {
                if command.op == .joined || command.op == .membersJoined {
                    print(command.debugDescription)
                    endTestCreateConversation += 1
                }
            }
        }
        connection.send(command: {
            var convCommand = IMConvCommand()
            convCommand.m = [clientId1, clientId2]
            var command = IMGenericCommand()
            command.cmd = .conv
            command.op = .start
            command.convMessage = convCommand
            print(command.debugDescription)
            return command
        }()) { (result) in
            XCTAssertEqual(DispatchQueue.getSpecific(key: self.delegateQueueSpecificKey), self.delegateQueueSpecificValue)
            switch result {
            case .inCommand(let command):
                print(command.debugDescription)
                XCTAssertTrue(command.hasConvMessage)
                XCTAssertTrue(command.convMessage.hasCid)
            case .error(_):
                XCTFail()
            }
            endTestCreateConversation += 1
        }
        self.busywait() { () -> Bool in
            return endTestCreateConversation == 3
        }
        
        connection.disconnect()
    }

}

class ConnectionDelegator: ConnectionDelegate {
    
    var connectionInConnectingClosure: ((Connection) -> Void)?
    func connectionInConnecting(connection: Connection) {
        connectionInConnectingClosure?(connection)
    }
    
    var connectionDidConnectClosure: ((Connection) -> Void)?
    func connectionDidConnect(connection: Connection) {
        connectionDidConnectClosure?(connection)
    }
    
    var connectionDidFailInConnectingClosure: ((Connection, Connection.Event) -> Void)?
    func connection(connection: Connection, didFailInConnecting event: Connection.Event) {
        connectionDidFailInConnectingClosure?(connection, event)
    }
    
    var connectionDidDisconnectClosure: ((Connection, Connection.Event) -> Void)?
    func connection(connection: Connection, didDisconnect event: Connection.Event) {
        connectionDidDisconnectClosure?(connection, event)
    }
    
    var connectionDidReceiveCommandClosure: ((Connection, IMGenericCommand) -> Void)?
    func connection(connection: Connection, didReceiveCommand inCommand: IMGenericCommand) {
        connectionDidReceiveCommandClosure?(connection, inCommand)
    }
    
}
