//
//  LCBridge.h
//  LeanCloud
//
//  Created by Tang Tianyong on 5/16/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LCBridge : NSObject

+ (void)executeBlock:(void(^)(void))block cleanup:(void(^)(void))cleanup;

@end