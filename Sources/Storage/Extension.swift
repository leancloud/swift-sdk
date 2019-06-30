//
//  Extension.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 3/24/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation
import Alamofire

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
    return "".padding(toLength: rhs * lhs.count, withPad: lhs, startingAt: 0)
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
        let elements: [(Key, T)] = try compactMap { (key, value) in
            (key, try transform(value))
        }
        return Dictionary<Key, T>(elements: elements)
    }

    func compactMapValue<T>(_ transform: (Value) throws -> T?) rethrows -> [Key: T] {
        let elements: [(Key, T)] = try compactMap { (key, value) in
            guard let value = try transform(value) else {
                return nil
            }
            return (key, value)
        }
        return Dictionary<Key, T>(elements: elements)
    }
    
    /*
     Maybe you will think: Why use JSONSerialization encoding and decoding `Dictionary` ?
     
     Because a Swift Raw Data Type `[String: Any]` is Strong-Type-Checking.
     
     e.g.
     ```
     var dic: [String: Any] = ["foo": Int32(1)]
     (dic["foo"] as? Int) == nil
     (dic["foo"] as? Int32) == Optional(1)
     ```
     
     But after JSONSerialization's encoding and decoding.
     
     The Swift Type `[String: Any]` has been converted to a Real JSON Object.
     
     ```
     dic = try! dic.jsonObject()
     (dic["foo"] as? Int) == Optional(1)
     (dic["foo"] as? Int32) == Optional(1)
     ```
     
     This will make data better for SDK to handle it.
     */
    func jsonObject() throws -> [Key: Value]? {
        let data: Data = try JSONSerialization.data(withJSONObject: self)
        if let json: [Key: Value] = try JSONSerialization.jsonObject(with: data) as? [Key: Value] {
            return json
        } else {
            return nil
        }
    }
    
    func jsonString(using encoding: String.Encoding = .utf8, options: JSONSerialization.WritingOptions = []) throws -> String? {
        let data = try JSONSerialization.data(withJSONObject: self, options: options)
        return String(data: data, encoding: encoding)
    }
}

extension String {

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

    var urlPathEncoded: String {
        return addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
    }

    var urlQueryEncoded: String {
        return URLEncoding.queryString.escape(self)
    }

    func appendingPathComponent(_ component: String) -> String {
        return (self as NSString).appendingPathComponent(component)
    }

    func prefix(upTo end: Int) -> String {
        return String(prefix(upTo: index(startIndex, offsetBy: end)))
    }
    
    func jsonObject<T>(using encoding: String.Encoding = .utf8, options: JSONSerialization.ReadingOptions = []) throws -> T? {
        guard !self.isEmpty else { return nil }
        if let data: Data = self.data(using: encoding) {
            return try JSONSerialization.jsonObject(with: data, options: options) as? T
        } else {
            return nil
        }
    }
    
}

extension Sequence {

    var unique: [Element] {
        return NSOrderedSet(array: Array(self)).array as? [Element] ?? []
    }

}

extension LCError {

    /**
     Initialize with an LCResponse object.

     - parameter response: The response object.
     */
    init?(response: LCResponse) {
        /*
         Guard response has error.
         If error not found, it means that the response is OK, there's no need to create error.
         */
        guard let error = response.error else {
            return nil
        }

        guard let data = response.data else {
            self = LCError(underlyingError: error)
            return
        }

        let body: Any

        do {
            body = try JSONSerialization.jsonObject(with: data, options: [])
        } catch
            /*
             We discard the deserialization error,
             because it's not the real error that user should care about.
             */
            _
        {
            self = LCError(underlyingError: error)
            return
        }

        /*
         Try to extract error from HTTP body,
         which contains the error defined in https://leancloud.cn/docs/error_code.html
         */
        if
            let body = body as? [String: Any],
            let code = body["code"] as? Int,
            let reason = body["error"] as? String
        {
            self = LCError(code: code, reason: reason, userInfo: nil)
        } else {
            self = LCError(underlyingError: error)
        }
    }

}

/**
 Synchronize on an object and do something.

 - parameter object: The object locked on.
 - parameter body: Something you want to do.

 - returns: Result of body.
 */
func synchronize<T>(on object: Any, body: () throws -> T) rethrows -> T {
    objc_sync_enter(object)

    defer { objc_sync_exit(object) }

    return try body()
}

/**
 Dispatch task in main queue asynchronously.

 - parameter task: The task to be dispatched.
 */
func mainQueueAsync(task: @escaping () -> Void) {
    DispatchQueue.main.async {
        task()
    }
}

/**
 Dispatch task in main queue synchronously.

 - parameter task: The task to be dispatched.
 */
func mainQueueSync<T>(task: () throws -> T) rethrows -> T {
    if Thread.isMainThread {
        return try task()
    } else {
        return try DispatchQueue.main.sync {
            try task()
        }
    }
}

/**
 Wait an asynchronous task to be done.

 - parameter task: The task to be done.

 - note: When task finish it's job, it must call `fulfill` to provide expected result.
 */
func expect<T>(_ task: @escaping (_ fulfill: @escaping (T) -> Void) throws -> Void) rethrows -> T {
    var result: T!

    let dispatchGroup = DispatchGroup()

    dispatchGroup.enter()

    try task { value in
        result = value
        dispatchGroup.leave()
    }

    dispatchGroup.wait()

    return result
}
