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
    private var pullBlock: () -> any Publisher<FileTransferResponse, Error>
    private var pushBlock: () -> any Publisher<FileTransferResponse, Error>
    private var deleteBlock: () -> Void
    private var createNewFolderBlock: () -> Void
    private var renameBlock: () -> Void
    private var doesFileExistBlock: () -> Bool
    
    init(
        adbState: ADBServiceState,
        connectedDevices: [Device],
        resetServer: @escaping () -> Void = defaultResetServerBlock,
        list: @escaping (URL) -> ListResponse = defaultListBlock,
        pull: @escaping () -> any Publisher<FileTransferResponse, Error> = defaultPullBlock,
        push: @escaping () -> any Publisher<FileTransferResponse, Error> = defaultPushBlock,
        delete: @escaping () -> Void = defaultDeleteBlock,
        createNewFolder: @escaping () -> Void = defaultCreateNewFolderBlock,
        rename: @escaping () -> Void = defaultRenameBlock,
        doesFileExist: @escaping () -> Bool = defaultDoesFileExistBlock
    ) {
        self.connectedDevices = CurrentValueSubject(connectedDevices).eraseToAnyPublisher()
        state = CurrentValueSubject(adbState).eraseToAnyPublisher()

        resetServerBlock = resetServer
        listBlock = list
        pullBlock = pull
        pushBlock = push
        deleteBlock = delete
        createNewFolderBlock = createNewFolder
        renameBlock = rename
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
    
    private static var defaultPullBlock: () -> any Publisher<FileTransferResponse, Error> = {
        let response = try! FileTransferResponse(rawOutput: "[ 39%] /sdcard/Roms/Gamecube/Super Mario Strikers.iso")
        return CurrentValueSubject<FileTransferResponse, Error>(response)
    }
    
    private static var defaultPushBlock: () -> any Publisher<FileTransferResponse, Error> = {
        let response = try! FileTransferResponse(rawOutput: "[ 39%] /sdcard/Roms/Gamecube/Super Mario Strikers.iso")
        return CurrentValueSubject<FileTransferResponse, Error>(response)
    }
    
    private static var defaultDeleteBlock: () -> Void = {}
    
    private static var defaultCreateNewFolderBlock: () -> Void = {}
    
    private static var defaultRenameBlock: () -> Void = {}
    
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
    
    func pull(serial: String, remotePath: URL, localPath: URL) -> any Publisher<FileTransferResponse, Error> {
        pullBlock()
    }
    
    func push(serial: String, localPath: URL, remotePath: URL) -> any Publisher<FileTransferResponse, Error>{
        pushBlock()
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
    
    func doesFileExist(serial: String, remotePath: URL) async throws -> Bool {
        doesFileExistBlock()
    }
}
