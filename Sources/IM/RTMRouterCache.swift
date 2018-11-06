//
//  RTMRouterCache.swift
//  LeanCloud
//
//  Created by Tianyong Tang on 2018/11/6.
//  Copyright © 2018 LeanCloud. All rights reserved.
//

import Foundation

/**
 RTM router cache.
 */
final class RTMRouterCache: LocalStorage, LocalStorageProtocol {

    let name = "RTMRouterCache"

    var type = LocalStorageType.fileCacheOrMemory

    /**
     Get RTM routing table from cache.

     - returns: RTM routing table, or nil if not found or expired.
     */
    func getRoutingTable() throws -> RTMRoutingTable? {
        return try perform { _ in
            guard let entity: RTMRoutingTableEntity = try fetchAnyObject() else {
                return nil
            }

            guard
                let primaryURLString = entity.primary,
                let primaryURL = URL(string: primaryURLString),
                let expiration = entity.expiration,
                Date() < expiration
            else {
                try deleteAllObjects(type: RTMRoutingTableEntity.self)
                try save()
                return nil
            }

            var secondaryURL: URL?

            if let secondaryURLString = entity.secondary {
                secondaryURL = URL(string: secondaryURLString)
            }

            let routingTable = RTMRoutingTable(primary: primaryURL, secondary: secondaryURL, expiration: expiration)

            return routingTable
        }
    }

    /**
     Cache RTM routing table.

     - parameter routingTable: The routing table to be cached.
     */
    func setRoutingTable(_ routingTable: RTMRoutingTable) throws {
        try perform { _ in
            try withSingleton { (entity: RTMRoutingTableEntity, context) in
                entity.primary = routingTable.primary.absoluteString
                entity.secondary = routingTable.secondary?.absoluteString
                entity.expiration = routingTable.expiration
            }

            try save()
        }
    }

    /**
     Clear cache.
     */
    func clear() throws {
        try perform { _ in
            try deleteAllObjects(type: RTMRoutingTableEntity.self)
            try save()
        }
    }

}
