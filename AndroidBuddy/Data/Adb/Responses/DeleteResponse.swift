//
//  DeleteResponse.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 28/4/2024.
//

import Foundation

/// Response for the `adb shell rm [-f|-rf] <path>` command
///
/// - Use `-f` when deleting a file.
/// - Use `-rf` when deleting a folder.
///
/// # Example Outputs
/// ## Success Output
/// Nothing is printed when the move is successful.
///
/// ## Trying to delete a directory with `-f`
/// ```
/// rm: sdcard/roms: Is a directory
/// ```
struct DeleteResponse {
    
    static func checkForErrors(rawOutput: String) throws {
        if !rawOutput.isEmpty {
            throw ADB.AdbError.commandError(output: rawOutput)
        }
    }
}
