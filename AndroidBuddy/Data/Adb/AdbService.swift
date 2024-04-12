//
//  AdbService.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 1/4/2024.
//

import Foundation
import Combine

class AdbService {
    
    static let shared = AdbService()

    var connectedDevices = CurrentValueSubject<[Device], Error>([])
    var state = CurrentValueSubject<ADBState, Never>(.notRunning)
    
    private var cancellables = Set<AnyCancellable>()
    private let backgroundQueue = DispatchQueue(label: "AdbService", qos: .background)
    
    private init() {
        setupDeviceMonitoring()
        startServer()
    }
    
    func startServer() {
        Task {
            do {
                state.send(.settingUp)
                try await ADB.killServer()
                try await Task.sleep(for: .seconds(2)) // Running kill server and then start server too close together causes issues
                try await ADB.startServer()
                let devices = try await getAllDevices()
                connectedDevices.send(devices) // Get initial data so there isn't a one second peroid of no data at the start
                state.send(.running)
            } catch {
                state.send(.error)
            }
        }
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
        
        state.flatMap { newState in
            switch newState {
            case .running: 
                return periodicDeviceRefresh.eraseToAnyPublisher()
            case .notRunning, .settingUp, .error: 
                return Empty(completeImmediately: false).eraseToAnyPublisher()
            }
        }
        .subscribe(connectedDevices)
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
    
    enum ADBState {
        case notRunning
        case settingUp
        case running
        case error
    }
}
