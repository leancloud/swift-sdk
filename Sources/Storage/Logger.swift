//
//  Logger.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 10/19/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

class Logger {
    static let shared = Logger()

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()

        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'.'HH':'mm':'ss'.'SSS"

        return dateFormatter
    }()

    private func log<T>(
        _ level: LCApplication.LogLevel,
        _ value: @autoclosure () -> T,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line)
    {
        guard LCApplication.default.logLevel >= level else {
            return
        }

        let date = Logger.dateFormatter.string(from: Date())
        let file = NSURL(string: file)?.lastPathComponent ?? "Unknown"

        print("[LeanCloud \(date) \(file) #\(line) \(function)]:", value())
    }

    func debug<T>(
        _ value: @autoclosure () -> T,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line)
    {
        log(.debug, value, file, function, line)
    }

    func error<T>(
        _ value: @autoclosure () -> T,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line)
    {
        log(.error, value, file, function, line)
    }
}
