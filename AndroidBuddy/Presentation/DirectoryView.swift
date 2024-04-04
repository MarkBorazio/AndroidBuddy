//
//  DirectoryView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 2/4/2024.
//

import SwiftUI

struct DirectoryView: View {
    
    struct Item: Identifiable {
        
        var id: URL { path } // Based on assumption that two things can't have same path in unix
        
        let path: URL
        let name: String
        let isSymlink: Bool
        let indentationLevel: Int
        let type: ItemType
        
        enum ItemType {
            case file
            case directory
        }
    }
    
    @EnvironmentObject var viewModel: ContentViewModel
    @State var selection: Set<DirectoryView.Item.ID> = []
    
    var body: some View {
        Table(viewModel.items, selection: $selection) {
            TableColumn("Name") { item in
                HStack {
                    Spacer().frame(width: 20 * CGFloat(item.indentationLevel))
                    Label(
                        title: { Text(item.name) },
                        icon: { Self.getSymbol(type: item.type) }
                    )
                }
            }
        }
        .contextMenu(forSelectionType: DirectoryView.Item.ID.self) { items in
            if items.count == 1 { // Single item menu.
                Button("Copy") { }
                Button("Delete", role: .destructive) { }
            } else { // Multi-item menu.
                Button("Copy") { }
                Button("New Folder With Selection") { }
                Button("Delete Selected", role: .destructive) { }
            }
        } primaryAction: { selectedItemIds in
            // This is executed when the row is double clicked
            if 
                selectedItemIds.count == 1,
                let selectedId = selectedItemIds.first,
                let selectedItem = viewModel.items.first(where: { $0.id == selectedId })
            {
                switch selectedItem.type {
                case .file:
                    viewModel.downloadFile(remotePath: selectedItem.path)
                case .directory:
                    viewModel.currentPath = selectedItem.path
                }
            }
        }
    }
    
    private static func getSymbol(type: Item.ItemType) -> Image {
        let name = switch type {
        case .file: "doc.fill"
        case .directory: "folder.fill"
        }
        return Image(systemName: name)
    }
}

#Preview {
    return DirectoryView()
        .environmentObject(ContentViewModel())
}
