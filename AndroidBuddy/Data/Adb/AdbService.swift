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

    var connectedDevices = CurrentValueSubject<DevicesResponse, Error>(.emptyResponse)
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
            .asyncTryMap { _ in
                return try await ADB.devices()
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
    
    enum ADBState {
        case notRunning
        case settingUp
        case running
        case error
    }
}
