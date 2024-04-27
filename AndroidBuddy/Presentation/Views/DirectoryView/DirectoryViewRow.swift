//
//  DirectoryViewRow.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 27/4/2024.
//

import SwiftUI

struct DirectoryViewRow: View {
    
    struct Item: Identifiable {
        
        // Based on assumption that two things can't have same path in unix TODO: I think the assumption is wrong - double check it.
        var id: URL { path }
        
        let path: URL
        let name: String
        let isSymlink: Bool
        let type: ItemType
        
        enum ItemType {
            case file
            case directory
        }
    }
    
    let item: Item
    @FocusState.Binding var renamableIdFocus: Item.ID?
    var onRename: (String) -> Void
    @State private var renamableText: String = ""
    
    private var isRenaming: Bool {
        item.id == renamableIdFocus
    }
    
    private var textFieldBinding: Binding<String> {
        isRenaming ? $renamableText : .constant(item.name)
    }
    
    var body: some View {
        Label(
            title: {
                ZStack(alignment: .leading) {
                    Text(item.name)
                        .opacity(isRenaming ? 0 : 1)
                    
                    TextField("", text: $renamableText)
                        .focused($renamableIdFocus, equals: item.id)
                        .onExitCommand {
                            renamableIdFocus = nil
                        }
                        .onSubmit {
                            submit()
                        }
                        .opacity(isRenaming ? 1 : 0)
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
    
    private static func getSymbol(for type: Item.ItemType) -> some View {
        let image: some View = switch type {
        case .file: Image(systemName: "doc.fill").foregroundStyle(Color.primary)
        case .directory: Image(systemName: "folder.fill").foregroundStyle(Color.mint)
        }
        return image.frame(width: 20, height: 20)
    }
}

#Preview {
    DirectoryViewRow(
        item: .init(
            path: URL(string: "/sdcard/roms")!,
            name: "Roms",
            isSymlink: false,
            type: .directory
        ),
        renamableIdFocus: FocusState().projectedValue,
        onRename: { _ in }
    )
}
