//
//  Extension.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/24/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

precedencegroup UniqueAdd {
    associativity: left
}

infix operator +~ : UniqueAdd

func +(lhs: [LCValue], rhs: [LCValue]) -> [LCValue] {
    var result = lhs

    result.append(contentsOf: rhs)

    return result
}

func +~(lhs: [LCValue], rhs: [LCValue]) -> [LCValue] {
    var result = lhs

    rhs.forEach { element in
        if !(result.contains { $0.isEqual(element) }) {
            result.append(element)
        }
    }

    return result
}

func -(lhs: [LCValue], rhs: [LCValue]) -> [LCValue] {
    return lhs.filter { element in
        !rhs.contains { $0.isEqual(element) }
    }
}

func +<T: LCValue>(lhs: [T], rhs: [T]) -> [T] {
    return ((lhs as [LCValue]) + (rhs as [LCValue])) as! [T]
}

func +~<T: LCValue>(lhs: [T], rhs: [T]) -> [T] {
    return ((lhs as [LCValue]) +~ (rhs as [LCValue])) as! [T]
}

func -<T: LCValue>(lhs: [T], rhs: [T]) -> [T] {
    return ((lhs as [LCValue]) - (rhs as [LCValue])) as! [T]
}

func *(lhs: String, rhs: Int) -> String {
    return "".padding(toLength: rhs * lhs.characters.count, withPad: lhs, startingAt: 0)
}

func ==(lhs: [LCValue], rhs: [LCValue]) -> Bool {
    let count = lhs.count

    guard count == rhs.count else {
        return false
    }

    for index in 0..<count {
        guard lhs[index].isEqual(rhs[index]) else {
            return false
        }
    }

    return true
}

func ==<K, V: Equatable>(lhs: [K: [K: V]], rhs: [K: [K: V]]) -> Bool {
    guard lhs.count == rhs.count else {
        return false
    }

    for (key, lval) in lhs {
        guard let rval = rhs[key] else {
            return false
        }
        guard lval == rval else {
            return false
        }
    }

    return true
}

func ==(lhs: [LCDictionary.Key: LCDictionary.Value], rhs: [LCDictionary.Key: LCDictionary.Value]) -> Bool {
    guard lhs.count == rhs.count else {
        return false
    }

    for (key, lval) in lhs {
        guard let rval = rhs[key] else {
            return false
        }
        guard lval.isEqual(rval) else {
            return false
        }
    }

    return true
}

extension Dictionary {
    init(elements: [Element]) {
        self.init()

        for (key, value) in elements {
            self[key] = value
        }
    }

    func mapValue<T>(_ transform: (Value) throws -> T) rethrows -> [Key: T] {
        let elements = try map { (key, value) in (key, try transform(value)) }
        return Dictionary<Key, T>(elements: elements)
    }
}

extension String {
    var md5String: String {
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
        return NSRegularExpression.escapedPattern(for: self)
    }

    var firstUppercaseString: String {
        guard !isEmpty else { return self }

        var result = self
        result.replaceSubrange(startIndex...startIndex, with: String(self[startIndex]).uppercased())
        return result
    }

    var firstLowercaseString: String {
        guard !isEmpty else { return self }

        var result = self
        result.replaceSubrange(startIndex...startIndex, with: String(self[startIndex]).lowercased())
        return result
    }

    var doubleQuoteEscapedString: String {
        return replacingOccurrences(of: "\"", with: "\\\"")
    }
}

extension Collection {
    func unique(_ equal: (_ a: Iterator.Element, _ b: Iterator.Element) -> Bool) -> [Iterator.Element] {
        var result: [Iterator.Element] = []

        for candidate in self {
            var existed = false
            for element in result {
                if equal(candidate, element) {
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
