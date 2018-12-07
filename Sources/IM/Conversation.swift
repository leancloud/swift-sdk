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
public class LCConversation {

    /// Conversation ID.
    public let id: String

    /// Conversation name.
    public internal(set) var name: String?

    /// Creation date.
    public internal(set) var createdAt: Date?

    /**
     Initialize conversation.

     - parameter id: The conversation ID.
     */
    init(id: String) {
        self.id = id
    }

    /**
     Current client.

     - note: Conversation retain a strong reference to client.
     */
    public internal(set) var client: LCClient?

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
