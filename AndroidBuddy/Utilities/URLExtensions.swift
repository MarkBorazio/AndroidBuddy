//
//  URLExtensions.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 6/4/2024.
//

import Foundation

extension URL {
    
    /// Return a path string that is compatible with adb shell
    ///
    /// Example command:
    /// ```
    /// adb -s R5CT638F8ST shell ls -lL /sdcard
    /// ```
    ///
    /// For standard adb commands that don't use `shell`, use `URL.pathForADBCommand` instead.
    var pathForShellCommand: String {
        return path(percentEncoded: false)
            .replacingOccurrences(of: " ", with: "\\ ") // Escape spaces
    }
    
    /// Return a path string that is compatible with adb commands that aren't shell
    ///
    /// Example command:
    /// ```
    /// adb pull "/sdcard/Voice Recorder/" /Users/Mark/Downloads
    /// ```
    ///
    /// For `adb shell` commands, use `URL.pathForShellCommand` instead.
    var pathForADBCommand: String {
        return path(percentEncoded: false)
    }
}
