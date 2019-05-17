//
//  LCRole.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 5/7/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud role type.

 A type to group user for access control.
 Conceptually, it is equivalent to UNIX user group.
 */
public class LCRole: LCObject {
    /**
     Name of role.

     The name must be unique throughout the application.
     It will be used as key in ACL to refer the role.
     */
    @objc dynamic public var name: LCString?

    /// Relation of users.
    @objc dynamic public var users: LCRelation?

    /// Relation of roles.
    @objc dynamic public var roles: LCRelation?

    public final override class func objectClassName() -> String {
        return "_Role"
    }

    /**
     Create an role with name.

     - parameter name: The name of role.
     */
    public convenience init(
        application: LCApplication = LCApplication.default,
        name: String)
    {
        self.init(application: application)
        self.name = LCString(name)
    }
}
