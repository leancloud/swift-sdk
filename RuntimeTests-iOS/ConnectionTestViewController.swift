//
//  ConnectionTestViewController.swift
//  RuntimeTests-iOS
//
//  Created by zapcannon87 on 2018/11/8.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation
import UIKit
import LeanCloud

class ConnectionTestViewController: UIViewController {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var label: UILabel!
    var client: IMClient!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.client = try! IMClient(ID: "ConnectionTestViewController", delegate: self)
        self.client.open { (result) in
            self.label.isHidden.toggle()
            self.activityIndicator.stopAnimating()
            switch result {
            case .success:
                self.showConnected()
            case .failure(error: let error):
                self.showError(error)
            }
        }
    }
    
    deinit {
        print("\(type(of: self)) deinit")
    }
    
    func showError(_ error: Error) {
        self.label.text = "\(error)"
        self.label.textColor = .red
    }
    
    func showConnecting() {
        self.label.text = "Connecting ..."
        self.label.textColor = .blue
    }
    
    func showConnected() {
        self.label.text = "Connected!"
        self.label.textColor = .green
    }
    
}

extension ConnectionTestViewController: IMClientDelegate {
    
    func client(_ client: IMClient, event: IMClientEvent) {
        switch event {
        case .sessionDidOpen:
            self.showConnected()
        case .sessionDidResume:
            self.showConnecting()
        case .sessionDidPause(error: let error):
            self.showError(error)
        case .sessionDidClose(error: let error):
            self.showError(error)
        }
    }
    
    func client(_ client: IMClient, conversation: IMConversation, event: IMConversationEvent) {
        
    }
    
}
