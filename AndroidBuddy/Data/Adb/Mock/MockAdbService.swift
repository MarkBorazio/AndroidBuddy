//
//  MockAdbService.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 13/4/2024.
//

import Foundation
import Combine

class MockAdbService {
    
    var connectedDevices: any Publisher<[Device], Error>
    var state: any Publisher<ADBServiceState, Never>
    
    private var resetServerBlock: () -> Void
    private var listBlock: (URL) -> ListResponse
    private var getBlueoothNameBlock: () -> String?
    private var pullBlock: () -> any Publisher<FileTransferResponse, Error>
    private var pushBlock: () -> any Publisher<FileTransferResponse, Error>
    private var installAPKBlock: () -> any Publisher<InstallAPKResponse, Error>
    private var deleteBlock: () -> Void
    private var createNewFolderBlock: () -> Void
    private var renameBlock: () -> Void
    private var moveBlock: () -> Void
    private var doesFileExistBlock: () -> Bool
    
    init(
        adbState: ADBServiceState,
        connectedDevices: [Device],
        resetServer: @escaping () -> Void = defaultResetServerBlock,
        list: @escaping (URL) -> ListResponse = defaultListBlock,
        getBluetoothName: @escaping () -> String? = defaultGetBluetoothNameBlock,
        pull: @escaping () -> any Publisher<FileTransferResponse, Error> = defaultPullBlock,
        push: @escaping () -> any Publisher<FileTransferResponse, Error> = defaultPushBlock,
        installAPK: @escaping () -> any Publisher<InstallAPKResponse, Error> = defaultInstallAPKBlock,
        delete: @escaping () -> Void = defaultDeleteBlock,
        createNewFolder: @escaping () -> Void = defaultCreateNewFolderBlock,
        rename: @escaping () -> Void = defaultRenameBlock,
        move: @escaping () -> Void = defaultMoveBlock,
        doesFileExist: @escaping () -> Bool = defaultDoesFileExistBlock
    ) {
        self.connectedDevices = CurrentValueSubject(connectedDevices).eraseToAnyPublisher()
        state = CurrentValueSubject(adbState).eraseToAnyPublisher()

        resetServerBlock = resetServer
        listBlock = list
        getBlueoothNameBlock = getBluetoothName
        pullBlock = pull
        pushBlock = push
        installAPKBlock = installAPK
        deleteBlock = delete
        createNewFolderBlock = createNewFolder
        renameBlock = rename
        moveBlock = move
        doesFileExistBlock = doesFileExist
    }
    
    private static func getResponse(fileName: String) -> String {
        let url = Bundle.main.url(forResource: fileName, withExtension: nil)!
        let data = try! Data(contentsOf: url)
        return String(data: data, encoding: .utf8)!
    }
}

// MARK: - Default Implementations

extension MockAdbService {
    
    private static var defaultResetServerBlock: () -> Void = {}
    
    private static var defaultListBlock: (URL) -> ListResponse = { path in
        let response = getResponse(fileName: "MockListResponse")
        return try! ListResponse(path: path, rawResponse: response)
    }
    
    private static var defaultGetBluetoothNameBlock: () -> String? = {
        return "Mock Device Name"
    }
    
    private static var defaultPullBlock: () -> any Publisher<FileTransferResponse, Error> = {
        let response = try! FileTransferResponse(rawOutput: "[ 39%] /sdcard/Roms/Gamecube/Super Mario Strikers.iso")
        return CurrentValueSubject<FileTransferResponse, Error>(response)
    }
    
    private static var defaultPushBlock: () -> any Publisher<FileTransferResponse, Error> = {
        let response = try! FileTransferResponse(rawOutput: "[ 39%] /sdcard/Roms/Gamecube/Super Mario Strikers.iso")
        return CurrentValueSubject<FileTransferResponse, Error>(response)
    }
    
    private static var defaultInstallAPKBlock: () -> any Publisher<InstallAPKResponse, Error> = {
        let response = try! InstallAPKResponse(rawOutput: "Performing Streamed Install")
        return CurrentValueSubject<InstallAPKResponse, Error>(response)
    }
    
    private static var defaultDeleteBlock: () -> Void = {}
    
    private static var defaultCreateNewFolderBlock: () -> Void = {}
    
    private static var defaultRenameBlock: () -> Void = {}
    
    private static var defaultMoveBlock: () -> Void = {}
    
    private static var defaultDoesFileExistBlock: () -> Bool = { true }
}

// MARK: - ADB Service Implementation

extension MockAdbService: ADBService {
    
    func resetServer() {
        resetServerBlock()
    }
    
    func list(serial: String, path: URL) async throws -> ListResponse {
        listBlock(path)
    }
    
    func getBluetoothName(serial: String) async throws -> String? {
        getBlueoothNameBlock()
    }
    
    func pull(serial: String, remotePath: URL, localPath: URL) -> any Publisher<FileTransferResponse, Error> {
        pullBlock()
    }
    
    func push(serial: String, localPath: URL, remotePath: URL) -> any Publisher<FileTransferResponse, Error>{
        pushBlock()
    }
    
    func installAPK(serial: String, localPath: URL) -> any Publisher<InstallAPKResponse, Error> {
        installAPKBlock()
    }
    
    func delete(serial: String, remotePath: URL, isDirectory: Bool) async throws {
        deleteBlock()
    }
    
    func createNewFolder(serial: String, remotePath: URL) async throws {
        createNewFolderBlock()
    }
    
    func rename(serial: String, remoteSourcePath: URL, remoteDestinationPath: URL) async throws {
        renameBlock()
    }
    
    func move(serial: String, remoteSourcePaths: [URL], remoteDestinationPath: URL) async throws {
        moveBlock()
    }
    
    func doesFileExist(serial: String, remotePath: URL) async throws -> Bool {
        doesFileExistBlock()
    }
}
