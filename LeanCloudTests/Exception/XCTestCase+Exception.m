//
//  XCTestCase+Exception.m
//  LeanCloud
//
//  Created by Tang Tianyong on 5/3/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

#import "XCTestCase+Exception.h"

@implementation XCTestCase (Exceptions)

- (void)XCTAssertThrowsException:(void (^)(void))block {
    XCTAssertThrows(block());
}

@end