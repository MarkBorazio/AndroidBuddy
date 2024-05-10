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
    func list(serial: String, path: URL) async throws -> ListResponse
    func getBluetoothName(serial: String) async throws -> String?
    func pull(serial: String, remotePath: URL, localPath: URL) -> any Publisher<FileTransferResponse, Error>
    func push(serial: String, localPath: URL, remotePath: URL) -> any Publisher<FileTransferResponse, Error>
    func installAPK(serial: String, localPath: URL) -> any Publisher<InstallAPKResponse, Error>
    func delete(serial: String, remotePath: URL, isDirectory: Bool) async throws
    func createNewFolder(serial: String, remotePath: URL) async throws
    func rename(serial: String, remoteSourcePath: URL, remoteDestinationPath: URL) async throws
    func move(serial: String, remoteSourcePaths: [URL], remoteDestinationPath: URL) -> InteractiveADBCommand<InteractiveMoveResponse>
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
