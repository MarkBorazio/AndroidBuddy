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
        let args = ["-s", serial, "shell", "ls", "-lL", "\(path.pathForShellCommand)"]
        let output = try await command(args: args)
        return ListCommandResponse(path: path, rawResponse: output)
    }
    
    static func pull(serial: String, remotePath: URL) async throws {
        let args = ["-s", serial, "pull", "\(remotePath.pathForADBCommand)", "Downloads"]
        try await command(args: args)
    }
    
    static func push(serial: String, localPath: URL, remotePath: URL) async throws {
        let args = ["-s", serial, "push", "\(localPath.pathForADBCommand)", "\(remotePath.pathForADBCommand)"]
        try await command(args: args)
    }
    
    static func delete(serial: String, remotePath: URL) async throws {
        let args = ["-s", serial, "shell", "rm", "-f", "\(remotePath.pathForShellCommand)"]
        try await command(args: args)
    }
    
    static func getBluetoothName(serial: String) async throws -> String {
        let args = ["-s", serial, "shell", "dumpsys", "bluetooth_manager", "|", "grep", "'name:'", "|", "cut", "-c9-"]
        return try await command(args: args)
    }
    
    static func devices() async throws -> DevicesResponse {
        let args = ["devices", "-l"]
        let output = try! await command(args: args)
        return DevicesResponse(rawOutput: output)
    }
    
    static func killServer() async throws {
        let args = ["kill-server"]
        try await command(args: args)
    }
    
    static func startServer() async throws {
        let args = ["start-server"]
        try await command(args: args)
    }

    @discardableResult
    private static func command(args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            
            process.standardOutput = pipe
            process.standardError = pipe
            process.arguments = args
            process.executableURL = executableUrl
            process.standardInput = nil
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)!

                try checkForDaemonError(output) // Should check first
                try checkForCommandError(output)
                
                let sanitisedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: sanitisedOutput)
            } catch {
                assert(false, "ADB Error: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    private static func checkForDaemonError(_ rawOutput: String) throws {
        let components = rawOutput.components(separatedBy: .newlines)
        let errorLine = "* failed to start daemon"
        if components.contains(errorLine) {
            throw AdbError.daemonError
        }
    }
    
    // From what I can tell, command errors start with "adb:" on the first line
    private static func checkForCommandError(_ rawOutput: String) throws {
        if rawOutput.hasPrefix("adb:") {
            throw AdbError.commandError(output: rawOutput)
        }
    }
    
    enum AdbError: Error {
        case daemonError
        case commandError(output: String)
    }
}
