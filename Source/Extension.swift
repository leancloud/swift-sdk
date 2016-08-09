//
//  Extension.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/24/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

infix operator +~ {
    associativity left
}

func +(lhs: [LCType], rhs: [LCType]) -> [LCType] {
    var result = lhs

    result.appendContentsOf(rhs)

    return result
}

func +~(lhs: [LCType], rhs: [LCType]) -> [LCType] {
    var result = lhs

    rhs.forEach { element in
        if !(result.contains { $0.isEqual(element) }) {
            result.append(element)
        }
    }

    return result
}

func -(lhs: [LCType], rhs: [LCType]) -> [LCType] {
    return lhs.filter { element in
        !rhs.contains { $0.isEqual(element) }
    }
}

func +<T: LCType>(lhs: [T], rhs: [T]) -> [T] {
    return ((lhs as [LCType]) + (rhs as [LCType])) as! [T]
}

func +~<T: LCType>(lhs: [T], rhs: [T]) -> [T] {
    return ((lhs as [LCType]) +~ (rhs as [LCType])) as! [T]
}

func -<T: LCType>(lhs: [T], rhs: [T]) -> [T] {
    return ((lhs as [LCType]) - (rhs as [LCType])) as! [T]
}

func *(lhs: String, rhs: Int) -> String {
    return "".stringByPaddingToLength(rhs * lhs.characters.count, withString: lhs, startingAtIndex: 0)
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

extension String {
    var MD5String: String {
        let bytes = Array<MD5.Byte>(self.utf8)
        let encodedBytes = MD5.calculate(bytes)

        let string = encodedBytes.reduce("") { string, byte in
            let radix = 16
            let hex = String(byte, radix: radix)
            let sum = string + (byte < MD5.Byte(radix) ? "0" : "") + hex
            return sum
        }

        return string
    }

    var regularEscapedString: String {
        return NSRegularExpression.escapedPatternForString(self)
    }

    var firstUppercaseString: String {
        guard !isEmpty else { return self }

        var result = self
        result.replaceRange(startIndex...startIndex, with: String(self[startIndex]).uppercaseString)
        return result
    }

    var firstLowercaseString: String {
        guard !isEmpty else { return self }

        var result = self
        result.replaceRange(startIndex...startIndex, with: String(self[startIndex]).lowercaseString)
        return result
    }

    var doubleQuoteEscapedString: String {
        return stringByReplacingOccurrencesOfString("\"", withString: "\\\"")
    }
}

extension CollectionType {
    func unique(equal: (a: Generator.Element, b: Generator.Element) -> Bool) -> [Generator.Element] {
        var result: [Generator.Element] = []

        for candidate in self {
            var existed = false
            for element in result {
                if equal(a: candidate, b: element) {
                    existed = true
                    break
                }
            }
            if !existed {
                result.append(candidate)
            }
        }

        return result
    }
}