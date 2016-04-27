//
//  Semaphore.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 4/27/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

/**
 A semaphore wrapper with some extensions.

 You can use Semaphore to pass value from `signal` to `wait`.
 */
class Semaphore<T: Any> {
    private var value: T?
    private let semaphore = dispatch_semaphore_create(0)
    private var deferClosure: (() -> Void)?

    init() {}

    init(_ deferClosure: (() -> Void)?) {
        self.deferClosure = deferClosure
    }

    func signal(value: T? = nil) {
        self.value = value
        dispatch_semaphore_signal(semaphore)
    }

    func wait() -> T? {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        defer { deferClosure?() }
        return value
    }
}