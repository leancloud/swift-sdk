//
//  Extension.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/24/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

func +<T: LCType>(left: [T]?, right: [T]?) -> [T]? {
    if let right = right {
        var result = left ?? []

        result.appendContentsOf(right)

        return result
    } else {
        return left
    }
}

func +~<T: LCType>(left: [T]?, right: [T]?) -> [T]? {
    if let right = right {
        var result = left ?? []

        right.forEach { (element) in
            if !result.contains(element) {
                result.append(element)
            }
        }

        return result
    } else {
        return left
    }
}

func -<T: LCType>(left: [T]?, right: [T]?) -> [T]? {
    if let left = left {
        if let right = right {
            return left.filter { !right.contains($0) }
        } else {
            return left
        }
    } else {
        return nil
    }
}

extension Dictionary {
    init(elements: [Element]) {
        self.init()

        for (key, value) in elements {
            self[key] = value
        }
    }

    func mapValue<T>(@noescape transform: Value throws -> T) rethrows -> [Key: T] {
        let elements = try map { (key, value) in (key, try transform(value)) }
        return Dictionary<Key, T>(elements: elements)
    }
}