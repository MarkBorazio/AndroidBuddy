//
//  ListCommandResponse.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 1/4/2024.
//

import Foundation

/// Response for the `ls` command
///
/// # Example Output
/// (When run as `ls -l`)
/// ```
/// total 144
/// dr-xr-xr-x   4 root   root          0 1971-04-12 04:10 acct
/// drwxr-xr-x  87 root   root       1800 2024-03-29 22:52 apex
/// -rw-r--r--   1 root   root      54435 2022-01-01 11:00 audit_filter_table
/// lrw-r--r--   1 root   root         11 2022-01-01 11:00 bin -> /system/bin
/// ```
struct ListCommandResponse {
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
    
    let path: URL
    let items: [Item]
    
    init(path: URL, rawResponse: String) throws {
        self.path = path
        
        if rawResponse.hasPrefix("ls:") {
            if rawResponse.contains("No such file or directory") {
                throw ADBServiceError.noSuchFileOrDirectory
            } else {
                throw ADB.AdbError.responseParseError
            }
        }
        
        let rawLines = rawResponse.components(separatedBy: "\n")
            .dropFirst() // First line tells us the total of something (not sure what though)
            .filter { !$0.isEmpty } // Remove newline at end
        
        items = try rawLines.compactMap { try Self.parseRawLine($0, path: path) }
    }
    
    private static func parseRawLine(_ line: String, path: URL) throws -> Item? {
        let components = line.components(separatedBy: " ")
            .filter { !$0.isEmpty }
        
        let permissions = components[0]
        
        /// Handle some kind of unknown case.
        /// The full line looks something like this:
        /// ```
        /// d?????????   ? ?      ?             ?                ? data_mirror
        /// ```
        if permissions.contains("?") {
            return nil
        }
        
        let rawFileType = permissions.first
        let fileType: Item.FileType
        switch rawFileType {
        case "d": fileType = .directory
        case "-": fileType = .file
        case "l": fileType = .symlink
        default:
            return nil
        }
        
        
        guard 
            components.count >= 8,
            let numberOfLinks = Int(components[1]),
            let size = Int(components[4])
        else {
            throw ADB.AdbError.responseParseError
        }
            
        let owner = components[2]
        let group = components[3]
        let date = components[5]
        let time = components[6]
        let name = components[7..<components.count].joined(separator: " ") // TODO: Figure out how to properly parse name... We probably will need to do a second command here...
        
        guard let dateTime = Self.dateFormatter.date(from: "\(date) \(time)") else {
            throw ADB.AdbError.responseParseError
        }
        
        return Item(
            path: path.appending(path: name),
            name: name,
            permissions: permissions,
            numberOfLinks: numberOfLinks,
            owner: owner,
            group: group,
            size: size,
            lastModifiedDate: dateTime,
            fileType: fileType
        )
    }
    
    struct Item {
        let path: URL
        let name: String
        let permissions: String
        let numberOfLinks: Int
        let owner: String
        let group: String
        let size: Int
        let lastModifiedDate: Date
        let fileType: FileType
        
        enum FileType {
            case file
            case directory
            case symlink // TODO: Add resolved path here (will probably need to run `readlink -f <path>`)
        }
    }
}
