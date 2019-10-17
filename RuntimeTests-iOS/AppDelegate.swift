//
//  AppDelegate.swift
//  RuntimeTests-iOS
//
//  Created by zapcannon87 on 2018/11/8.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import UIKit
@testable import LeanCloud

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        do {
            LCApplication.logLevel = .all
            try LCApplication.default.set(
                id: "S5vDI3IeCk1NLLiM1aFg3262-gzGzoHsz",
                key: "7g5pPsI55piz2PRLPWK5MPz0",
                serverURL: "https://s5vdi3ie.lc-cn-n1-shared.com")
        } catch {
            fatalError("\(error)")
        }
        
        return true
    }

}

