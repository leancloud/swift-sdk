//
//  MessagePushTestViewController.swift
//  RuntimeTests-iOS
//
//  Created by zapcannon87 on 2019/3/6.
//  Copyright © 2019 LeanCloud. All rights reserved.
//

import Foundation
import UIKit
import LeanCloud
import UserNotifications

let apnsTeamId = "7J5XFNL99Q"

class MessagePushTestViewController: UIViewController {
    
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var sendPushMessageButton: UIButton!
    
    var imClient: IMClient!
    var isClientOpened: Bool = false
    var isInstallationSaved: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.activityIndicatorView.startAnimating()
        self.sendPushMessageButton.isEnabled = false
        let group = DispatchGroup()
        group.enter()
        group.enter()
        (UIApplication.shared.delegate as? AppDelegate)?.didRegisterForRemoteNotificationsWithDeviceToken = { [weak self] (deviceToken, error) in
            if let deviceToken = deviceToken,
                let clientID = self?.imClient.ID {
                let installation = LCApplication.default.currentInstallation
                do {
                    try installation.append("channels", element: clientID, unique: true)
                    installation.set(deviceToken: deviceToken, apnsTeamId: apnsTeamId)
                    _ = installation.save({ (result) in
                        switch result {
                        case .success:
                            self?.isInstallationSaved = true
                        case .failure(error: let error):
                            self?.show(error: "\(error)")
                        }
                        group.leave()
                    })
                } catch {
                    self?.show(error: "\(error)")
                }
            } else if let error = error {
                self?.show(error: "\(error)")
            }
        }
        let alert = UIAlertController(
            title: "Input Client ID",
            message: "this action will create an IM Client and open it, then add the ID to the channels of the installation.",
            preferredStyle: .alert
        )
        alert.addTextField { (textField) in
            textField.placeholder = "Enter an ID"
        }
        alert.addAction(UIAlertAction(title: "cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] (_) in
            guard let clientID = alert.textFields?.first?.text else {
                return
            }
            do {
                self?.imClient = try IMClient(ID: clientID)
                self?.imClient.open(completion: { (result) in
                    switch result {
                    case .success:
                        self?.isClientOpened = true
                        UNUserNotificationCenter.current().requestAuthorization(
                            options: [.alert, .sound, .badge])
                        { granted, error in
                            if granted {
                                DispatchQueue.main.async {
                                    UIApplication.shared.registerForRemoteNotifications()
                                }
                            }
                        }
                    case .failure(error: let error):
                        self?.show(error: "\(error)")
                    }
                    group.leave()
                })
            } catch {
                self?.show(error: "\(error)")
            }
        }))
        self.present(alert, animated: true)
        group.notify(queue: .main) { [weak self] in
            if self?.isClientOpened == true, self?.isInstallationSaved == true {
                self?.activityIndicatorView.stopAnimating()
                self?.sendPushMessageButton.isEnabled = true
                self?.show(success: "now you can send message to test APNs")
            }
        }
    }
    
    deinit {
        print("\(type(of: self)) deinit")
    }
    
    func show(error: String) {
        let alert = UIAlertController(title: "Error", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        self.present(alert, animated: true)
    }
    
    func show(success: String) {
        let alert = UIAlertController(title: "Success", message: success, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        self.present(alert, animated: true)
    }
    
    
    @IBAction func sendPushMessageAction(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Send Push Message",
            message: "this action will create a unique conversation with other Client ID and send a message with push data",
            preferredStyle: .alert
        )
        alert.addTextField { (textField) in
            textField.placeholder = "Enter other Client ID"
        }
        alert.addTextField { (textField) in
            textField.placeholder = "Enter message text"
        }
        alert.addTextField { (textField) in
            textField.placeholder = "Enter push alert"
        }
        alert.addAction(UIAlertAction(title: "cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] (_) in
            guard
                let otherClientID = alert.textFields![0].text,
                let messageText = alert.textFields![1].text,
                let pushAlert = alert.textFields![2].text
                else
            { return }
            do {
                self?.activityIndicatorView.startAnimating()
                self?.sendPushMessageButton.isEnabled = false
                try self?.imClient.createConversation(clientIDs: [otherClientID], isUnique: true, completion: { (result) in
                    switch result {
                    case .success(value: let conversation):
                        do {
                            let message = IMTextMessage()
                            message.text = messageText
                            let pushData: [String: Any] = [
                                "alert": pushAlert,
                                "_profile": "dev",
                                "_apns_team_id": apnsTeamId
                            ]
                            try conversation.send(message: message, pushData: pushData, completion: { (result) in
                                switch result {
                                case .success:
                                    self?.show(success: "message has been sent")
                                case .failure(error: let error):
                                    self?.show(error: "\(error)")
                                }
                                self?.activityIndicatorView.stopAnimating()
                                self?.sendPushMessageButton.isEnabled = true
                            })
                        } catch {
                            self?.activityIndicatorView.stopAnimating()
                            self?.sendPushMessageButton.isEnabled = true
                            self?.show(error: "\(error)")
                        }
                    case .failure(error: let error):
                        self?.activityIndicatorView.stopAnimating()
                        self?.sendPushMessageButton.isEnabled = true
                        self?.show(error: "\(error)")
                    }
                })
            } catch {
                self?.show(error: "\(error)")
            }
        }))
        self.present(alert, animated: true)
    }
    
}
