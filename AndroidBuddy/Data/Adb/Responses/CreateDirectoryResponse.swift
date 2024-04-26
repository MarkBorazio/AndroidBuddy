//
//  CreateDirectoryResponse.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 27/4/2024.
//

import Foundation

/// Response for the `adb shell mkdir <remote>` command
///
/// # Example Outputs
/// ## Success Output
/// Nothing is printed when the directory is successfully created.
///
/// ## File Already Exists:
/// ```
/// mkdir: 'sdcard/roms/Gamecube': File exists
/// ```
/// ## Directory Does Not Exist:
/// ```
/// mkdir: 'sdcard/roms/nonExistentFolder/anotherFakeFolder': No such file or directory
/// ```
enum CreateDirectoryResponse {
    
    static func checkForErrors(rawOutput: String) throws {
        if !rawOutput.isEmpty {
            throw ADB.AdbError.commandError(output: rawOutput)
        }
    }
}
