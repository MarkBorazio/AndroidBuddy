//
//  StandardAdbService.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 1/4/2024.
//

import Foundation
import Combine

class StandardAdbService: ADBService {
    
    
    private var connectedDevicesSubject = CurrentValueSubject<[Device], Error>([])
    private var stateSubject = CurrentValueSubject<ADBServiceState, Never>(.notRunning)
    
    private var cancellables = Set<AnyCancellable>()
    private let backgroundQueue = DispatchQueue(label: "AdbService", qos: .background)
    
    let connectedDevices: any Publisher<[Device], Error>
    let state: any Publisher<ADBServiceState, Never>
    
    init() {
        connectedDevices = connectedDevicesSubject.eraseToAnyPublisher()
        state = stateSubject.eraseToAnyPublisher()
        
        setupDeviceMonitoring()
        startServer()
    }
    
    private func setupDeviceMonitoring() {
        let periodicDeviceRefresh = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .receive(on: backgroundQueue)
            .asyncTryCompactMap { [weak self] _ -> [Device]? in
                guard let self else { return nil }
                return try await getAllDevices()
            }
            .removeDuplicates()
        
        stateSubject.flatMap { newState in
            switch newState {
            case .running: 
                return periodicDeviceRefresh.eraseToAnyPublisher()
            case .notRunning, .settingUp, .error: 
                return Empty(completeImmediately: false).eraseToAnyPublisher()
            }
        }
        .subscribe(connectedDevicesSubject)
        .store(in: &cancellables)
    }
    
    private func getAllDevices() async throws -> [Device] {
        var devices: [Device] = []
        
        let devicesResponse = try await ADB.devices()
        for serial in devicesResponse.connectedDeviceSerials {
            let name = try await ADB.getBluetoothName(serial: serial)
            let device = Device(bluetoothName: name, serial: serial)
            devices.append(device)
        }
        
        return devices
    }
    
    func startServer() {
        Task {
            do {
                stateSubject.send(.settingUp)
                try await ADB.killServer()
                try await Task.sleep(for: .seconds(2)) // Running kill server and then start server too close together causes issues
                try await ADB.startServer()
                let devices = try await getAllDevices()
                connectedDevicesSubject.send(devices) // Get initial data so there isn't a one second peroid of no data at the start
                stateSubject.send(.running)
            } catch {
                stateSubject.send(.error)
            }
        }
    }
    
    func killServer() async throws {
        try await ADB.killServer()
    }
    
    func list(serial: String, path: URL) async throws -> ListCommandResponse {
        try await ADB.list(serial: serial, path: path)
    }
    
    func pull(serial: String, remotePath: URL) -> any Publisher<PullProgressResponse, Error> {
        ADB.pull(serial: serial, remotePath: remotePath)
            .eraseToAnyPublisher()
            .map { PullProgressResponse(rawOutput: $0) }
            .removeDuplicates()
    }
    
    func push(serial: String, localPath: URL, remotePath: URL) async throws {
        try await ADB.push(serial: serial, localPath: localPath, remotePath: remotePath)
    }
    
    func delete(serial: String, remotePath: URL) async throws {
        try await ADB.delete(serial: serial, remotePath: remotePath)
    }
    
    func getBluetoothName(serial: String) async throws -> String {
        try await ADB.getBluetoothName(serial: serial)
    }
    
    func devices() async throws -> DevicesResponse {
        try await ADB.devices()
    }
}
