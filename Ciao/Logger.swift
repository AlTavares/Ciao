//
//  Logger.swift
//  Ciao
//
//  Created by Alexandre Tavares on 11/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

import Foundation

enum Level: Int {
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

struct Logger {
    static var level = Level.verbose
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

    static func log(_ message: Any...,
                    level: Level,
                    fileName: String = #file,
                    line: Int = #line,
                    column: Int = #column,
                    funcName: String = #function) {

        guard level.rawValue >= self.level.rawValue else { return }
        print("\(date) [\(level.description)][\(sourceFileName(filePath: fileName))]:\(line) \(column) \(funcName) -> \(message)")
    }

    private static func sourceFileName(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        return components.isEmpty ? "" : components.last!
    }
}

extension Logger {
    static func verbose(_ message: Any...) {
        Logger.log(message, level: .verbose)
    }
    static func debug(_ message: Any...) {
        Logger.log(message, level: .debug)
    }
    static func info(_ message: Any...) {
        Logger.log(message, level: .info)
    }
    static func warning(_ message: Any...) {
        Logger.log(message, level: .warning)
    }
    static func error(_ message: Any...) {
        Logger.log(message, level: .error)
    }
}

