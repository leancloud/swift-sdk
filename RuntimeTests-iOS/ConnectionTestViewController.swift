//
//  ConnectionTestViewController.swift
//  RuntimeTests-iOS
//
//  Created by zapcannon87 on 2018/11/8.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation
import UIKit
@testable import LeanCloud

class ConnectionTestViewController: UIViewController {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var label: UILabel!
    var client: IMClient!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.client = try! IMClient(id: "ConnectionTestViewController", delegate: self)
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

extension ConnectionTestViewController: LCClientDelegate {
    
    func client(didOpenSession client: IMClient) {
        self.showConnected()
    }
    
    func client(didBecomeResumeSession client: IMClient) {
        self.showConnecting()
    }
    
    func client(_ client: IMClient, didCloseSession error: LCError) {
        self.showError(error)
    }
    
    func client(_ client: IMClient, didPauseSession error: LCError) {
        self.showError(error)
    }
    
}
