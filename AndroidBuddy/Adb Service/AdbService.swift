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
    
    func listCommand(path: URL) throws -> ListCommandResponse {
        let args = "shell ls -lL \(path.path())"
        let output = try adbCommand(argsString: args)
        return ListCommandResponse(path: path, rawResponse: output)
    }
    
    func pullCommand(remotePath: URL) throws {
        let args = "pull \(remotePath.path()) Downloads"
        try adbCommand(argsString: args)
    }
    
    func pushCommand(localPath: URL, remotePath: URL) throws {
        let args = "push \(localPath.path()) \(remotePath.path())"
        let output = try adbCommand(argsString: args)
        
        print(args)
        print(localPath)
        print(output)
    }
    
    @discardableResult
    func manualCommand(args: String) throws -> String {
        return try adbCommand(argsString: args)
    }
    
    @discardableResult
    private func adbCommand(argsString: String) throws -> String {
        let args = argsString.components(separatedBy: " ")
        return try adbCommand(args: args)
    }
    
    // TODO: Make async?
    @discardableResult
    private func adbCommand(args: [String]) throws -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = args
        task.executableURL = Bundle.main.url(forResource: "adb", withExtension: nil)!
        task.standardInput = nil

        try task.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        
        return output
    }
}
