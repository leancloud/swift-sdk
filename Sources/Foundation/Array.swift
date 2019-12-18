//
//  LCArray.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/// LeanCloud List Type
public class LCArray: NSObject, LCValue, Collection, ExpressibleByArrayLiteral {
    public typealias Index = Int
    public typealias Element = LCValue

    public private(set) var value: [Element] = []

    public override init() {
        super.init()
    }

    public convenience init(_ value: [Element]) {
        self.init()
        self.value = value
    }

    public convenience init(_ value: [LCValueConvertible]) {
        self.init()
        self.value = value.map { $0.lcValue }
    }
    
    public convenience init(_ array: LCArray) {
        self.init()
        self.value = array.value
    }

    public convenience required init(arrayLiteral elements: LCValueConvertible...) {
        self.init(elements)
    }

    public convenience init(
        application: LCApplication = .default,
        unsafeObject: Any)
        throws
    {
        self.init()
        guard let object = unsafeObject as? [Any] else {
            throw LCError(
                code: .malformedData,
                reason: "Failed to construct \(LCArray.self) with a \(type(of: unsafeObject)) object.")
        }
        self.value = try object.map { element in
            try ObjectProfiler.shared.object(application: application, jsonValue: element)
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        self.value = (aDecoder.decodeObject(forKey: "value") as? [Element]) ?? []
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.value, forKey: "value")
    }

    public func copy(with zone: NSZone?) -> Any {
        return LCArray(self)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? LCArray {
            return object === self || object.value == self.value
        } else {
            return false
        }
    }

    public func makeIterator() -> IndexingIterator<[Element]> {
        return self.value.makeIterator()
    }

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return self.value.count
    }

    public func index(after i: Int) -> Int {
        return self.value.index(after: i)
    }

    public subscript(index: Int) -> LCValue {
        get {
            return self.value[index]
        }
    }

    public var jsonValue: Any {
        return self.value.map { $0.jsonValue }
    }

    public var jsonString: String {
        return self.formattedJSONString(indentLevel: 0)
    }

    public var rawValue: Any {
        return self.value.map { $0.rawValue }
    }
}

extension LCArray: LCValueExtension {
    
    var lconValue: Any? {
        return self.value.compactMap { ($0 as? LCValueExtension)?.lconValue }
    }
    
    static func instance(application: LCApplication) -> LCValue {
        return self.init()
    }
    
    func forEachChild(_ body: (_ child: LCValue) throws -> Void) rethrows {
        try forEach { try body($0) }
    }
    
    func add(_ other: LCValue) throws -> LCValue {
        throw LCError(
            code: .invalidType,
            reason: "\(LCArray.self) cannot do `add(_:)`.")
    }
    
    func concatenate(_ other: LCValue, unique: Bool) throws -> LCValue {
        guard let elements = (other as? LCArray)?.value else {
            throw LCError(
                code: .invalidType,
                reason: "\(LCArray.self) cannot do `concatenate(_:unique:)` with a \(type(of: other)) object.")
        }
        let result = LCArray(self.value)
        result.concatenateInPlace(elements, unique: unique)
        return result
    }
    
    func concatenateInPlace(_ elements: [Element], unique: Bool) {
        self.value = unique
            ? (self.value +~ elements)
            : (self.value + elements)
    }
    
    func differ(_ other: LCValue) throws -> LCValue {
        guard let elements = (other as? LCArray)?.value else {
            throw LCError(
                code: .invalidType,
                reason: "\(LCArray.self) cannot do `differ(_:)` with a \(type(of: other)) object.")
        }
        let result = LCArray(self.value)
        result.differInPlace(elements)
        return result
    }
    
    func differInPlace(_ elements: [Element]) {
        self.value = (self.value - elements)
    }
    
    func formattedJSONString(indentLevel: Int, numberOfSpacesForOneIndentLevel: Int = 4) -> String {
        if self.value.isEmpty {
            return "[]"
        }
        let lastIndent = " " * (numberOfSpacesForOneIndentLevel * indentLevel)
        let bodyIndent = " " * (numberOfSpacesForOneIndentLevel * (indentLevel + 1))
        let body = self.value
            .compactMap {
                ($0 as? LCValueExtension)?.formattedJSONString(
                    indentLevel: indentLevel + 1,
                    numberOfSpacesForOneIndentLevel: numberOfSpacesForOneIndentLevel) }
            .joined(separator: ",\n" + bodyIndent)
        return "[\n\(bodyIndent)\(body)\n\(lastIndent)]"
    }
}
