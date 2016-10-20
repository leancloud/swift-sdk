//
//  Logger.swift
//  LeanCloud
//
//  Created by Tang Tianyong on 10/19/16.
//  Copyright © 2016 LeanCloud. All rights reserved.
//

import Foundation

class Logger {
    static let defaultLogger = Logger()

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()

        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'.'HH':'mm':'ss'.'SSS"

        return dateFormatter
    }()

    public func log<T>(
        _ value: @autoclosure () -> T,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line)
    {
        let date = Logger.dateFormatter.string(from: Date())
        let file = NSURL(string: file)?.lastPathComponent ?? "Unknown"

        print("[LeanCloud \(date) \(file) #\(line) \(function)]:", value())
    }
}
