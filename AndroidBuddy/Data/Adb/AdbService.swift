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
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        
        // Setup Device Monitoring
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .receive(on: DispatchQueue.global(qos: .background))
            .asyncTryMap { _ in
                return try await ADB.devices()
            }
            .removeDuplicates()
            .subscribe(connectedDevices)
            .store(in: &cancellables)
    }
}
