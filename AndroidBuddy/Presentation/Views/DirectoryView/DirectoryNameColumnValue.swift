//
//  DirectoryNameColumnValue.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 27/4/2024.
//

import SwiftUI

struct DirectoryNameColumnValue: View {
    
    let item: DirectoryView.Item
    @FocusState.Binding var renamableIdFocus: DirectoryView.Item.ID?
    var onRename: (String) -> Void
    @State private var renamableText: String = ""
    
    private var isRenaming: Bool {
        item.id == renamableIdFocus
    }
    
    var body: some View {
        Label(
            title: {
                ZStack(alignment: .leading) {
                    Text(item.name)
                        .opacity(isRenaming ? 0 : 1) // Hide when renaming
                    
                    TextField("", text: $renamableText)
                        .focused($renamableIdFocus, equals: item.id)
                        .onExitCommand {
                            renamableIdFocus = nil
                        }
                        .onSubmit {
                            submit()
                        }
                        .opacity(isRenaming ? 1 : 0) // Hide when not renaming
                }
            },
            icon: {
                Self.getSymbol(for: item.type)
            }
        )
        .onChange(of: renamableIdFocus) { value in
            renamableText = item.name
        }
    }
    
    private func submit() {
        if renamableText != item.name && !renamableText.isEmpty {
            onRename(renamableText)
        }
        renamableIdFocus = nil
    }
    
    private static func getSymbol(for type: DirectoryView.Item.ItemType) -> some View {
        let image: some View = switch type {
        case .file: Image(systemName: "doc.fill").foregroundStyle(Color.primary)
        case .directory: Image(systemName: "folder.fill").foregroundStyle(Color.mint)
        }
        return image.frame(width: 20, height: 20)
    }
}

#Preview {
    DirectoryNameColumnValue(
        item: .init(
            path: URL(string: "/sdcard/roms")!,
            name: "Roms",
            dateModified: "29 April, 2024 at 4:11 am",
            size: "24.9 MB",
            isSymlink: false,
            type: .directory
        ),
        renamableIdFocus: FocusState().projectedValue,
        onRename: { _ in }
    )
}
