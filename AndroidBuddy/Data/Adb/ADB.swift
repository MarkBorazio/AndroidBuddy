//
//  ADB.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 6/4/2024.
//

import Foundation
import Combine

enum ADB {
    
    typealias ADBArgs = [String]
    
    private static let executableUrl = Bundle.main.url(forResource: "adb", withExtension: nil)!
    
    static func listArgs(serial: String, path: URL) -> ADBArgs {
        ["-s", serial, "shell", "ls", "-lL", "\(path.pathForShellCommand)"]
    }
    
    static func pullArgs(serial: String, remotePath: URL, localPath: URL) -> ADBArgs {
        ["-s", serial, "pull", "\(remotePath.pathForADBCommand)", "\(localPath.pathForADBCommand)"]
    }
    
    static func pushArgs(serial: String, localPath: URL, remotePath: URL) -> ADBArgs {
        ["-s", serial, "push", "\(localPath.pathForADBCommand)", "\(remotePath.pathForADBCommand)"]
    }

    static func installAPKArgs(serial: String, localPath: URL) -> ADBArgs {
        ["-s", serial, "install", "-r", "\(localPath.pathForADBCommand)"]
    }
    
    static func deleteFileArgs(serial: String, remotePath: URL) -> ADBArgs {
        ["-s", serial, "shell", "rm", "-f", "\(remotePath.pathForShellCommand)"]
    }
    
    static func deleteDirectoryArgs(serial: String, remotePath: URL) -> ADBArgs {
        ["-s", serial, "shell", "rm", "-rf", "\(remotePath.pathForShellCommand)"]
    }
    
    static func getBluetoothNameArgs(serial: String) -> ADBArgs {
        ["-s", serial, "shell", "dumpsys", "bluetooth_manager", "|", "grep", "'name:'", "|", "cut", "-c9-"]
    }
    
    static func createNewDirectoryArgs(serial: String, remotePath: URL) -> ADBArgs {
        ["-s", serial, "shell", "mkdir", remotePath.pathForShellCommand]
    }
    
    static func moveArgs(serial: String, remoteSourcePaths: [URL], remoteDestinationPath: URL, interactive: Bool, noClobber: Bool) -> ADBArgs {
        var args = ["-s", serial, "shell", "mv"]
        if interactive {
            args.append("-i")
        }
        if noClobber {
            args.append("-n")
        }
        return args + remoteSourcePaths.map(\.pathForShellCommand) + [remoteDestinationPath.pathForShellCommand]
    }
    
    static let devicesArgs: ADBArgs = ["devices", "-l"]
    
    static let killServerArgs: ADBArgs = ["kill-server"]

    static let startServerArgs: ADBArgs = ["start-server"]
    
    static func commandPublisher(_ args: ADBArgs) -> InteractiveADBCommand<String> {
        Logger.verbose("Sending ADB command (publisher). Args: \(args.joined(separator: " "))")
        
        // Setup the PTY handles
        var primaryDescriptor: Int32 = 0
        var replicaDescriptor: Int32 = 0
        guard openpty(&primaryDescriptor, &replicaDescriptor, nil, nil, nil) != -1 else {
            let failurePublisher = Fail<String, Error>(error: AdbError.failedToOpenPty).eraseToAnyPublisher()
            let emptyWriteHandler: ADBWriteHandler = { _ in }
            return InteractiveADBCommand(publisher: failurePublisher, writeHandler: emptyWriteHandler)
        }
        let primaryHandle = FileHandle(fileDescriptor: primaryDescriptor, closeOnDealloc: true)
        let replicaHandle = FileHandle(fileDescriptor: replicaDescriptor, closeOnDealloc: true)
        let inputPipe = Pipe()
        
        let process = Process()
        process.standardInput = inputPipe
        process.standardOutput = replicaHandle
        process.standardError = replicaHandle
        process.arguments = args
        process.executableURL = executableUrl
        process.environment = [
            "TERM": "SMART"
        ]
        
        // syncQueue exists because the process can exit and the .finished completion be sent when
        // the readabilityHandler is in the middle of executing it's block.
        // This isn't the greatest solution; I think it's possible that the process can finish before
        // the readability handler is called for the last time, but so far I haven't noticed that happen.
        let syncQueue = DispatchQueue(label: "androidBuddy.commandPublisher.syncQueue")
        let gloabalQueue = DispatchQueue.global(qos: .userInitiated)
        
        let subject = PassthroughSubject<String, Error>()
        
        let deferredPublisher = Deferred {
            
            gloabalQueue.async {
                
                primaryHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    syncQueue.async {
                        do {
                            guard let rawOutput = String(data: data, encoding: .utf8) else {
                                throw AdbError.dataNotUtf8
                            }
                            Logger.verbose(rawOutput)
                            guard !rawOutput.isEmpty else { return }
                            let sanitisedOutput = try sanitiseOutput(rawOutput)
                            Logger.verbose(sanitisedOutput)
                            subject.send(sanitisedOutput)
                        } catch {
                            Logger.error("ADB readabilityHandler error.", error: error)
                            subject.send(completion: .failure(error))
                        }
                    }
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    syncQueue.async {
                        subject.send(completion: .finished)
                    }
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
        
        let writeHandler: ADBWriteHandler = { input in
            syncQueue.async {
                do {
                    let inputWithNewline = input.appending("\n")
                    guard let inputData = inputWithNewline.data(using: .utf8) else {
                        throw AdbError.writeError
                    }
                    try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
                } catch {
                    Logger.error("ADB writeHandler error.", error: error)
                    subject.send(completion: .failure(error))
                }
            }
        }
        
        return InteractiveADBCommand(publisher: deferredPublisher, writeHandler: writeHandler)
    }
    
    @discardableResult
    static func command(_ args: ADBArgs) async throws -> String {
        Logger.verbose("Sending ADB command. Args: \(args.joined(separator: " "))")
        return try await withCheckedThrowingContinuation { continuation in
            let pipe = Pipe()
            let testPipe = Pipe()
            
            let process = Process()
            process.standardOutput = pipe
            process.standardInput = testPipe
            process.standardError = pipe
            process.arguments = args
            process.executableURL = executableUrl
            
            // Run process here in it's own do block so that if there is an error running it,
            // we can return early and not run the `terminate` function
            // as that would otherwise result in a crash.
            do {
                try process.run()
            } catch {
                Logger.error("Failed to run process.", error: error)
                continuation.resume(throwing: error)
                return
            }
                
            do {
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
        
        if components.contains("* failed to start daemon") {
            throw AdbError.daemonError
        }
        
        if components.contains(where: { $0.hasPrefix("adb:") }) {
            throw AdbError.adbError(output: rawOutput)
        }
        
        return components
            .filter { !$0.hasPrefix("*") } // Lines that start with "*" are just logging statements that can be discarded
            .joined(separator: "\n")
    }
    
    enum AdbError: Error {
        case daemonError
        case adbError(output: String) // When error starts with "adb:"
        case commandError(output: String) // When error starts with command (eg: "ls:")
        case failedToOpenPty
        case dataNotUtf8
        case responseParseError
        case writeError
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
}
