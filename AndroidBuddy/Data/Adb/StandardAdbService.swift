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
        resetServer()
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
        
        Logger.verbose("Getting all devices...")
        let devicesResponse = try await ADB.devices()
        Logger.verbose("...got devices.")
        for serial in devicesResponse.connectedDeviceSerials {
            Logger.verbose("Getting bluetooth name for \(serial)...")
            let name = try await ADB.getBluetoothName(serial: serial)
            Logger.verbose("...got Bluetooth name for \(serial).")
            let device = Device(bluetoothName: name, serial: serial)
            devices.append(device)
        }
        
        return devices
    }
    
    func resetServer() {
        Logger.info("Beginning server reset.")
        Task {
            do {
                stateSubject.send(.settingUp)
                Logger.info("Killing server...")
                try await ADB.killServer()
                Logger.info("...server killed.")
                try await Task.sleep(for: .seconds(3)) // Running kill server and then start server too close together causes issues
                Logger.info("Starting server...")
                try await ADB.startServer()
                Logger.info("...server started.")
                let devices = try await getAllDevices()
                connectedDevicesSubject.send(devices) // Get initial data so there isn't a one second peroid of no data at the start
                stateSubject.send(.running)
            } catch {
                stateSubject.send(.error)
            }
        }
    }
    
    func list(serial: String, path: URL) async throws -> ListCommandResponse {
        Logger.info("Listing devices for \(serial) at path \(path.path(percentEncoded: false))")
        return try await ADB.list(serial: serial, path: path)
    }
    
    func pull(serial: String, remotePath: URL) -> any Publisher<PullProgressResponse, Error> {
        Logger.info("Pulling \(remotePath.path(percentEncoded: false))")
        return ADB.pull(serial: serial, remotePath: remotePath)
            .eraseToAnyPublisher()
            .tryMap { try PullProgressResponse(rawOutput: $0) }
            .removeDuplicates()
    }
    
    func push(serial: String, localPath: URL, remotePath: URL) async throws {
        Logger.info("Pushing \(localPath.path(percentEncoded: false)) to \(remotePath.path(percentEncoded: false))")
        try await ADB.push(serial: serial, localPath: localPath, remotePath: remotePath)
    }
    
    func delete(serial: String, remotePath: URL) async throws {
        Logger.info("Deleting \(remotePath.path(percentEncoded: false)) for \(serial).")
        try await ADB.delete(serial: serial, remotePath: remotePath)
    }
}
