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
    
    var startServerBlock: () -> Void
    var killServerBlock: () -> Void
    var listBlock: (URL) -> ListCommandResponse
    var pullBlock: () -> any Publisher<PullProgressResponse, Error>
    var pushBlock: () -> Void
    var deleteBlock: () -> Void
    var getBluetoothNameBlock: () -> String
    var devicesBlock: () -> DevicesResponse
    
    init(
        adbState: ADBServiceState,
        devices: [Device],
        startServerBlock: @escaping () -> Void = defaultStartServerBlock,
        killServerBlock: @escaping () -> Void = defaultKillServerBlock,
        listBlock: @escaping (URL) -> ListCommandResponse = defaultListBlock,
        pullBlock: @escaping () -> any Publisher<PullProgressResponse, Error> = defaultPullBlock,
        pushBlock: @escaping () -> Void = defaultPushBlock,
        deleteBlock: @escaping () -> Void = defaultDeleteBlock,
        getBluetoothNameBlock: @escaping () -> String = defaultGetBluetoothNameBlock,
        devicesBlock: @escaping () -> DevicesResponse = defaultDevicesBlock
    ) {
        connectedDevices = CurrentValueSubject(devices).eraseToAnyPublisher()
        state = CurrentValueSubject(adbState).eraseToAnyPublisher()
        
        self.startServerBlock = startServerBlock
        self.killServerBlock = killServerBlock
        self.listBlock = listBlock
        self.pullBlock = pullBlock
        self.pushBlock = pushBlock
        self.deleteBlock = deleteBlock
        self.getBluetoothNameBlock = getBluetoothNameBlock
        self.devicesBlock = devicesBlock
    }
    
    private static func getResponse(fileName: String) -> String {
        let url = Bundle.main.url(forResource: fileName, withExtension: nil)!
        let data = try! Data(contentsOf: url)
        return String(data: data, encoding: .utf8)!
    }
}

// MARK: - Default Implementations

extension MockAdbService {
    
    static var defaultStartServerBlock: () -> Void = {}
    
    static var defaultKillServerBlock: () -> Void = {}
    
    static var defaultListBlock: (URL) -> ListCommandResponse = { path in
        let response = getResponse(fileName: "MockListResponse")
        return ListCommandResponse(path: path, rawResponse: response)
    }
    
    static var defaultPullBlock: () -> any Publisher<PullProgressResponse, Error> = {
        let response = PullProgressResponse(rawOutput: "[ 39%] /sdcard/Roms/Gamecube/Super Mario Strikers.iso")
        return CurrentValueSubject<PullProgressResponse, Error>(response)
    }
    
    static var defaultPushBlock: () -> Void = {}
    
    static var defaultDeleteBlock: () -> Void = {}
    
    static var defaultGetBluetoothNameBlock: () -> String = {
        "Mock Device Name"
    }
    
    static var defaultDevicesBlock: () -> DevicesResponse = {
        let response = getResponse(fileName: "MockDevicesResponse")
        return DevicesResponse(rawOutput: response)
    }
    
}

// MARK: - ADB Service Implementation

extension MockAdbService: ADBService {
    
    func startServer() {
        startServerBlock()
    }
    
    func killServer() async throws {
        killServerBlock()
    }
    
    func list(serial: String, path: URL) async throws -> ListCommandResponse {
        listBlock(path)
    }
    
    func pull(serial: String, remotePath: URL) -> any Publisher<PullProgressResponse, Error> {
        pullBlock()
    }
    
    func push(serial: String, localPath: URL, remotePath: URL) async throws {
        pushBlock()
    }
    
    func delete(serial: String, remotePath: URL) async throws {
        deleteBlock()
    }
    
    func getBluetoothName(serial: String) async throws -> String {
        getBluetoothNameBlock()
    }
    
    func devices() async throws -> DevicesResponse {
        devicesBlock()
    }
    
}
