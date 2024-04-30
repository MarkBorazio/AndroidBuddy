//
//  ADB.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 6/4/2024.
//

import Foundation
import Combine

enum ADB {
    
    private static let executableUrl = Bundle.main.url(forResource: "adb", withExtension: nil)!
    
    static func list(serial: String, path: URL) async throws -> ListResponse {
        let args = ["-s", serial, "shell", "ls", "-lL", "\(path.pathForShellCommand)"]
        let output = try await command(args: args)
        return try ListResponse(path: path, rawResponse: output)
    }
    
    static func pull(serial: String, remotePath: URL, localPath: URL) -> any Publisher<String, Error> {
        let args = ["-s", serial, "pull", "\(remotePath.pathForADBCommand)", "\(localPath.pathForADBCommand)"]
        return commandPublisher(args: args)
    }
    
    static func push(serial: String, localPath: URL, remotePath: URL) -> any Publisher<String, Error> {
        let args = ["-s", serial, "push", "\(localPath.pathForADBCommand)", "\(remotePath.pathForADBCommand)"]
        return commandPublisher(args: args)
    }

    static func installAPK(serial: String, localPath: URL) -> any Publisher<String, Error> {
        let args = ["-s", serial, "install", "-r", "\(localPath.pathForADBCommand)"]
        return commandPublisher(args: args)
    }
    
    static func deleteFile(serial: String, remotePath: URL) async throws -> String {
        let args = ["-s", serial, "shell", "rm", "-f", "\(remotePath.pathForShellCommand)"]
        return try await command(args: args)
    }
    
    static func deleteDirectory(serial: String, remotePath: URL) async throws -> String {
        let args = ["-s", serial, "shell", "rm", "-rf", "\(remotePath.pathForShellCommand)"]
        return try await command(args: args)
    }
    
    static func getBluetoothName(serial: String) async throws -> String {
        let args = ["-s", serial, "shell", "dumpsys", "bluetooth_manager", "|", "grep", "'name:'", "|", "cut", "-c9-"]
        return try await command(args: args)
    }
    
    static func createNewDirectory(serial: String, remotePath: URL) async throws -> String {
        let args = ["-s", serial, "shell", "mkdir", remotePath.pathForShellCommand]
        return try await command(args: args)
    }
    
    static func move(serial: String, remoteSourcePath: URL, remoteDestinationPath: URL) async throws -> String {
        let args = ["-s", serial, "shell", "mv", remoteSourcePath.pathForShellCommand, remoteDestinationPath.pathForShellCommand]
        return try await command(args: args)
    }
    
    static func devices() async throws -> DevicesResponse {
        let args = ["devices", "-l"]
        let output = try await command(args: args)
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
    
    // Used for debugging - I am not sure how tightly written the regex is - Needs proper tests written for it
    @discardableResult
    static func command(args: String) async throws -> String {
        let regex = try! NSRegularExpression(pattern: #""[^"]*"|\S+"#) // Split args into array - Parts eclosed in quotes *should* be treated as one arg
        let argsArray = regex.matches(in: args, range: NSRange(args.startIndex..., in: args))
            .map { String(args[Range($0.range, in: args)!]) }
            .map { arg in
                arg.filter { $0 != "\"" }
            }
        return try await command(args: argsArray)
    }
    
    static func commandPublisher(args: [String]) -> any Publisher<String, Error> {
        Logger.verbose("Sending ADB command (publisher). Args: \(args.joined(separator: " "))")
        return Deferred {
            // Setup the PTY handles
            var primaryDescriptor: Int32 = 0
            var replicaDescriptor: Int32 = 0
            guard openpty(&primaryDescriptor, &replicaDescriptor, nil, nil, nil) != -1 else {
                return Fail<String, Error>(error: AdbError.failedToOpenPty).eraseToAnyPublisher()
            }
            let primaryHandle = FileHandle(fileDescriptor: primaryDescriptor, closeOnDealloc: true)
            let replicaHandle = FileHandle(fileDescriptor: replicaDescriptor, closeOnDealloc: true)
            
            let process = Process()
            process.standardInput = replicaHandle
            process.standardOutput = replicaHandle
            process.standardError = replicaHandle
            process.arguments = args
            process.executableURL = executableUrl
            process.environment = [
                "TERM": "SMART"
            ]
            
            let subject = PassthroughSubject<String, Error>()
            
            DispatchQueue.global(qos: .userInitiated).async {
                primaryHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard let rawOutput = String(data: data, encoding: .utf8) else { return }
                    Logger.verbose(rawOutput)
                    guard !rawOutput.isEmpty else { return }
                    do {
                        let sanitisedOutput = try sanitiseOutput(rawOutput)
                        Logger.verbose(sanitisedOutput)
                        subject.send(sanitisedOutput)
                    } catch {
                        Logger.error("ADB readabilityHandler error.", error: error)
                        subject.send(completion: .failure(error))
                    }
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    subject.send(completion: .finished)
                } catch {
                    Logger.error("ADB error.", error: error)
                    subject.send(completion: .failure(error))
                }
            }
            
            func cleanUp() {
                try? primaryHandle.close()
                try? replicaHandle.close()
                process.terminate()
            }
            
            return subject
                .handleEvents(
                    receiveCompletion: { _ in
                        cleanUp()
                    },
                    receiveCancel: {
                        cleanUp()
                    }
                )
                .eraseToAnyPublisher()
        }
    }
    
    @discardableResult
    static func command(args: [String]) async throws -> String {
        Logger.verbose("Sending ADB command. Args: \(args.joined(separator: " "))")
        return try await withCheckedThrowingContinuation { continuation in
            let pipe = Pipe()
            
            let process = Process()
            process.standardOutput = pipe
            process.standardError = pipe
            process.arguments = args
            process.executableURL = executableUrl
            
            do {
                try process.run()
                let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
                
                guard let rawOutput = String(data: data, encoding: .utf8) else {
                    throw AdbError.dataNotUtf8
                }
                
                Logger.verbose(rawOutput)

                let sanitisedOutput = try sanitiseOutput(rawOutput)
                continuation.resume(returning: sanitisedOutput)
            } catch {
                Logger.error("ADB error.", error: error)
                continuation.resume(throwing: error)
            }
            
            process.terminate()
        }
    }
    
    private static func sanitiseOutput(_ rawOutput: String) throws -> String {
        let components = rawOutput
            .trimmingPrefixCharacters(in: .whitespacesAndNewlines) // Don't trim trailing spaces and file names, as some reponses have trailing spaces (like in a file name, for example)
            .components(separatedBy: .newlines)
        
        let errorLine = "* failed to start daemon"
        if components.contains(errorLine) {
            throw AdbError.daemonError
        }
        
        let adbErrorPrefix = "adb:"
        if components.contains(where: { $0.hasPrefix(adbErrorPrefix) }) {
            throw AdbError.commandError(output: rawOutput)
        }
        
        return components
            .filter { !$0.hasPrefix("*") } // Lines that start with "*" are just logging statements that can be discarded
            .joined(separator: "\n")
    }
    
    enum AdbError: Error {
        case daemonError
        case commandError(output: String)
        case failedToOpenPty
        case dataNotUtf8
        case responseParseError(output: String)
    }
}
