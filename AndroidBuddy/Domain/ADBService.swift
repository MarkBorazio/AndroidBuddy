//
//  ADBService.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 13/4/2024.
//

import Foundation
import Combine

protocol ADBService {
    
    var connectedDevices: any Publisher<[Device], Error> { get }
    var state: any Publisher<ADBServiceState, Never> { get }
    
    func resetServer()
    func list(serial: String, path: URL) async throws -> ListCommandResponse
    func pull(serial: String, remotePath: URL, localPath: URL) -> any Publisher<FileTransferResponse, Error>
    func push(serial: String, localPath: URL, remotePath: URL) -> any Publisher<FileTransferResponse, Error>
    func delete(serial: String, remotePath: URL) async throws
    func createNewFolder(serial: String, remotePath: URL) async throws
    func rename(serial: String, remoteSourcePath: URL, remoteDestinationPath: URL) async throws
    func doesFileExist(serial: String, remotePath: URL) async throws -> Bool
}

enum ADBServiceState {
    case notRunning
    case settingUp
    case running
    case error
}

enum ADBServiceError: Error {
    case noSuchFileOrDirectory
    case fileOrDirectoryAlreadyExists
}
