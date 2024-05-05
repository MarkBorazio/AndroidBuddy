//
//  DirectoryItem.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 6/5/2024.
//

import SwiftUI
import UniformTypeIdentifiers

/// Represents an item in a directory (ie: Folder, File, or Symlink)
struct DirectoryItem: Identifiable, Codable {
    
    // Based on assumption that two things can't have same path in unix TODO: I think the assumption is wrong - double check it.
    var id: URL { path }
    
    let path: URL
    let name: String
    let dateModified: String
    let size: String
    let isSymlink: Bool
    let type: ItemType
    
    enum ItemType: Codable {
        case file
        case directory
    }
}

// This exists so that a view can receive multiple items in one drop.
struct TransferableDirectoryItems: Codable, Transferable {
    let items: [DirectoryItem]
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .transferableDirectoryItem)
    }
}

extension UTType {
    static var transferableDirectoryItem: UTType { UTType(exportedAs: "com.androidBuddy.transferableDirectoryItem") }
}
