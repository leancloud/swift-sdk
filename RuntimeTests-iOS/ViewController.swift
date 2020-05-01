//
//  ViewController.swift
//  RuntimeTests-iOS
//
//  Created by zapcannon87 on 2018/11/8.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import UIKit
import LeanCloud

class LiveQueryTest: LCObject {
    @objc dynamic var numberField: LCNumber?
    @objc dynamic var stringField: LCString?
}

class ViewController: UITableViewController {
    
    var liveQueryArray: [LiveQuery] = []
    let username = UUID().uuidString
    let password = UUID().uuidString

    override func viewDidLoad() {
        super.viewDidLoad()
        
        LiveQueryTest.register()
        
        let user = LCUser()
        user.username = self.username.lcString
        user.password = self.password.lcString
        if let error = user.signUp().error {
            print(error)
        }
        
        for i in 0...1 {
            do {
                let query = LCQuery(className: "\(LiveQueryTest.self)")
                query.whereKey("numberField", .equalTo(i))
                let liveQuery = try LiveQuery(query: query, eventHandler: { (liveQuery, event) in
                    switch event {
                    case .create(object: let object):
                        assert(object is LiveQueryTest)
                    case .delete(object: let object):
                        assert(object is LiveQueryTest)
                    case let .enter(object: object, updatedKeys: updatedKeys):
                        assert(object is LiveQueryTest)
                        assert(!updatedKeys.isEmpty)
                    case let .leave(object: object, updatedKeys: updatedKeys):
                        assert(object is LiveQueryTest)
                        assert(!updatedKeys.isEmpty)
                    case let .update(object: object, updatedKeys: updatedKeys):
                        assert(object is LiveQueryTest)
                        assert(!updatedKeys.isEmpty)
                    default:
                        break
                    }
                    print(event)
                })
                self.liveQueryArray.append(liveQuery)
            } catch {
                fatalError("\(error)")
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 8
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "subscribe all"
        case 1:
            cell.textLabel?.text = "unsubscribe all"
        case 2:
            cell.textLabel?.text = "create"
        case 3:
            cell.textLabel?.text = "delete"
        case 4:
            cell.textLabel?.text = "enter and leave"
        case 5:
            cell.textLabel?.text = "update"
        case 6:
            cell.textLabel?.text = "user login"
        case 7:
            cell.textLabel?.text = "release live query"
        default:
            fatalError()
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            tableView.isUserInteractionEnabled = false
            DispatchQueue.global().async {
                let group = DispatchGroup()
                for item in self.liveQueryArray {
                    group.enter()
                    item.subscribe(completion: { (result) in
                        assert(Thread.isMainThread)
                        group.leave()
                        switch result {
                        case .success:
                            break
                        case .failure(error: let error):
                            print(error)
                        }
                    })
                }
                group.wait()
                DispatchQueue.main.async {
                    tableView.isUserInteractionEnabled = true
                }
            }
        case 1:
            tableView.isUserInteractionEnabled = false
            DispatchQueue.global().async {
                let group = DispatchGroup()
                for item in self.liveQueryArray {
                    group.enter()
                    item.unsubscribe(completion: { (result) in
                        assert(Thread.isMainThread)
                        group.leave()
                        switch result {
                        case .success:
                            break
                        case .failure(error: let error):
                            print(error)
                        }
                    })
                }
                group.wait()
                DispatchQueue.main.async {
                    tableView.isUserInteractionEnabled = true
                }
            }
        case 2:
            tableView.isUserInteractionEnabled = false
            let object = LiveQueryTest()
            object.numberField = Int.random(in: 0..<self.liveQueryArray.count).lcNumber
            object.stringField = UUID().uuidString.lcString
            object.save { (result) in
                tableView.isUserInteractionEnabled = true
                switch result {
                case .success:
                    break
                case .failure(error: let error):
                    print(error)
                }
            }
        case 3:
            tableView.isUserInteractionEnabled = false
            let query = LCQuery(className: "\(LiveQueryTest.self)")
            query.limit = 1
            _ = query.find { (result) in
                switch result {
                case .success(objects: let objects):
                    if let object = objects.first {
                        object.delete { (result) in
                            tableView.isUserInteractionEnabled = true
                            switch result {
                            case .success:
                                break
                            case .failure(error: let error):
                                print(error)
                            }
                        }
                    } else {
                        tableView.isUserInteractionEnabled = true
                    }
                case .failure(error: let error):
                    tableView.isUserInteractionEnabled = true
                    print(error)
                }
            }
        case 4:
            tableView.isUserInteractionEnabled = false
            let query = LCQuery(className: "\(LiveQueryTest.self)")
            query.limit = 1
            _ = query.find { (result) in
                switch result {
                case .success(objects: let objects):
                    if let object = objects.first as? LiveQueryTest, var number = object.numberField?.intValue {
                        if number == (self.liveQueryArray.count - 1) {
                            number = 0
                        } else {
                            number += 1
                        }
                        object.numberField = number.lcNumber
                        object.save(completion: { (result) in
                            tableView.isUserInteractionEnabled = true
                            switch result {
                            case .success:
                                break
                            case .failure(error: let error):
                                print(error)
                            }
                        })
                    } else {
                        tableView.isUserInteractionEnabled = true
                    }
                case .failure(error: let error):
                    tableView.isUserInteractionEnabled = true
                    print(error)
                }
            }
        case 5:
            tableView.isUserInteractionEnabled = false
            let query = LCQuery(className: "\(LiveQueryTest.self)")
            query.limit = 1
            _ = query.find { (result) in
                switch result {
                case .success(objects: let objects):
                    if let object = objects.first as? LiveQueryTest {
                        object.stringField = UUID().uuidString.lcString
                        object.save(completion: { (result) in
                            tableView.isUserInteractionEnabled = true
                            switch result {
                            case .success:
                                break
                            case .failure(error: let error):
                                print(error)
                            }
                        })
                    } else {
                        tableView.isUserInteractionEnabled = true
                    }
                case .failure(error: let error):
                    tableView.isUserInteractionEnabled = true
                    print(error)
                }
            }
        case 6:
            tableView.isUserInteractionEnabled = false
            LCUser.logOut()
            if let error = LCUser.logIn(username: self.username, password: self.password).error {
                print(error)
            }
            tableView.isUserInteractionEnabled = true
        case 7:
            if !self.liveQueryArray.isEmpty {            
                self.liveQueryArray.removeLast()
            }
        default:
            fatalError()
        }
    }

}
