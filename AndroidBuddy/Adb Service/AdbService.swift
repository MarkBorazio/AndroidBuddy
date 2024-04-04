//
//  AdbService.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 1/4/2024.
//

import Foundation

class AdbService {
    
    static let shared = AdbService()
    private init() {}
    
    func listCommand(path: URL) async throws -> ListCommandResponse {
        let args = "shell ls -lL \(path.path())"
        let output = try await adbCommand(argsString: args)
        return ListCommandResponse(path: path, rawResponse: output)
    }
    
    func pullCommand(remotePath: URL) async throws {
        let args = "pull \(remotePath.path()) Downloads"
        try await adbCommand(argsString: args)
    }
    
    func pushCommand(localPath: URL, remotePath: URL) async throws {
        let args = "push \(localPath.path()) \(remotePath.path())"
        try await adbCommand(argsString: args)
    }
    
    @discardableResult
    func manualCommand(args: String) async throws -> String {
        return try await adbCommand(argsString: args)
    }
    
    @discardableResult
    private func adbCommand(argsString: String) async throws -> String {
        let args = argsString.components(separatedBy: " ")
        return try await adbCommand(args: args)
    }

    @discardableResult
    private func adbCommand(args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let pipe = Pipe()
            
            task.standardOutput = pipe
            task.standardError = pipe
            task.arguments = args
            task.executableURL = Bundle.main.url(forResource: "adb", withExtension: nil)!
            task.standardInput = nil

            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)!
                if output.hasPrefix("adb: error:") {
                    print(output)
                    continuation.resume(throwing: AdbError.commandError(output: output))
                } else {
                    continuation.resume(returning: output)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    enum AdbError: Error {
        case commandError(output: String)
    }
}
