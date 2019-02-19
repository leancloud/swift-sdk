//
//  RTMConnectionTestCase.swift
//  LeanCloudTests
//
//  Created by zapcannon87 on 2018/11/3.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

class RTMConnectionTestCase: RTMBaseTestCase {
    
    

}

extension RTMConnectionTestCase {
    
    class Delegator: RTMConnectionDelegate {
        
        var inConnecting: ((RTMConnection) -> Void)?
        func connection(inConnecting connection: RTMConnection) {
            inConnecting?(connection)
        }
        
        var didConnect: ((RTMConnection) -> Void)?
        func connection(didConnect connection: RTMConnection) {
            didConnect?(connection)
        }
        
        var didDisconnect: ((RTMConnection, LCError) -> Void)?
        func connection(_ connection: RTMConnection, didDisconnect error: LCError) {
            didDisconnect?(connection, error)
        }
        
        var didReceiveCommand: ((RTMConnection, IMGenericCommand) -> Void)?
        func connection(_ connection: RTMConnection, didReceiveCommand inCommand: IMGenericCommand) {
            didReceiveCommand?(connection, inCommand)
        }
        
    }
    
}
