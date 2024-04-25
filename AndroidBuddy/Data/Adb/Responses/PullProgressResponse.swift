//
//  PullProgressResponse.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 21/4/2024.
//

import Foundation

/// Response for the `pull <remote> <local>` command
///
/// # Example Outputs
/// Progress Update:
/// ```
/// [ 39%] /sdcard/Roms/Gamecube/Super Mario Strikers.iso
/// ```
/// Transfer completion:
/// ```
/// /sdcard/Roms/Gamecube/Super Mario Strikers.iso: 1 file pulled, 0 skipped. 35.9 MB/s (1459978240 bytes in 38.753s)
/// ```
struct PullProgressResponse: Equatable {
    
    enum Progress: Equatable {
        case inProgress(percentage: Double)
        case completed
    }
    
    let progress: Progress
    
    init(rawOutput: String) throws {
        
        if rawOutput.hasPrefix("[") {
            let lowerBound = rawOutput.index(rawOutput.startIndex, offsetBy: 1)
            let upperBound = rawOutput.index(rawOutput.startIndex, offsetBy: 3)
            let range = lowerBound...upperBound
            
            let percentageString = String(rawOutput[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let percentageInt = Int(percentageString) else {
                throw ADB.AdbError.responseParseError
            }
            
            if percentageInt >= 100 {
                progress = .completed
            } else {
                let percentageDouble = Double(percentageInt) / 100
                progress = .inProgress(percentage: percentageDouble)
            }
        } else {
            // Should be safe to assume that this is the completion line being printed
            progress = .completed
        }
    }
}
