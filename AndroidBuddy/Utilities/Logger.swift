//
//  Logger.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 25/4/2024.
//

import Foundation

enum Logger {
    
    static var verboseLoggingEnabled = false

    private enum Level: String {
        case verbose = "Verbose 🤍"
        case info    = "Info    💙"
        case warning = "Warning 🧡"
        case error   = "Error   💔"
        case fatal   = "Fatal   ☠️"
    }
    
    private static func log(message: String, level: Level, error: Error? = nil) {
        let timestampFormat = Date.FormatStyle()
            .hour()
            .minute()
            .second()
        let timestamp = Date().formatted(timestampFormat)
        
        var output = "[LOGGER | \(timestamp) | \(level.rawValue)] \(message)"
        if let error {
           output = "\(output) | Error: \(error)"
        }
        print(output)
    }
    
    static func verbose(_ message: String) {
        guard verboseLoggingEnabled else { return }
        log(message: message, level: .verbose)
    }
    
    static func info(_ message: String) {
        log(message: message, level: .info)
    }
    
    static func warning(_ message: String) {
        log(message: message, level: .warning)
    }
    
    static func error(_ message: String, error: Error? = nil) {
        log(message: message, level: .error, error: error)
        assert(false)
    }
    
    static func fatal(_ message: String, error: Error? = nil) -> Never {
        log(message: message, level: .fatal, error: error)
        fatalError()
    }
}
