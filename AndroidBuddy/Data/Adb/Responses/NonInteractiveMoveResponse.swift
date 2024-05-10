//
//  NonInteractiveMoveResponse.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 27/4/2024.
//

import Foundation

/// Response for the `adb shell mv <source> <destination>` command
///
/// - If the destination is a directory that already exists, the source will be moved to inside of the destination directory.
/// - If the destination does not exist, the source will have it's path changed to the destination path.
///
/// # Example Outputs
/// ## Success Output
/// Nothing is printed when the move is successful.
///
/// ## Destination is an existing file:
/// ```
/// mv: Donkey Kong Jungle Beat (USA).iso: Read-only file system
/// ```
struct NonInteractiveMoveResponse {
    
    static func checkForErrors(rawOutput: String) throws {
        if !rawOutput.isEmpty {
            throw ADB.AdbError.commandError(output: rawOutput)
        }
    }
}
