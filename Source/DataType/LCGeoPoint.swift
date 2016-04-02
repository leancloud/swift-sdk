//
//  LCGeoPoint.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/1/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 LeanCloud geography point type.

 This type can be used to represent a 2D location with latitude and longitude.
 */
public final class LCGeoPoint: LCType {
    public private(set) var latitude: Double = 0
    public private(set) var longitude: Double = 0

    override var JSONValue: AnyObject? {
        return [
            "__type": "GeoPoint",
            "latitude": latitude,
            "longitude": longitude
        ]
    }

    public required init() {
        super.init()
    }

    public convenience init(latitude: Double, longitude: Double) {
        self.init()
        self.latitude = latitude
        self.longitude = longitude
    }

    public override func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! LCGeoPoint
        copy.latitude = latitude
        copy.longitude = longitude
        return copy
    }

    public override func isEqual(another: AnyObject?) -> Bool {
        if another === self {
            return true
        } else if let another = another as? LCGeoPoint {
            return another.latitude == latitude && another.longitude == longitude
        } else {
            return false
        }
    }
}