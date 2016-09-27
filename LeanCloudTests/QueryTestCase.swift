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
    object.dateField     = LCDate(Date(timeIntervalSince1970: 1024))
    object.geoPointField = LCGeoPoint(latitude: 45, longitude: -45)
    object.objectField   = sharedChild
    object.nullField     = LCNull()

    object.insertRelation("relationField", object: sharedFriend)

    XCTAssertTrue(object.save().isSuccess)

    return object
}()

let sharedElement: TestObject = {
    let object = TestObject()
    XCTAssertTrue(object.save().isSuccess)
    return object
}()

let sharedFriend: TestObject = {
    let object = TestObject()
    object.stringField = "friend"
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

    func execute<T: LCObject>(_ query: LCQuery) -> (isSuccess: Bool, objects: [T]) {
        let result: LCQueryResult<T> = query.find()

        switch result {
        case .success(let objects):
            return (true, objects)
        case .failure:
            return (false, [])
        }
    }

    func objectQuery() -> LCQuery {
        return LCQuery(className: TestObject.objectClassName())
    }

    func testIncluded() {
        let object = sharedObject

        XCTAssertTrue(object.save().isSuccess)

        let query = objectQuery()
        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("objectField", .included)

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

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("stringField", .selected)
        query.whereKey("booleanField", .selected)

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

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("stringField", .existed)

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testNotExisted() {
        let query = objectQuery()
        query.whereKey("objectId", .notExisted)

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && objects.isEmpty)
    }

    func testEqualTo() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("dateField", .equalTo(Date(timeIntervalSince1970: 1024)))
        query.whereKey("nullField", .equalTo(NSNull()))

        /* Tip: You can use EqualTo to compare an value against elements in an array field.
           If the given value is equal to any element in the array referenced by key, the comparation will be successful. */
        query.whereKey("arrayField", .equalTo(sharedElement))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testNotEqualTo() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("numberField", .notEqualTo(42))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && objects.isEmpty)
    }

    func testLessThan() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("numberField", .lessThan(42))

        let (isSuccess1, objects1) = execute(query)
        XCTAssertTrue(isSuccess1 && objects1.isEmpty)

        query.whereKey("numberField", .lessThan(43))
        query.whereKey("dateField", .lessThan(Date(timeIntervalSince1970: 1025)))

        let (isSuccess2, objects2) = execute(query)
        XCTAssertTrue(isSuccess2 && !objects2.isEmpty)
    }

    func testLessThanOrEqualTo() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("numberField", .lessThanOrEqualTo(42))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testGreaterThan() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("numberField", .greaterThan(41.9))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testGreaterThanOrEqualTo() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("dateField", .greaterThanOrEqualTo(Date(timeIntervalSince1970: 1023.9)))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testContainedIn() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))

        /* Tip: You can use ContainedIn to compare an array of values against a non-array field.
           If any value in given array is equal to the value referenced by key, the comparation will be successful. */
        query.whereKey("dateField", .containedIn([Date(timeIntervalSince1970: 1024)]))

        /* Tip: Also, you can apply the constraint to array field. */
        query.whereKey("arrayField", .containedIn([42, "bar"]))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testNotContainedIn() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))

        /* Tip: Like ContainedIn, you can apply NotContainedIn to non-array field. */
        query.whereKey("numberField", .notContainedIn([42]))

        /* Tip: Also, you can apply the constraint to array field. */
        query.whereKey("arrayField", .notContainedIn([42, "bar"]))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && objects.isEmpty)
    }

    func testContainedAllIn() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))

        /* Tip: Like ContainedIn, you can apply ContainedAllIn to non-array field. */
        query.whereKey("numberField", .containedAllIn([42]))

        /* Tip: Also, you can apply the constraint to array field. */
        query.whereKey("arrayField", .containedAllIn([42, "bar", sharedElement]))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testEqualToSize() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("arrayField", .equalToSize(3))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testLocatedNear() {
        let query = objectQuery()

        query.whereKey("geoPointField", .locatedNear(LCGeoPoint(latitude: 45, longitude: -45), minimal: nil, maximal: nil))
        query.limit = 1

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testLocatedNearWithRange() {
        let query = objectQuery()

        /* Tip: At the equator, one degree of longitude and latitude is approximately equal to about 111 kilometers, or 70 miles. */

        let minimal = LCGeoPoint.Distance(value: 0, unit: .Kilometer)
        let maximal = LCGeoPoint.Distance(value: 150, unit: .Kilometer)

        query.whereKey("geoPointField", .locatedNear(LCGeoPoint(latitude: 44, longitude: -45), minimal: minimal, maximal: maximal))
        query.limit = 1

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testLocatedWithin() {
        let query = objectQuery()

        let southwest = LCGeoPoint(latitude: 44, longitude: -46)
        let northeast = LCGeoPoint(latitude: 46, longitude: -44)

        query.whereKey("geoPointField", .locatedWithin(southwest: southwest, northeast: northeast))
        query.limit = 1

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testMatchedQuery() {
        let object   = sharedObject
        let child    = sharedChild
        let query    = objectQuery()
        let subQuery = objectQuery()

        subQuery.whereKey("objectId", .equalTo(child.objectId!))
        subQuery.whereKey("stringField", .equalTo("child"))

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("objectField", .matchedQuery(subQuery))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testNotMatchedQuery() {
        let object   = sharedObject
        let query    = objectQuery()
        let subQuery = objectQuery()

        subQuery.whereKey("objectId", .equalTo(sharedChild.objectId!))

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("objectField", .notMatchedQuery(subQuery))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && objects.isEmpty)
    }

    func testMatchedQueryAndKey() {
        let object   = sharedObject
        let query    = objectQuery()
        let subQuery = objectQuery()

        subQuery.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("objectId", .matchedQueryAndKey(query: subQuery, key: "objectId"))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
        XCTAssertEqual(objects.first, object)
    }

    func testNotMatchedQueryAndKey() {
        let object   = sharedObject
        let query    = objectQuery()
        let subQuery = objectQuery()

        subQuery.whereKey("objectId", .notEqualTo(object.objectId!))
        query.whereKey("objectId", .notMatchedQueryAndKey(query: subQuery, key: "objectId"))

        let (isSuccess, objects) = execute(query)

        /* Tip: Like query, the maximum number of subquery is 1000.
           If number of records exceeds 1000, NotMatchedQueryAndKey will return the objects that are not existed in subquery.
           So, we cannot use equality assertion here. */
        XCTAssertTrue(isSuccess && !objects.isEmpty)
    }

    func testMatchedPattern() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("stringField", .matchedRegularExpression("^foo$", option: nil))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
        XCTAssertEqual(objects.first, object)
    }

    func testMatchedSubstring() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("stringField", .matchedSubstring("foo"))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
        XCTAssertEqual(objects.first, object)
    }

    func testPrefixedBy() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("stringField", .prefixedBy("f"))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
        XCTAssertEqual(objects.first, object)
    }

    func testSuffixedBy() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.whereKey("stringField", .suffixedBy("o"))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
        XCTAssertEqual(objects.first, object)
    }

    func testRelatedTo() {
        let object = sharedObject
        let friend = sharedFriend
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(friend.objectId!))
        query.whereKey("relationField", .relatedTo(object))

        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && !objects.isEmpty)
        XCTAssertEqual(objects.first, friend)
    }

    func testAscending() {
        let object = sharedObject
        let child  = sharedChild
        let query  = objectQuery()

        query.whereKey("objectId", .containedIn([object.objectId!, child.objectId!]))
        query.whereKey("objectId", .ascending)

        let (isSuccess, objects) = execute(query)

        XCTAssertTrue(isSuccess && !objects.isEmpty)

        let objectId1 = objects[0].objectId!
        let objectId2 = objects.last?.objectId!

        XCTAssertTrue((objectId1.value as NSString).compare(objectId2!.value) == .orderedAscending)
    }

    func testDescending() {
        let object = sharedObject
        let child  = sharedChild
        let query  = objectQuery()

        query.whereKey("objectId", .containedIn([object.objectId!, child.objectId!]))
        query.whereKey("objectId", .descending)

        let (isSuccess, objects) = execute(query)

        XCTAssertTrue(isSuccess && !objects.isEmpty)

        let objectId1 = objects[0].objectId!
        let objectId2 = objects.last?.objectId!

        XCTAssertTrue((objectId1.value as NSString).compare(objectId2!.value) == .orderedDescending)
    }

    func testLogicAnd() {
        let object  = sharedObject
        let child   = sharedChild
        let query1  = objectQuery()
        let query2  = objectQuery()

        query1.whereKey("objectId", .equalTo(object.objectId!))
        query2.whereKey("objectId", .equalTo(child.objectId!))

        let query = query1.and(query2)
        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && objects.isEmpty)
    }

    func testLogicOr() {
        let object  = sharedObject
        let child   = sharedChild
        let query1  = objectQuery()
        let query2  = objectQuery()

        query1.whereKey("objectId", .equalTo(object.objectId!))
        query2.whereKey("objectId", .equalTo(child.objectId!))

        let query = query1.or(query2)
        let (isSuccess, objects) = execute(query)
        XCTAssertTrue(isSuccess && objects.count == 2)
    }

    func testCount() {
        let object = sharedObject
        let child  = sharedChild
        let query  = objectQuery()

        query.whereKey("objectId", .containedIn([object.objectId!, child.objectId!]))

        let count = query.count().intValue
        XCTAssertEqual(count, 2)
    }

    func testGetFirst() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))

        let result = query.getFirst()
        XCTAssertNil(query.limit)
        XCTAssertEqual(result.object, object)
    }

    func testGetObject() {
        let object = sharedObject
        let query  = objectQuery()

        let result = query.get(object.objectId!.value)
        XCTAssertEqual(result.object, object)
    }

    func testCopyQuery() {
        let query = objectQuery()
        query.limit = 42
        let queryCopy = query.copy() as! LCQuery

        XCTAssertEqual(queryCopy.limit, 42)
        XCTAssertNotEqual(queryCopy, query)

        queryCopy.limit = 43
        XCTAssertEqual(query.limit, 42)
    }

    func testArchiveQuery() {
        let query = objectQuery()
        let matchedQuery = objectQuery()

        query.whereKey("stringField", .matchedQuery(matchedQuery))

        let queryCopy = query.copy() as! LCQuery
        let queryArchivement = NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: query)) as! LCQuery

        matchedQuery.limit = 42

        let keyPath = "where.stringField.$inQuery.limit"

        XCTAssertEqual((queryCopy.LCONValue as NSDictionary).value(forKeyPath: keyPath) as? Int, 42)
        XCTAssertNil((queryArchivement.LCONValue as NSDictionary).value(forKeyPath: keyPath))
    }

    func testSkip() {
        let object = sharedObject
        let query  = objectQuery()

        query.whereKey("objectId", .equalTo(object.objectId!))
        query.skip = 1

        let objects = query.find().objects ?? []
        XCTAssertTrue(objects.isEmpty)
    }

}
