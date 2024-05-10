//
//  InteractiveMoveResponse.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 27/4/2024.
//

import Foundation

/// Response for the `adb shell mv [-i] [-n] <source> <destination>` command
///
/// - If the destination is a directory that already exists, the source will be moved to inside of the destination directory.
/// - If the destination is a file that already exists:
///   - The operation will cancelled if the `-n` flag is specified
///   - A Y/N confirmation will be required if the `-i` flag is specified
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

// TODO: Write correct documentation for above.
struct InteractiveMoveResponse {
    
    enum ResponseType {
        case nothing
        case requestingOverwriteConfirmation(url: URL)
    }
    
    private static let overwriteRequestPrefix = "mv: overwrite "
    private static let overwriteRequestSuffix = " (y/N):"
    
    let type: ResponseType
    
    init(rawOutput: String) throws {
        if rawOutput.isEmpty {
            type = .nothing
        } else if rawOutput.hasPrefix(Self.overwriteRequestPrefix) && rawOutput.hasSuffix(Self.overwriteRequestSuffix) {
            let urlString = rawOutput
                .dropFirst(Self.overwriteRequestPrefix.count)
                .dropLast(Self.overwriteRequestSuffix.count)
                .addingPercentEncoding(withAllowedCharacters: .whitespaces.inverted)
            guard
                let urlString,
                let url = URL(string: String(urlString))
            else {
                throw ADB.AdbError.responseParseError
            }
            type = .requestingOverwriteConfirmation(url: url)
        } else {
            throw ADB.AdbError.commandError(output: rawOutput)
        }
    }
}
