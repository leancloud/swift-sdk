//
//  ViewController.swift
//  RuntimeTests-iOS
//
//  Created by zapcannon87 on 2018/11/8.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import UIKit

class ViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Connection Test"
        default:
            fatalError()
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            let vc = self.storyboard!.instantiateViewController(withIdentifier: "ConnectionTestViewController")
            self.navigationController?.pushViewController(vc, animated: true)
        default:
            fatalError()
        }
    }

}
