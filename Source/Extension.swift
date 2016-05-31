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

func +(left: LCType, right: LCType?) -> LCType? {
    return left.add(right)
}

func +~(left: LCType, right: LCType?) -> LCType? {
    return left.add(right, unique: true)
}

func -(left: LCType, right: LCType?) -> LCType? {
    return left.subtract(right)
}

func +<T: LCType>(left: [T], right: [T]) -> [T] {
    var result = left

    result.appendContentsOf(right)

    return result
}

func +~<T: LCType>(left: [T], right: [T]) -> [T] {
    var result = left

    right.forEach { element in
        if !result.contains(element) {
            result.append(element)
        }
    }

    return result
}

func -<T: LCType>(left: [T], right: [T]) -> [T] {
    return left.filter { element in
        !right.contains(element)
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

extension NSThread {
    func lc_executeBlock(block: () -> Void) {
        block()
    }

    func lc_performBlock(block: () -> Void) {
        if NSThread.currentThread() !== self {
            let block = unsafeBitCast(block as @convention(block) () -> Void, AnyObject.self)
            self.performSelector(#selector(lc_executeBlock(_:)), onThread: self, withObject: block, waitUntilDone: true)
        } else {
            block()
        }
    }
}