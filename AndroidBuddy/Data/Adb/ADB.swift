//
//  ADB.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 6/4/2024.
//

import Foundation

enum ADB {
    
    private static let executableUrl = Bundle.main.url(forResource: "adb", withExtension: nil)!
    
    static func list(serial: String, path: URL) async throws -> ListCommandResponse {
        let args = ["-s", "\(serial)", "shell", "ls", "-lL", "\(path.pathForShellCommand)"]
        let output = try await command(args: args)
        return ListCommandResponse(path: path, rawResponse: output)
    }
    
    static func pull(serial: String, remotePath: URL) async throws {
        let args = ["-s", "\(serial)", "pull", "\(remotePath.pathForADBCommand)", "Downloads"]
        try await command(args: args)
    }
    
    static func push(serial: String, localPath: URL, remotePath: URL) async throws {
        let args = ["-s", "\(serial)", "push", "\(localPath.pathForADBCommand)", "\(remotePath.pathForADBCommand)"]
        try await command(args: args)
    }
    
    static func delete(serial: String, remotePath: URL) async throws {
        let args = ["-s", "\(serial)", "shell", "rm", "-f", "\(remotePath.pathForShellCommand)"]
        try await command(args: args)
    }
    
    static func devices() async throws -> DevicesResponse {
        let args = ["devices", "-l"]
        let output = try! await command(args: args)
        return DevicesResponse(rawOutput: output)
    }
    

    @discardableResult
    private static func command(args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let pipe = Pipe()
            
            task.standardOutput = pipe
            task.standardError = pipe
            task.arguments = args
            task.executableURL = executableUrl
            task.standardInput = nil
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)!
                
                if output.hasPrefix("adb:") {
                    assert(false, output)
                    continuation.resume(throwing: AdbError.commandError(output: output))
                } else {
                    continuation.resume(returning: output)
                }
            } catch {
                print("Unexpected ADB Error: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    enum AdbError: Error {
        case commandError(output: String)
    }
}
