//
//  XCTestCase+Exception.h
//  LeanCloud
//
//  Created by Tang Tianyong on 5/3/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface XCTestCase (Exceptions)

- (void)XCTAssertThrowsException:(void (^)(void))block;

@end