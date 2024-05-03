//
//  BluetoothNameResponse.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 4/5/2024.
//

import Foundation

/// Response parser for the very specific`adb shell dumpsys bluetooth_manager | grep 'name:' | cut -c9-` command.
///
/// # Discussion
/// This is usually what the phone's name is that is set in the settings. As far as I can tell, the only way to grab it is to call `dumpsys bluetooth_manager`.
/// The command that gets run autmotically searches for the Bluetooth name field.
/// I am assuming it is possible that there can be no name (maybe the device doesn't support Bluetooth) and that we would receive a blank response, in which case the output gets parsed and `nil` is returned.
///
/// # Example output from ADB
/// ```
/// Mark's Phone
/// ```
enum BluetoothNameResponse {
    
    static func extractName(_ rawOutput: String) -> String? {
        let sanitisedOutput = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitisedOutput.isEmpty ? nil : sanitisedOutput
    }
}
