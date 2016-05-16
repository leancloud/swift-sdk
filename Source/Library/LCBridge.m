//
//  LCBridge.m
//  LeanCloud
//
//  Created by Tang Tianyong on 5/16/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

#import "LCBridge.h"

typedef void (^lc_cleanup_block_t)();

void lc_execute_cleanup_block(__strong lc_cleanup_block_t *cleanup) {
    (*cleanup)();
}

@implementation LCBridge

+ (void)executeBlock:(void (^)(void))block cleanup:(void (^)(void))cleanup {
    __strong lc_cleanup_block_t cleanupBlock __attribute__((cleanup(lc_execute_cleanup_block), unused)) = cleanup;
    block();
}

@end