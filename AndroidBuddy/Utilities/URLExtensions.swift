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
    /// Example compatible command:
    /// ```
    /// adb shell ls -lL /sdcard
    /// ```
    ///
    /// For standard adb commands that don't use `shell`, use `URL.pathForADBCommand` instead.
    var pathForShellCommand: String {
        let path = path(percentEncoded: false)
        return "\"\(path)\"" // Need to wrap in quotes
    }
    
    /// Return a path string that is compatible with adb commands that aren't shell
    ///
    /// Example compatible command:
    /// ```
    /// adb pull "/sdcard/Voice Recorder/" /Users/Mark/Downloads
    /// ```
    ///
    /// For `adb shell` commands, use `URL.pathForShellCommand` instead.
    var pathForADBCommand: String {
        return path(percentEncoded: false)
    }
    
    /// Creates a URL where the path is `/`.
    static var shellRoot: URL {
        return URL(string: "/")!
    }
}
