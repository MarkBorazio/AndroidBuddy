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
    private var listBlock: (URL) -> ListCommandResponse
    private var pullBlock: () -> any Publisher<FileTransferResponse, Error>
    private var pushBlock: () -> any Publisher<FileTransferResponse, Error>
    private var deleteBlock: () -> Void
    
    init(
        adbState: ADBServiceState,
        connectedDevices: [Device],
        resetServer: @escaping () -> Void = defaultResetServerBlock,
        list: @escaping (URL) -> ListCommandResponse = defaultListBlock,
        pull: @escaping () -> any Publisher<FileTransferResponse, Error> = defaultPullBlock,
        push: @escaping () -> any Publisher<FileTransferResponse, Error> = defaultPushBlock,
        delete: @escaping () -> Void = defaultDeleteBlock
    ) {
        self.connectedDevices = CurrentValueSubject(connectedDevices).eraseToAnyPublisher()
        state = CurrentValueSubject(adbState).eraseToAnyPublisher()

        resetServerBlock = resetServer
        listBlock = list
        pullBlock = pull
        pushBlock = push
        deleteBlock = delete
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
    
    private static var defaultListBlock: (URL) -> ListCommandResponse = { path in
        let response = getResponse(fileName: "MockListResponse")
        return try! ListCommandResponse(path: path, rawResponse: response)
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
}

// MARK: - ADB Service Implementation

extension MockAdbService: ADBService {
    
    func resetServer() {
        
    }
    
    func list(serial: String, path: URL) async throws -> ListCommandResponse {
        listBlock(path)
    }
    
    func pull(serial: String, remotePath: URL) -> any Publisher<FileTransferResponse, Error> {
        pullBlock()
    }
    
    func push(serial: String, localPath: URL, remotePath: URL) -> any Publisher<FileTransferResponse, Error>{
        pushBlock()
    }
    
    func delete(serial: String, remotePath: URL) async throws {
        deleteBlock()
    }
}
