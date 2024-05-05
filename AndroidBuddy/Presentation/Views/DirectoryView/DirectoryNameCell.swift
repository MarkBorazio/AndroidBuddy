//
//  DirectoryNameCell.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 27/4/2024.
//

import SwiftUI

struct DirectoryNameCell: View {
    
    let item: DirectoryItem
    @FocusState.Binding var renamableIdFocus: DirectoryItem.ID?
    var onRename: (String) -> Void
    @State private var renamableText: String = ""
    
    private var isRenaming: Bool {
        item.id == renamableIdFocus
    }
    
    var body: some View {
        labelView
            .frame(height: 20)
            .contentShape(Rectangle())
            .onChange(of: renamableIdFocus) { value in
                renamableText = item.name
            }
    }
    
    private var labelView: some View {
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
    }
    
    private func submit() {
        if renamableText != item.name && !renamableText.isEmpty {
            onRename(renamableText)
        }
        renamableIdFocus = nil
    }
    
    private static func getSymbol(for type: DirectoryItem.ItemType) -> some View {
        let image: some View = switch type {
        case .file: 
            Image(systemName: "doc.fill")
                .foregroundStyle(Gradient(colors: [Color.primary]))
        case .directory: 
            Image(systemName: "folder.fill")
                .foregroundStyle(Gradient(colors: [
                    Color(red: 132/255, green: 214/255, blue: 252/255),
                    Color(red: 111/255, green: 187/255, blue: 247/255)
                ]))
        }
        return image.frame(width: 20, height: 20)
    }
}

#Preview {
    DirectoryNameCell(
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
