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
    
    private init() {}

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()

        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd' 'HH':'mm':'ss'.'SSS"

        return dateFormatter
    }()

    private func log<T>(
        _ level: LCApplication.LogLevel,
        _ value: () -> T,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line)
    {
        guard LCApplication.logLevel >= level else {
            return
        }

        let date = Logger.dateFormatter.string(from: Date())
        let file = NSURL(string: file)?.lastPathComponent ?? "Unknown"
        
        var info = "[\(level)][LeanCloud][\(date)][\(file)][#\(line)][\(function)]:"
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
        switch level {
        case .error:
            info = "[❤️]" + info
        case .debug:
            info = "[💙]" + info
        case .verbose:
            info = "[💛]" + info
        default:
            break
        }
        #endif

        print(info, value())
    }

    func debug<T>(
        _ value: @autoclosure () -> T,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line)
    {
        log(.debug, value, file, function, line)
    }
    
    func debug<T>(
        closure: () -> T,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line)
    {
        log(.debug, closure, file, function, line)
    }

    func error<T>(
        _ value: @autoclosure () -> T,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line)
    {
        log(.error, value, file, function, line)
    }
    
    func error<T>(
        closure: () -> T,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line)
    {
        log(.error, closure, file, function, line)
    }

    func verbose<T>(
        _ value: @autoclosure () -> T,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line)
    {
        log(.verbose, value, file, function, line)
    }
    
    func verbose<T>(
        closure: () -> T,
        _ file: String = #file,
        _ function: String = #function,
        _ line: Int = #line)
    {
        log(.verbose, closure, file, function, line)
    }
    
}
