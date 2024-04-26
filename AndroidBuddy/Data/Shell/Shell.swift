//
//  Shell.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 26/4/2024.
//

import Foundation

// Currently only used for debugging purposes.
// I don't even think it works properly.
enum Shell {
    
    static func doesFileExist(path: URL) async throws -> String {
        let args = ["[", "-e", path.pathForShellCommand, "]", "&&", "echo", "\"True\"", "||", "echo", "\"False\""]
        return try await command(args)
    }
    
    // Used for debugging - I am not sure how tightly written the regex is - Needs proper tests written for it
    @discardableResult
    static func command(argsString: String) async throws -> String {
        let regex = try! NSRegularExpression(pattern: #""[^"]*"|\S+"#) // Split args into array - Parts eclosed in quotes *should* be treated as one arg
        let argsArray = regex.matches(in: argsString, range: NSRange(argsString.startIndex..., in: argsString))
            .map { String(argsString[Range($0.range, in: argsString)!]) }
            .map { arg in
                arg.filter { $0 != "\"" }
            }
        return try await command(argsArray)
    }

    @discardableResult
    static func command(_ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let pipe = Pipe()
            
            task.standardOutput = pipe
            task.standardError = pipe
            task.arguments = args
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.standardInput = nil
            
            do {
                try task.run()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else {
                    throw ShellError.failedToParseResponse
                }
                
                continuation.resume(returning: output)
            } catch {
                Logger.error("Shell command failure. Command: \(args)", error: error)
                continuation.resume(throwing: error)
            }
        }
    }
    
    enum ShellError: Error {
        case failedToParseResponse
    }
}


