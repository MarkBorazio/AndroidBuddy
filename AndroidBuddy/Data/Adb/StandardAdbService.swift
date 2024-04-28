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
    
    func list(serial: String, path: URL) async throws -> ListResponse {
        Logger.info("Listing devices for \(serial) at path \(path.path(percentEncoded: false))")
        return try await ADB.list(serial: serial, path: path)
    }
    
    func pull(serial: String, remotePath: URL, localPath: URL) -> any Publisher<FileTransferResponse, Error> {
        Logger.info("Pulling \(remotePath.path(percentEncoded: false)) to \(localPath.path(percentEncoded: false))")
        return ADB.pull(serial: serial, remotePath: remotePath, localPath: localPath)
            .eraseToAnyPublisher()
            .tryMap { try FileTransferResponse(rawOutput: $0) }
            .removeDuplicates()
    }
    
    func push(serial: String, localPath: URL, remotePath: URL) -> any Publisher<FileTransferResponse, Error> {
        Logger.info("Pushing \(localPath.path(percentEncoded: false)) to \(remotePath.path(percentEncoded: false))")
        return ADB.push(serial: serial, localPath: localPath, remotePath: remotePath)
            .eraseToAnyPublisher()
            .tryMap { try FileTransferResponse(rawOutput: $0) }
            .removeDuplicates()
    }
    
    func delete(serial: String, remotePath: URL, isDirectory: Bool) async throws {
        Logger.info("Deleting \(remotePath.path(percentEncoded: false)) for \(serial).")
        let output = if isDirectory {
            try await ADB.deleteDirectory(serial: serial, remotePath: remotePath)
        } else {
            try await ADB.deleteFile(serial: serial, remotePath: remotePath)
        }
        try DeleteResponse.checkForErrors(rawOutput: output)
    }
    
    func createNewFolder(serial: String, remotePath: URL) async throws {
        Logger.info("Creating new directory at \(remotePath.path(percentEncoded: false)) for \(serial).")
        let output = try await ADB.createNewDirectory(serial: serial, remotePath: remotePath)
        try CreateDirectoryResponse.checkForErrors(rawOutput: output)
    }
    
    func rename(serial: String, remoteSourcePath: URL, remoteDestinationPath: URL) async throws {
        Logger.info("Renaming \(remoteSourcePath.path(percentEncoded: false)) to \(remoteDestinationPath.path(percentEncoded: false)) for device \(serial).")
        let fileOrDirectoryExists = try await doesFileExist(serial: serial, remotePath: remoteDestinationPath)
        guard !fileOrDirectoryExists else {
            throw ADBServiceError.fileOrDirectoryAlreadyExists
        }
        let output = try await ADB.move(serial: serial, remoteSourcePath: remoteSourcePath, remoteDestinationPath: remoteDestinationPath)
        try MoveResponse.checkForErrors(rawOutput: output)
    }
    
    func doesFileExist(serial: String, remotePath: URL) async throws -> Bool {
        Logger.info("Checking if \(remotePath.path(percentEncoded: false)) exists for device \(serial).")
        do {
            let _ = try await list(serial: serial, path: remotePath)
            return true // If the file does not exist, an error is thrown. Therefore, if we reach this point, the file must exist.
        } catch ADBServiceError.noSuchFileOrDirectory {
            return false
        }
    }
}
