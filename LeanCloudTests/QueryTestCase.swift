//
//  QueryTestCase.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/20/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import XCTest
@testable import LeanCloud

let sharedObject: TestObject = {
    let object = TestObject()

    object.numberField   = 42
    object.booleanField  = true
    object.stringField   = "foo"
    object.arrayField    = [LCNumber(42), LCString("bar"), sharedElement]
    object.dateField     = LCDate(NSDate(timeIntervalSince1970: 1024))
    object.geoPointField = LCGeoPoint(latitude: 45, longitude: -45)
    object.objectField   = sharedChild
    object.nullField     = LCNull.null

    object.insertRelation("relationField", object: sharedRelation)

    XCTAssertTrue(object.save().isSuccess)

    return object
}()

let sharedElement: TestObject = {
    let object = TestObject()
    XCTAssertTrue(object.save().isSuccess)
    return object
}()

let sharedRelation: TestObject = {
    let object = TestObject()
    XCTAssertTrue(object.save().isSuccess)
    return object
}()

let sharedChild: TestObject = {
    let object = TestObject()
    object.stringField = "child"
    XCTAssertTrue(object.save().isSuccess)
    return object
}()

class QueryTestCase: BaseTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func execute<T: LCObject>(query: Query) -> (isSuccess: Bool, objects: [T]) {
        let result: QueryResult<T> = query.find()

        switch result {
        case let .Success(objects):
            return (true, objects)
        case .Failure:
            return (false, [])
        }
    }

    func objectQuery() -> Query {
        return Query(className: TestObject.objectClassName())
    }

    func testIncluded() {
        let object = sharedObject

        XCTAssertTrue(object.save().isSuccess)

        let query = objectQuery()
        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("objectField", .Included)

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)

        if let child = (objects.first as? TestObject)?.objectField as? TestObject {
            XCTAssertEqual(child.stringField, "child")
        } else {
            XCTFail()
        }
    }

    func testSelected() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("stringField", .Selected)
        query.whereKey("booleanField", .Selected)

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)

        let shadow = objects.first as! TestObject

        XCTAssertEqual(shadow.stringField, "foo")
        XCTAssertEqual(shadow.booleanField, true)
        XCTAssertNil(shadow.numberField)
    }

    func testExisted() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("stringField", .Existed)

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testNotExisted() {
        let query = objectQuery()
        query.whereKey("objectId", .NotExisted)

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && objects.isEmpty)
    }

    func testEqualTo() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("dateField", .EqualTo(value: LCDate(NSDate(timeIntervalSince1970: 1024))))
        query.whereKey("nullField", .EqualTo(value: LCNull.null))

        /* Tip: You can use EqualTo to compare an value against elements in an array field.
           If the given value is equal to any element in the array referenced by key, the comparation will be successful. */
        query.whereKey("arrayField", .EqualTo(value: sharedElement))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testNotEqualTo() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("numberField", .NotEqualTo(value: LCNumber(42)))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && objects.isEmpty)
    }

    func testLessThan() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("numberField", .LessThan(value: LCNumber(42)))

        let (isSuccess1, objects1) = execute(query)
        XCTAssertTrue(isSuccess1 && objects1.isEmpty)

        query.whereKey("numberField", .LessThan(value: LCNumber(43)))
        query.whereKey("dateField", .LessThan(value: LCDate(NSDate(timeIntervalSince1970: 1025))))

        let (isSuccess2, objects2) = execute(query)
        XCTAssertTrue(isSuccess2 && !objects2.isEmpty)
    }

    func testLessThanOrEqualTo() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("numberField", .LessThanOrEqualTo(value: LCNumber(42)))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testGreaterThan() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("numberField", .GreaterThan(value: LCNumber(41.9)))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testGreaterThanOrEqualTo() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("dateField", .GreaterThanOrEqualTo(value: LCDate(NSDate(timeIntervalSince1970: 1023.9))))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testContainedIn() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))

        /* Tip: You can use ContainedIn to compare an array of values against a non-array field.
           If any value in given array is equal to the value referenced by key, the comparation will be successful. */
        query.whereKey("dateField", .ContainedIn(array: [LCDate(NSDate(timeIntervalSince1970: 1024))]))

        /* Tip: Also, you can apply the constraint to array field. */
        query.whereKey("arrayField", .ContainedIn(array: [LCNumber(42), LCString("bar")]))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testNotContainedIn() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))

        /* Tip: Like ContainedIn, you can apply NotContainedIn to non-array field. */
        query.whereKey("numberField", .NotContainedIn(array: [LCNumber(42)]))

        /* Tip: Also, you can apply the constraint to array field. */
        query.whereKey("arrayField", .NotContainedIn(array: [LCNumber(42), LCString("bar")]))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && objects.isEmpty)
    }

    func testContainedAllIn() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))

        /* Tip: Like ContainedIn, you can apply ContainedAllIn to non-array field. */
        query.whereKey("numberField", .ContainedAllIn(array: [LCNumber(42)]))

        /* Tip: Also, you can apply the constraint to array field. */
        query.whereKey("arrayField", .ContainedAllIn(array: [LCNumber(42), LCString("bar"), sharedElement]))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testEqualToSize() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("arrayField", .EqualToSize(size: 3))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testNearbyPoint() {
        let query = objectQuery()

        query.whereKey("geoPointField", .NearbyPoint(point: LCGeoPoint(latitude: 45, longitude: -45)))
        query.limit = 1

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testNearbyPointWithRange() {
        let query = objectQuery()

        /* Tip: At the equator, one degree of longitude and latitude is approximately equal to about 111 kilometers, or 70 miles. */

        let from = LCGeoPoint.Distance(value: 0, unit: .Kilometer)
        let to   = LCGeoPoint.Distance(value: 150, unit: .Kilometer)

        query.whereKey("geoPointField", .NearbyPointWithRange(point: LCGeoPoint(latitude: 44, longitude: -45), from: from, to: to))
        query.limit = 1

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testNearbyPointWithRectangle() {
        let query = objectQuery()

        let southwest = LCGeoPoint(latitude: 44, longitude: -46)
        let northeast = LCGeoPoint(latitude: 46, longitude: -44)

        query.whereKey("geoPointField", .NearbyPointWithRectangle(southwest: southwest, northeast: northeast))
        query.limit = 1

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testMatchedQuery() {
        let object   = sharedObject
        let child    = sharedChild
        let query    = objectQuery()
        let subQuery = objectQuery()

        subQuery.whereKey("objectId", .EqualTo(value: child.objectId!))
        subQuery.whereKey("stringField", .EqualTo(value: LCString("child")))

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("objectField", .MatchedQuery(query: subQuery))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testNotMatchedQuery() {
        let object   = sharedObject
        let query    = objectQuery()
        let subQuery = objectQuery()

        subQuery.whereKey("objectId", .EqualTo(value: sharedChild.objectId!))

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("objectField", .NotMatchedQuery(query: subQuery))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && objects.isEmpty)
    }

    func testMatchedQueryAndKey() {
        let object   = sharedObject
        let query    = objectQuery()
        let subQuery = objectQuery()

        subQuery.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("objectId", .MatchedQueryAndKey(query: subQuery, key: "objectId"))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
        XCTAssertEqual(objects.first, object)
    }

    func testNotMatchedQueryAndKey() {
        let object   = sharedObject
        let query    = objectQuery()
        let subQuery = objectQuery()

        subQuery.whereKey("objectId", .NotEqualTo(value: object.objectId!))
        query.whereKey("objectId", .NotMatchedQueryAndKey(query: subQuery, key: "objectId"))

        let (isSuccess, objects) = execute(query)

        /* Tip: Like query, the maximum number of subquery is 1000.
           If number of records exceeds 1000, NotMatchedQueryAndKey will return the objects that are not existed in subquery.
           So, we cannot use equality assertion here. */
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testMatchedPattern() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("stringField", .MatchedPattern(pattern: "^foo$", option: nil))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
        XCTAssertEqual(objects.first, object)
    }

    func testMatchedSubstring() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("stringField", .MatchedSubstring(string: "foo"))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
        XCTAssertEqual(objects.first, object)
    }

    func testPrefixedBy() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("stringField", .PrefixedBy(string: "f"))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
        XCTAssertEqual(objects.first, object)
    }

    func testSuffixedBy() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .EqualTo(value: object.objectId!))
        query.whereKey("stringField", .SuffixedBy(string: "o"))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
        XCTAssertEqual(objects.first, object)
    }

    func testRelatedTo() {
        let object   = sharedObject
        let relation = sharedRelation
        let query    = objectQuery()

        query.whereKey("objectId", .EqualTo(value: relation.objectId!))
        query.whereKey("relationField", .RelatedTo(object: object))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
        XCTAssertEqual(objects.first, relation)
    }

    func testAscending() {
        let object = sharedObject
        let child  = sharedChild
        let query  = objectQuery()

        query.whereKey("objectId", .ContainedIn(array: [object.objectId!, child.objectId!]))
        query.whereKey("objectId", .Ascending)

        let (isSuccess, objects) = execute(query)

        XCTAssertTrue(isSuccess && !objects.isEmpty)

        let objectId1 = objects[0].objectId!
        let objectId2 = objects.last?.objectId!

        XCTAssertTrue((objectId1.value as NSString).compare(objectId2!.value) == .OrderedAscending)
    }

    func testDescending() {
        let object = sharedObject
        let child  = sharedChild
        let query  = objectQuery()

        query.whereKey("objectId", .ContainedIn(array: [object.objectId!, child.objectId!]))
        query.whereKey("objectId", .Descending)

        let (isSuccess, objects) = execute(query)

        XCTAssertTrue(isSuccess && !objects.isEmpty)

        let objectId1 = objects[0].objectId!
        let objectId2 = objects.last?.objectId!

        XCTAssertTrue((objectId1.value as NSString).compare(objectId2!.value) == .OrderedDescending)
    }

    func testLogicAnd() {
        let object = sharedObject
        let child  = sharedChild
        let query1  = objectQuery()
        let query2  = objectQuery()

        query1.whereKey("objectId", .EqualTo(value: object.objectId!))
        query2.whereKey("objectId", .EqualTo(value: child.objectId!))

        let query = query1 && query2
        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && objects.isEmpty)
    }

    func testLogicOr() {
        let object = sharedObject
        let child  = sharedChild
        let query1  = objectQuery()
        let query2  = objectQuery()

        query1.whereKey("objectId", .EqualTo(value: object.objectId!))
        query2.whereKey("objectId", .EqualTo(value: child.objectId!))

        let query = query1 || query2
        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && objects.count == 2)
    }

    func testCount() {
        let object = sharedObject
        let child  = sharedChild
        let query  = objectQuery()

        query.whereKey("objectId", .ContainedIn(array: [object.objectId!, child.objectId!]))

        let result = query.count()

        switch result {
        case let .Success(count):
            XCTAssertEqual(count, 2)
        default:
            XCTFail()
        }
    }

}
