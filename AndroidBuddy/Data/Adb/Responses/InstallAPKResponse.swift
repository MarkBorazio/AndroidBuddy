//
//  InstallAPKResponse.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 29/4/2024.
//

import Foundation

/// Response parser for the `install -r <localFilePath>` command.
///
/// # Example outputs from ADB
/// ## Progress Update
/// ```
/// Performing Streamed Install
/// ```
/// ## Transfer Completion
/// ```
/// Success
/// ```
struct InstallAPKResponse: Equatable {
    
    enum Progress: Equatable {
        case inProgress // Percentage is not provided
        case completed
    }
    
    let progress: Progress
    
    init(rawOutput: String) throws {
        
        let sanitisedOutput = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitisedOutput == "Performing Streamed Install" {
            progress = .inProgress
        } else if sanitisedOutput == "Success" {
            progress = .completed
        } else {
            throw ADB.AdbError.responseParseError
        }
    }
}
