//
//  FileTransferResponse.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 21/4/2024.
//

import Foundation

/// Response parser for the `pull <remote> <local>` command and the `push <local> <remote>` command.
///
/// # Example outputs from ADB
/// ## Progress Update (Pull):
/// ```
/// [ 39%] /sdcard/Roms/Gamecube/Super Mario Strikers.iso
/// ```
/// ## Transfer completion (Pull):
/// ```
/// /sdcard/Roms/Gamecube/Super Mario Strikers.iso: 1 file pulled, 0 skipped. 35.9 MB/s (1459978240 bytes in 38.753s)
/// ```
/// ## Progress Update (Push):
/// ```
/// [ 10%] sdcard/roms/Gamecube/F-Zero GX (USA).iso
/// ```
/// ## Transfer completion (Push):
/// ```
/// /Users/Mark/Downloads/F-Zero GX (USA).iso: 1 file pushed, 0 skipped. 33.4 MB/s (1459978240 bytes in 41.748s)s
/// ```
struct FileTransferResponse: Equatable {
    
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
