//
//  Logger.swift
//  Ciao
//
//  Created by Alexandre Tavares on 11/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

import Foundation

public enum Level: Int {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4

    var description: String {
        switch self {
        case .verbose:
            return "verbose"
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .warning:
            return "warning"
        case .error:
            return "error"
        }
    }
}

public var LoggerLevel = Level.verbose

struct Logger {
    private static var dateFormat = "yyyy-MM-dd hh:mm:ssSSS"
    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter
    }

    private static var date: String {
        return Logger.dateFormatter.string(from: Date())
    }

    fileprivate static func log(_ message: Any...,
                    level: Level,
                    fileName: String = #file,
                    line: Int = #line,
                    funcName: String = #function) {

        guard level.rawValue >= LoggerLevel.rawValue else { return }
        var msg = message.description.dropFirst(2)
        msg = msg.dropLast(2)
        print("\(date) [\(level.description)][\(sourceFileName(filePath: fileName))]:\(line) \(funcName) -> \(msg)")
    }

    private static func sourceFileName(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        return components.isEmpty ? "" : components.last!
    }
}

extension Logger {
    static func verbose(_ message: Any...,
                        fileName: String = #file,
                        line: Int = #line,
                        funcName: String = #function) {
        Logger.log(message, level: .verbose, fileName: fileName, line: line, funcName: funcName)
    }

    static func debug(_ message: Any...,
                      fileName: String = #file,
                      line: Int = #line,
                      funcName: String = #function) {
        Logger.log(message, level: .debug, fileName: fileName, line: line, funcName: funcName)
    }

    static func info(_ message: Any...,
                     fileName: String = #file,
                     line: Int = #line,
                     funcName: String = #function) {
        Logger.log(message, level: .info, fileName: fileName, line: line, funcName: funcName)
    }

    static func warning(_ message: Any...,
                        fileName: String = #file,
                        line: Int = #line,
                        funcName: String = #function) {
        Logger.log(message, level: .warning, fileName: fileName, line: line, funcName: funcName)
    }

    static func error(_ message: Any...,
                      fileName: String = #file,
                      line: Int = #line,
                      funcName: String = #function) {
        Logger.log(message, level: .error, fileName: fileName, line: line, funcName: funcName)
    }
}
