//
//  DevicesResponse.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 5/4/2024.
//

import Foundation

/// Response for the `adb devices -l` command
///
/// # Example Output
/// ```
/// List of devices attached
/// R5CT638F8ST    device
/// ```
struct DevicesResponse: Equatable {
    
    let connectedDeviceSerials: [String]
    
    init(rawOutput: String) {
        
        let rawLines = rawOutput
            .components(separatedBy: "\n")
            .dropFirst() // First line is "List of devices attached"
            .filter { !$0.isEmpty } // Remove newline at end
        
        connectedDeviceSerials = rawLines.compactMap { rawLine in
            let components = rawLine
                .components(separatedBy: " ")
                .filter { !$0.isEmpty }
            guard components.count > 0 else { return nil }
            return components[0]
        }
    }
    
    // MARK: - Default Empty response
    
    static let emptyResponse = DevicesResponse()
    
    private init() {
        connectedDeviceSerials = []
    }
}
