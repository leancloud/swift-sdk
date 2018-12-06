//
//  Conversation.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/11/26.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/**
 IM Conversation.

 Conversations are used to group clients and messages.
 */
public class LCConversation: LCObject {

    /// Conversation name.
    @objc open dynamic var name: LCString?

    /**
     Current client.

     - note: Conversation retain a strong reference to client.
     */
    public private(set) var client: LCClient?

    public final override class func objectClassName() -> String {
        return "_Conversation"
    }

}

/**
 IM chat room conversation.

 It lacks some features such as Offline Message and Push Notification.

 However, it can contain more clients.
 */
public final class LCChatRoomConversation: LCConversation {}

/**
 IM temporary conversation.
 */
public final class LCTemporaryConversation: LCConversation {}
