//
//  Message.swift
//  LeanCloud
//
//  Created by zapcannon87 on 2018/12/26.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/// IM Message
public class LCMessage: NSObject {
    
    public enum IOType {
        case `in`
        case out
    }
    
    public var ioType: IOType {
        if
            let fromClientID: String = self.fromClientID,
            let localClientID: String = self.localClientID,
            fromClientID == localClientID
        { return .out }
        else
        { return .in }
    }
    
    public enum Status: Int {
        case none = 0
        case sending = 1
        case sent = 2
        case delivered = 3
        case failed = 4
        case read = 5
    }
    
    public internal(set) var status: Status = .none
    
    public internal(set) var ID: String?
    
    public internal(set) var fromClientID: String?
    internal var localClientID: String?
    
    public internal(set) var conversationID: String?
    
    public internal(set) var sentTimestamp: Int64?
    public var sentDate: Date? {
        return date(fromMillisecond: sentTimestamp)
    }
    
    public internal(set) var deliveredTimestamp: Int64?
    public var deliveredDate: Date? {
        return date(fromMillisecond: deliveredTimestamp)
    }
    
    public internal(set) var readTimestamp: Int64?
    public var readDate: Date? {
        return date(fromMillisecond: readTimestamp)
    }
    
    public internal(set) var patchedTimestamp: Int64?
    public var patchedDate: Date? {
        return date(fromMillisecond: patchedTimestamp)
    }
    
    public let isAllMembersMentioned: Bool?
    
    public let mentionedMembers: [String]?
    
    public var isCurrentClientMentioned: Bool {
        if self.ioType == .out {
            return false
        } else {
            if self.isAllMembersMentioned == true {
                return true
            }
            if let id: String = self.localClientID,
                self.mentionedMembers?.contains(id) == true {
                return true
            }
            return false
        }
    }
    
    public enum Content {
        
        case string(String)
        
        case data(Data)
        
        var string: String? {
            switch self {
            case .string(let s): return s
            default: return nil
            }
        }
        
        var data: Data? {
            switch self {
            case .data(let d): return d
            default: return nil
            }
        }
        
    }
    
    public let content: Content
    
    public init(content: Content, isAllMembersMentioned: Bool? = nil, mentionedMembers: [String]? = nil) {
        self.content = content
        self.isAllMembersMentioned = isAllMembersMentioned
        self.mentionedMembers = mentionedMembers
        super.init()
    }
    
    var isTransient: Bool?
    
    var isOffline: Bool?
    
    var hasMore: Bool?
    
}

private extension LCMessage {
    
    func date(fromMillisecond timestamp: Int64?) -> Date? {
        guard let timestamp = timestamp else {
            return nil
        }
        let second = TimeInterval(timestamp) / 1000.0
        return Date(timeIntervalSince1970: second)
    }
    
}
