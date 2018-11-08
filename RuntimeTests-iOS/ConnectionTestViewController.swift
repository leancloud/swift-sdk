//
//  ConnectionTestViewController.swift
//  RuntimeTests-iOS
//
//  Created by zapcannon87 on 2018/11/8.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation
import UIKit

class ConnectionTestViewController: UIViewController {
    
    var connection: Connection!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        connection = Connection(application: LCApplication.default, delegate: self, lcimProtocol: .protobuf1)
        connection.setAutoReconnectionEnabled(with: true)
        connection.connect()
    }
    
}

extension ConnectionTestViewController: ConnectionDelegate {
    
    func connectionInConnecting(connection: Connection) {
        
    }
    
    func connectionDidConnect(connection: Connection) {
        
    }
    
    func connection(connection: Connection, didFailInConnecting event: Connection.Event) {
        
    }
    
    func connection(connection: Connection, didDisconnect event: Connection.Event) {
        
    }
    
    func connection(connection: Connection, didReceiveCommand inCommand: IMGenericCommand) {
        
    }
    
}
