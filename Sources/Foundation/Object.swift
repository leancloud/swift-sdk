//
//  Object.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 2/23/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/// LeanCloud Object Type.
@dynamicMemberLookup
open class LCObject: NSObject, LCValue, LCValueExtension, Sequence {
    
    // MARK: Property
    
    /// The application this object belong to.
    public let application: LCApplication
    
    /// Access Control List.
    @objc public dynamic var ACL: LCACL?

    /// The identifier of this object.
    @objc public dynamic private(set) var objectId: LCString?
    
    /// The created date of this object.
    @objc public dynamic private(set) var createdAt: LCDate?
    
    /// The updated date of this object.
    @objc public dynamic private(set) var updatedAt: LCDate?

    /**
     The table of properties.

     - note: This property table may not contains all properties, 
             because when a property did set in initializer, its setter hook will not be called in Swift.
             This property is intent for internal use.
             For accesssing all properties, please use `dictionary` property.
     */
    private var propertyTable: LCDictionary = [:]

    /// The table of all properties.
    lazy var dictionary: LCDictionary = {
        /**
         Synchronize property table.
         
         This method will synchronize nonnull instance variables into property table.
         
         Q: Why we need this method?
         
         A: When a property is set through dot syntax in initializer, its corresponding setter hook will not be called,
         it will result in that some properties will not be added into property table.
         */
        ObjectProfiler.shared.iterateProperties(self) { (key, _) in
            guard let ivarValue = Runtime.instanceVariableValue(self, key) as? LCValue else {
                return
            }
            if let value = self.propertyTable[key]?.lcValue,
                value === ivarValue {
                return
            }
            self.propertyTable[key] = ivarValue
        }
        return self.propertyTable
    }()

    public var hasObjectId: Bool {
        return self.objectId != nil
    }
    
    private(set) var objectClassName: String?

    var actualClassName: String {
        if let className = (self["className"] as? LCString)?.value {
            return className
        } else if let className = self.objectClassName {
            return className
        }
        return type(of: self).objectClassName()
    }

    /// The temp in-memory object identifier.
    lazy var internalId: String = {
        Utility.compactUUID
    }()

    /// Operation hub.
    /// Used to manage update operations.
    var operationHub: OperationHub?

    /// Whether this object has unsync-data to upload to server.
    public var hasDataToUpload: Bool {
        if self.hasObjectId {
            if let operationHub = self.operationHub {
                return !operationHub.isEmpty
            } else {
                return false
            }
        } else {
            return true
        }
    }
    
    // MARK: Subclassing
    
    /**
     Set class name of current type.
     
     The default implementation returns the class name without root module.
     
     - returns: The class name of current type.
     */
    open class func objectClassName() -> String {
        let className = String(validatingUTF8: class_getName(self))!
        
        /* Strip root namespace to cope with application package name's change. */
        if let index = className.firstIndex(of: ".") {
            let startIndex: String.Index = className.index(after: index)
            return String(className[startIndex...])
        } else {
            return className
        }
    }
    
    /**
     Register current object class manually.
     */
    public static func register() {
        ObjectProfiler.shared.registerClass(self)
    }
    
    // MARK: Initialization
    
    /// Initializing a new object with default application.
    public override required init() {
        self.application = .default
        super.init()
        self.operationHub = OperationHub(self)
        self.propertyTable.elementDidChange = { [weak self] (key, value) in
            Runtime.setInstanceVariable(self, key, value)
        }
    }
    
    /// Initializing a new object with an application.
    /// - Parameter application: The application this object belong to.
    public required init(application: LCApplication) {
        self.application = application
        super.init()
        self.operationHub = OperationHub(self)
        self.propertyTable.elementDidChange = { [weak self] (key, value) in
            Runtime.setInstanceVariable(self, key, value)
        }
    }
    
    /// Initializing a new object with an application and a identifier.
    /// - Parameters:
    ///   - application: The application this object belong to.
    ///   - objectId: The identifier of an exist object.
    public convenience init(
        application: LCApplication = .default,
        objectId: LCStringConvertible)
    {
        self.init(application: application)
        self.objectId = objectId.lcString
    }
    
    /// Initializing a new object with an application and class name.
    /// - Parameters:
    ///   - application: The application this object belong to.
    ///   - className: The class name of this object.
    public convenience init(
        application: LCApplication = .default,
        className: LCStringConvertible)
    {
        self.init(application: application)
        self.objectClassName = className.lcString.value
    }
    
    /// Initializing a new object with an application, a identifier and class name.
    /// - Parameters:
    ///   - application: The application this object belong to.
    ///   - className: The class name of this object.
    ///   - objectId: The identifier of an exist object.
    public convenience init(
        application: LCApplication = .default,
        className: LCStringConvertible,
        objectId: LCStringConvertible)
    {
        self.init(application: application)
        self.objectClassName = className.lcString.value
        self.objectId = objectId.lcString
    }

    convenience init(application: LCApplication, dictionary: LCDictionaryConvertible) {
        self.init(application: application)
        for (key, value) in dictionary.lcDictionary {
            self.propertyTable[key] = value
        }
    }
    
    // MARK: NSCoding
    
    /// Returns an object initialized from data in a given unarchiver.
    /// - Parameter coder: An unarchiver object.
    public required convenience init?(coder: NSCoder) {
        let application: LCApplication
        if let applicationID = coder.decodeObject(forKey: "applicationID") as? String,
            let registeredApplication = LCApplication.registry[applicationID] {
            application = registeredApplication
        } else {
            application = LCApplication.default
        }
        self.init(application: application)
        self.objectClassName = coder.decodeObject(forKey: "objectClassName") as? String
        let dictionary: LCDictionary = (coder.decodeObject(forKey: "propertyTable") as? LCDictionary) ?? [:]
        for (key, value) in dictionary {
            self.propertyTable[key] = value
        }
    }
    
    /// Encodes the receiver using a given archiver.
    /// - Parameter coder: An archiver object.
    public func encode(with coder: NSCoder) {
        let applicationID: String = self.application.id
        let propertyTable: LCDictionary = self.dictionary.copy() as! LCDictionary
        coder.encode(applicationID, forKey: "applicationID")
        coder.encode(propertyTable, forKey: "propertyTable")
        if let objectClassName = self.objectClassName {
            coder.encode(objectClassName, forKey: "objectClassName")
        }
    }
    
    // MARK: NSCopying
    
    /// Will not do copying, just return a pointer to this object.
    /// - Parameter zone: Unused, just pass nil.
    open func copy(with zone: NSZone?) -> Any {
        return self
    }
    
    // MARK: NSObjectProtocol

    open override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? LCObject {
            return object === self || (hasObjectId && object.objectId == objectId)
        } else {
            return false
        }
    }

    open override func value(forKey key: String) -> Any? {
        return self[key]
            ?? super.value(forKey: key)
    }
    
    open override func value(forUndefinedKey key: String) -> Any? {
        return nil
    }
    
    // MARK: Sequence

    open func makeIterator() -> DictionaryIterator<String, LCValue> {
        return dictionary.makeIterator()
    }
    
    // MARK: LCValue

    open var jsonValue: Any {
        var result: [String: Any] = [:]

        if let properties = dictionary.jsonValue as? [String: Any] {
            result.merge(properties) { (lhs, rhs) in rhs }
        }

        result["__type"]    = "Object"
        result["className"] = actualClassName

        return result
    }

    open var jsonString: String {
        return formattedJSONString(indentLevel: 0)
    }

    public var rawValue: Any {
        return self
    }
    
    // MARK: LCValueExtension
    
    func formattedJSONString(indentLevel: Int, numberOfSpacesForOneIndentLevel: Int = 4) -> String {
        let dictionary = LCDictionary(self.dictionary)
        
        dictionary["__type"] = "Object".lcString
        dictionary["className"] = actualClassName.lcString
        
        return dictionary.formattedJSONString(indentLevel: indentLevel, numberOfSpacesForOneIndentLevel: numberOfSpacesForOneIndentLevel)
    }

    var lconValue: Any? {
        guard let objectId = objectId else {
            return nil
        }

        return [
            "__type"    : "Pointer",
            "className" : actualClassName,
            "objectId"  : objectId.value
        ]
    }
    
    static func instance(application: LCApplication) -> LCValue {
        return self.init(application: application)
    }

    func forEachChild(_ body: (_ child: LCValue) throws -> Void) rethrows {
        try dictionary.forEachChild(body)
    }

    func add(_ other: LCValue) throws -> LCValue {
        throw LCError(code: .invalidType, reason: "Object cannot be added.")
    }

    func concatenate(_ other: LCValue, unique: Bool) throws -> LCValue {
        throw LCError(code: .invalidType, reason: "Object cannot be concatenated.")
    }

    func differ(_ other: LCValue) throws -> LCValue {
        throw LCError(code: .invalidType, reason: "Object cannot be differed.")
    }
    
    // MARK: Key Value Change
    
    func getProperty<Value: LCValue>(_ key: String) throws -> Value? {
        let value = self.propertyTable[key]
        if let value = value {
            guard value is Value else {
                throw LCError(
                    code: .invalidType,
                    reason: "Failed to get property, Type mismatch.",
                    userInfo: [
                        "key": key,
                        "source_type": "\(type(of: value))",
                        "target_type": "\(Value.self)"])
            }
        }
        return value as? Value
    }
    
    func loadProperty<Value: LCValue>(_ key: String) throws -> Value {
        if let value: Value = try self.getProperty(key) {
            return value
        }
        guard let type = Value.self as? LCValueExtension.Type,
            let value = type.instance(application: self.application) as? Value else {
                throw LCError(
                    code: .invalidType,
                    reason: "Failed to load property, Type cannot be instantiated.",
                    userInfo: [
                        "key": key,
                        "target_type": "\(Value.self)"])
        }
        self.propertyTable[key] = value
        return value
    }
    
    func updateProperty(_ operation: Operation) throws {
        guard case let .key(key) = operation.key else {
            return
        }
        let value = operation.value
        switch operation.name {
        case .set, .delete:
            self.willChangeValue(forKey: key)
            self.propertyTable[key] = value
            self.didChangeValue(forKey: key)
        case .increment:
            guard let number = value as? LCNumber else {
                throw LCError(
                    code: .invalidType,
                    reason: "Failed to increase property, Type mismatch.",
                    userInfo: ["key": key, "value_type": "\(type(of: value))"])
            }
            let property: LCNumber = try self.loadProperty(key)
            self.willChangeValue(forKey: key)
            property.addInPlace(number.value)
            self.didChangeValue(forKey: key)
        case .add, .addUnique, .remove:
            guard let array = value as? LCArray else {
                let reason = (operation.name == .remove)
                    ? "Failed to remove objects from property"
                    : "Failed to add objects to property"
                throw LCError(
                    code: .invalidType,
                    reason: "\(reason), Type mismatch.",
                    userInfo: ["key": key, "value_type": "\(type(of: value))"])
            }
            if operation.name == .remove {
                let property: LCArray? = try self.getProperty(key)
                self.willChangeValue(forKey: key)
                property?.differInPlace(array.value)
                self.didChangeValue(forKey: key)
            } else {
                let property: LCArray = try self.loadProperty(key)
                self.willChangeValue(forKey: key)
                property.concatenateInPlace(array.value, unique: (operation.name == .addUnique))
                self.didChangeValue(forKey: key)
            }
        case .addRelation, .removeRelation:
            guard let array = value as? LCArray,
                let elements = array.value as? [LCRelation.Element] else {
                    let reason = (operation.name == .addRelation)
                        ? "Failed to add relations to property"
                        : "Failed to remove relations from property"
                    throw LCError(
                        code: .invalidType,
                        reason: "\(reason), Type mismatch.",
                        userInfo: ["key": key, "value_type": "\(type(of: value))"])
            }
            if operation.name == .addRelation {
                let relation: LCRelation = try self.loadProperty(key)
                self.willChangeValue(forKey: key)
                try relation.appendElements(elements)
                self.didChangeValue(forKey: key)
            } else {
                let relation: LCRelation? = try self.getProperty(key)
                self.willChangeValue(forKey: key)
                relation?.removeElements(elements)
                self.didChangeValue(forKey: key)
            }
        }
    }
    
    func updateByKeyPath(_ operation: Operation) throws {
        guard case let .keyPath(key: _, path: path) = operation.key else {
            return
        }
        var dictionary: LCDictionary?
        for (index, key) in path.enumerated() {
            if index == 0 {
                dictionary = self[key] as? LCDictionary
            } else if index != (path.count - 1) {
                dictionary = dictionary?[key] as? LCDictionary
            }
        }
        if let dictionary = dictionary, let key = path.last {
            let value = operation.value
            switch operation.name {
            case .set, .delete:
                dictionary[key] = value
            case .increment:
                if let value = value as? LCNumber,
                    let number = dictionary[key] as? LCNumber {
                    number.addInPlace(value.value)
                }
            case .add, .addUnique, .remove:
                if let value = value as? LCArray,
                    let array = dictionary[key] as? LCArray {
                    if operation.name == .remove {
                        array.differInPlace(value.value)
                    } else {
                        array.concatenateInPlace(value.value, unique: (operation.name == .addUnique))
                    }
                }
            default:
                break
            }
        }
    }
    
    func addOperation(_ name: Operation.Name, _ key: String, _ value: LCValue? = nil) throws {
        let operation = try Operation(name: name, key: key, value: value)
        switch operation.key {
        case .key:
            try self.updateProperty(operation)
        case .keyPath:
            guard self.hasObjectId else {
                throw LCError(
                    code: .notFound,
                    reason: "Object ID not found, Key-Path is unavailable on an object without a valid ID.",
                    userInfo: ["key": key])
            }
            guard operation.name != .addRelation,
                operation.name != .removeRelation else {
                    throw LCError(
                        code: .inconsistency,
                        reason: "Relation operation is unavailable for Key-Path.",
                        userInfo: ["key": key])
            }
            try self.updateByKeyPath(operation)
        }
        try self.operationHub?.reduce(operation)
    }
    
    func transformValue(_ key: String, _ value: LCValue?) -> LCValue? {
        guard let value = value else {
            return nil
        }
        switch key {
        case "ACL":
            return LCACL(jsonValue: value.jsonValue)
        case "createdAt", "updatedAt":
            return LCDate(jsonValue: value.jsonValue)
        default:
            return value
        }
    }
    
    func update(_ key: String, _ value: LCValue?) {
        self.willChangeValue(forKey: key)
        self.propertyTable[key] = self.transformValue(key, value)
        self.didChangeValue(forKey: key)
    }
    
    func discardChanges() {
        self.operationHub?.reset()
    }
    
    // MARK: Operation

    open subscript(key: String) -> LCValueConvertible? {
        get {
            return self.get(key)
        }
        set {
            do {
                try self.set(key, value: newValue)
            } catch {
                Logger.shared.error(error)
            }
        }
    }

    open subscript(dynamicMember key: String) -> LCValueConvertible? {
        get {
            return self[key]
        }
        set {
            self[key] = newValue
        }
    }

    /**
     Get value for key.

     - parameter key: The key for which to get the value.

     - returns: The value for key.
     */
    open func get(_ key: String) -> LCValueConvertible? {
        return ObjectProfiler.shared.propertyValue(self, key)
            ?? self.propertyTable[key]
    }

    /**
     Set value for key.

     This method allows you to set a value of a Swift built-in type which confirms LCValueConvertible.

     - parameter key:   The key for which to set the value.
     - parameter value: The new value.
     */
    open func set(_ key: String, value: LCValueConvertible?) throws {
        if let value = value?.lcValue {
            try self.addOperation(.set, key, value)
        } else {
            try self.addOperation(.delete, key)
        }
    }

    /**
     Unset value for key.

     - parameter key: The key for which to unset.
     */
    open func unset(_ key: String) throws {
        try self.addOperation(.delete, key)
    }

    /**
     Increase a number by amount.

     - parameter key:    The key of number which you want to increase.
     - parameter amount: The amount to increase. If no amount is specified, 1 is used by default. 
     */
    open func increase(_ key: String, by: LCNumberConvertible = 1) throws {
        try self.addOperation(.increment, key, by.lcNumber)
    }

    /**
     Append an element into an array.

     - parameter key:     The key of array into which you want to append the element.
     - parameter element: The element to append.
     */
    open func append(_ key: String, element: LCValueConvertible) throws {
        try self.addOperation(.add, key, LCArray([element.lcValue]))
    }

    /**
     Append one or more elements into an array.

     - parameter key:      The key of array into which you want to append the elements.
     - parameter elements: The array of elements to append.
     */
    open func append(_ key: String, elements: LCArrayConvertible) throws {
        try self.addOperation(.add, key, elements.lcArray)
    }

    /**
     Append an element into an array with unique option.

     - parameter key:     The key of array into which you want to append the element.
     - parameter element: The element to append.
     - parameter unique:  Whether append element by unique or not.
                          If true, element will not be appended if it had already existed in array;
                          otherwise, element will always be appended.
     */
    open func append(_ key: String, element: LCValueConvertible, unique: Bool) throws {
        try self.addOperation(unique ? .addUnique : .add, key, LCArray([element.lcValue]))
    }

    /**
     Append one or more elements into an array with unique option.

     - seealso: `append(key: String, element: LCValue, unique: Bool)`

     - parameter key:      The key of array into which you want to append the element.
     - parameter elements: The array of elements to append.
     - parameter unique:   Whether append element by unique or not.
     */
    open func append(_ key: String, elements: LCArrayConvertible, unique: Bool) throws {
        try self.addOperation(unique ? .addUnique : .add, key, elements.lcArray)
    }

    /**
     Remove an element from an array.

     - parameter key:     The key of array from which you want to remove the element.
     - parameter element: The element to remove.
     */
    open func remove(_ key: String, element: LCValueConvertible) throws {
        try self.addOperation(.remove, key, LCArray([element.lcValue]))
    }

    /**
     Remove one or more elements from an array.

     - parameter key:      The key of array from which you want to remove the element.
     - parameter elements: The array of elements to remove.
     */
    open func remove(_ key: String, elements: LCArrayConvertible) throws {
        try self.addOperation(.remove, key, elements.lcArray)
    }

    /**
     Get relation object for key.

     - parameter key: The key where relationship based on.

     - returns: The relation for key.
     */
    open func relationForKey(_ key: String) -> LCRelation {
        return LCRelation(application: self.application, key: key, parent: self)
    }

    /**
     Insert an object into a relation.

     - parameter key:    The key of relation into which you want to insert the object.
     - parameter object: The object to insert.
     */
    open func insertRelation(_ key: String, object: LCObject) throws {
        try self.addOperation(.addRelation, key, LCArray([object]))
    }

    /**
     Remove an object from a relation.

     - parameter key:    The key of relation from which you want to remove the object.
     - parameter object: The object to remove.
     */
    open func removeRelation(_ key: String, object: LCObject) throws {
        try self.addOperation(.removeRelation, key, LCArray([object]))
    }
    
    // MARK: Save
    
    /// Options for saving action.
    public enum SaveOption {
        /// Saved success result will return all data of this object.
        case fetchWhenSave
        /// Only the object match the query condition can be saved.
        case query(LCQuery)
    }
    
    /// Save a batch of objects in one request synchronously.
    /// - Parameters:
    ///   - objects: An array of objects to be saved.
    ///   - options: See `LCObject.SaveOption`, default is `[]`, it will be applyed to all objects.
    /// - Returns: `LCBooleanResult`.
    public class func save(
        _ objects: [LCObject],
        options: [LCObject.SaveOption] = [])
        -> LCBooleanResult
    {
        return self.validateApplication(objects: objects)
            ?? expect { fulfill in
                self.save(
                    objects,
                    options: options,
                    completionInBackground: fulfill)
        }
    }
    
    /// Save a batch of objects in one request asynchronously.
    /// - Parameters:
    ///   - objects: An array of objects to be saved.
    ///   - options: See `LCObject.SaveOption`, default is `[]`, it will be applyed to all objects.
    ///   - completionQueue: The queue where the `completion` be called, default is `DispatchQueue.main`.
    ///   - completion: The callback of result.
    /// - Returns: `LCRequest`.
    @discardableResult
    public class func save(
        _ objects: [LCObject],
        options: [LCObject.SaveOption] = [],
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.validateApplication(
            objects: objects,
            completionQueue: completionQueue,
            completion: completion)
            ?? self.save(
                objects,
                options: options,
                completionInBackground: { result in
                    completionQueue.async {
                        completion(result)
                    }
            })
    }
    
    @discardableResult
    static func save(
        _ objects: [LCObject],
        options: [SaveOption],
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        var parameters: [String: Any] = [:]
        for option in options {
            switch option {
            case .fetchWhenSave:
                parameters["fetchWhenSave"] = true
            case .query(let query):
                if let application = objects.first?.application {
                    guard application === query.application else {
                        return application.httpClient.request(
                            error: LCError(
                                code: .inconsistency,
                                reason: "`application` !== `query.application`, they should be the same instance."),
                            completionHandler: completion)
                    }
                }
                if let lconWhere = query.lconWhere {
                    parameters["where"] = lconWhere
                }
            }
        }
        return ObjectUpdater.save(
            objects,
            parameters: (parameters.isEmpty ? nil : parameters),
            completionInBackground: completion)
    }
    
    /// Save object and its all descendant objects synchronously.
    /// - Parameter options: See `LCObject.SaveOption`, default is `[]`.
    /// - Returns: `LCBooleanResult`.
    public func save(
        options: [LCObject.SaveOption] = [])
        -> LCBooleanResult
    {
        return type(of: self).save(
            [self],
            options: options)
    }
    
    /// Save object and its all descendant objects asynchronously.
    /// - Parameters:
    ///   - options: See `LCObject.SaveOption`, default is `[]`.
    ///   - completionQueue: The queue where the `completion` be called, default is `DispatchQueue.main`.
    ///   - completion: The callback of result.
    /// - Returns: `LCRequest`.
    @discardableResult
    public func save(
        options: [LCObject.SaveOption] = [],
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return type(of: self).save(
            [self],
            options: options,
            completionQueue: completionQueue,
            completion: completion)
    }
    
    // MARK: Delete
    
    /// Delete a batch of objects in one request synchronously.
    /// - Parameter objects: An array of objects to be deleted.
    /// - Returns: `LCBooleanResult`.
    public static func delete(
        _ objects: [LCObject])
        -> LCBooleanResult
    {
        return self.validateApplication(objects: objects)
            ?? expect { fulfill in
                self.delete(
                    objects,
                    completionInBackground: fulfill)
        }
    }
    
    /// Delete a batch of objects in one request asynchronously.
    /// - Parameters:
    ///   - objects: An array of objects to be deleted.
    ///   - completionQueue: The queue where the `completion` be called, default is `DispatchQueue.main`.
    ///   - completion: The callback of result.
    /// - Returns: `LCRequest`.
    @discardableResult
    public static func delete(
        _ objects: [LCObject],
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.validateApplication(
            objects: objects,
            completionQueue: completionQueue,
            completion: completion)
            ?? self.delete(
                objects,
                completionInBackground: { result in
                    completionQueue.async {
                        completion(result)
                    }
            })
    }
    
    @discardableResult
    private static func delete(
        _ objects: [LCObject],
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return ObjectUpdater.delete(
            objects,
            completionInBackground: completion)
    }
    
    /// Delete current object synchronously.
    public func delete() -> LCBooleanResult {
        return type(of: self).delete([self])
    }
    
    /// Delete current object asynchronously.
    /// - Parameters:
    ///   - completionQueue: The queue where the `completion` be called, default is `DispatchQueue.main`.
    ///   - completion: The callback of result.
    /// - Returns: `LCRequest`.
    @discardableResult
    public func delete(
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return type(of: self).delete(
            [self],
            completionQueue: completionQueue,
            completion: completion)
    }
    
    // MARK: Fetch
    
    /// Fetch a batch of objects in one request synchronously.
    /// - Parameters:
    ///   - objects: An array of objects to be fetched.
    ///   - keys: Specify only return the values of the `keys`, or not return the values of the `keys` when add a "-" prefix to the key.
    /// - Returns: `LCBooleanResult`.
    public static func fetch(
        _ objects: [LCObject],
        keys: [String]? = nil)
        -> LCBooleanResult
    {
        return self.validateApplication(objects: objects)
            ?? expect { fulfill in
                self.fetch(
                    objects,
                    keys: keys,
                    completionInBackground: fulfill)
        }
    }
    
    /// Fetch a batch of objects in one request asynchronously.
    /// - Parameters:
    ///   - objects: An array of objects to be fetched.
    ///   - keys: Specify only return the values of the `keys`, or not return the values of the `keys` when add a "-" prefix to the key.
    ///   - completionQueue: The queue where the `completion` be called, default is `DispatchQueue.main`.
    ///   - completion: The callback of result.
    /// - Returns: `LCRequest`.
    @discardableResult
    public static func fetch(
        _ objects: [LCObject],
        keys: [String]? = nil,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return self.validateApplication(
            objects: objects,
            completionQueue: completionQueue,
            completion: completion)
            ?? self.fetch(
                objects,
                keys: keys,
                completionInBackground: { result in
                    completionQueue.async {
                        completion(result)
                    }
            })
    }
    
    @discardableResult
    private static func fetch(
        _ objects: [LCObject],
        keys: [String]?,
        completionInBackground completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return ObjectUpdater.fetch(
            objects,
            keys: keys,
            completionInBackground: completion)
    }
    
    /// Fetch object from server synchronously.
    /// - Parameter keys: Specify only return the values of the `keys`, or not return the values of the `keys` when add a "-" prefix to the key.
    /// - Returns: `LCBooleanResult`.
    public func fetch(
        keys: [String]? = nil)
        -> LCBooleanResult
    {
        return type(of: self).fetch(
            [self],
            keys: keys)
    }
    
    /// Fetch object from server asynchronously.
    /// - Parameters:
    ///   - keys: Specify only return the values of the `keys`, or not return the values of the `keys` when add a "-" prefix to the key.
    ///   - completionQueue: The queue where the `completion` be called, default is `DispatchQueue.main`.
    ///   - completion: The callback of result.
    /// - Returns: `LCRequest`.
    @discardableResult
    public func fetch(
        keys: [String]? = nil,
        completionQueue: DispatchQueue = .main,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest
    {
        return type(of: self).fetch(
            [self],
            keys: keys,
            completionQueue: completionQueue,
            completion: completion)
    }
    
    // MARK: Misc
    
    func preferredBatchRequest(
        method: HTTPClient.Method,
        path: String,
        internalId: String)
        throws -> [String: Any]?
    {
        return nil
    }
    
    func validateBeforeSaving() throws {
        /* Nop */
    }
    
    func objectDidSave() {
        /* Nop */
    }
    
    private static func validateApplication(
        objects: [LCObject])
        -> LCBooleanResult?
    {
        let sharedApplication = objects.first?.application ?? .default
        for object in objects {
            guard object.application === sharedApplication else {
                return .failure(
                    error: LCError(
                        code: .inconsistency,
                        reason: "the applications of the `objects` should be the same instance."))
            }
        }
        return nil
    }
    
    private static func validateApplication(
        objects: [LCObject],
        completionQueue: DispatchQueue,
        completion: @escaping (LCBooleanResult) -> Void)
        -> LCRequest?
    {
        let sharedApplication = objects.first?.application ?? .default
        for object in objects {
            guard object.application === sharedApplication else {
                return sharedApplication.httpClient
                    .request(
                        error: LCError(
                            code: .inconsistency,
                            reason: "the applications of the `objects` should be the same instance."),
                        completionQueue: completionQueue,
                        completionHandler: completion)
            }
        }
        return nil
    }
}
