//
//  Query.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/19/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

final public class Query {
    /// Query class name.
    public private(set) var className: String

    /**
     Constraint for key.
     */
    public enum Constraint {
        case Included
        case Selected

        case Existed
        case NotExisted

        case EqualTo(value: LCType)
        case NotEqualTo(value: LCType)
        case LessThan(value: LCType)
        case LessThanOrEqualTo(value: LCType)
        case GreaterThan(value: LCType)
        case GreaterThanOrEqualTo(value: LCType)

        case ContainedIn(array: LCArray)
        case NotContainedIn(array: LCArray)
        case ContainedAllIn(array: LCArray)
        case EqualToSize(size: LCNumber)

        case NearbyPoint(point: LCGeoPoint)
        case NearbyPointWithRange(point: LCGeoPoint, min: LCGeoPoint.Distance?, max: LCGeoPoint.Distance?)
        case NearbyPointWithRectangle(point: LCGeoPoint, southwest: LCGeoPoint, northeast: LCGeoPoint)

        case MatchedQuery(query: Query)
        case NotMatchedQuery(query: Query)
        case MatchedQueryAndKey(query: Query, key: String)
        case NotMatchedQueryAndKey(query: Query, key: String)

        case MatchedPattern(pattern: String, option: String?)
        case MatchedSubstring(string: String)
        case PrefixedBy(string: String)
        case SuffixedBy(string: String)
    }

    /**
     Construct query with class name.

     - parameter className: The class name to query.
     */
    public init(className: String) {
        self.className = className
    }

    /**
     Add constraint in query.

     - parameter constraint: The constraint.
     */
    public func whereKey(key: String, _ constraint: Constraint) {
        /* Stub method. */
    }
}