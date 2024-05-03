//
//  DirectoryView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 2/4/2024.
//

import SwiftUI

struct DirectoryView: View {
    
    struct Item: Identifiable {
        
        // Based on assumption that two things can't have same path in unix TODO: I think the assumption is wrong - double check it.
        var id: URL { path }
        
        let path: URL
        let name: String
        let dateModified: String
        let size: String
        let isSymlink: Bool
        let type: ItemType
        
        enum ItemType {
            case file
            case directory
        }
    }
    
    @EnvironmentObject private var viewModel: ContentViewModel
    @State private var selection: Set<Item.ID> = []
    @FocusState private var renamableIdFocus: Item.ID?
    
    var body: some View {
        Table(viewModel.items, selection: $selection) {
            TableColumn("Name") { item in
                DirectoryNameColumnValue(
                    item: item,
                    renamableIdFocus: $renamableIdFocus,
                    onRename: { newName in
                        viewModel.rename(remoteSource: item.path, newName: newName)
                        selection = []
                    }
                )
            }
            .width(min: 200)
            
            TableColumn(
                Text("Date Modified")
                    .foregroundColor(.secondary)
            ) { item in
                Text(item.dateModified)
                    .foregroundStyle(Color.secondary)
            }
            .width(170)

            
            TableColumn(
                Text("Size")
                    .foregroundColor(.secondary)
            ) { item in
                HStack {
                    Spacer()
                    Text(item.size)
                        .foregroundStyle(Color.secondary)
                }
            }
            .width(90)
        }
        .contextMenu(
            forSelectionType: Item.ID.self,
            menu: rightClickMenu,
            primaryAction: doubleClickHandler
        )
    }
    
    @ViewBuilder
    private func rightClickMenu(selectedItemIds: Set<Item.ID>) -> some View {
        if selectedItemIds.isEmpty {
            EmptyView()
        } else {
            let selectedItems = getItemsFromIds(selectedItemIds)
            if selectedItems.count == 1, let selectedItem = selectedItems.first { // Single item menu.
                Button("Save to downloads") {
                    viewModel.requestFileDownload(remotePath: selectedItem.path)
                }
                Button("Rename") {
                    selection = [selectedItem.id]
                    renamableIdFocus = selectedItem.id
                }
                Button("Delete", role: .destructive) {
                    viewModel.requestItemDeletion(item: selectedItem)
                }
            } else { // Multi-item menu.
                Button("Delete Selected", role: .destructive) { }
                Button("Save to downloads") {}
            }
        }
    }
    
    private func doubleClickHandler(selectedItemIds: Set<Item.ID>) {
        let selectedItems = getItemsFromIds(selectedItemIds)
        if selectedItems.count == 1, let selectedItem = selectedItems.first {
            switch selectedItem.type {
            case .file:
                viewModel.requestFileDownload(remotePath: selectedItem.path)
            case .directory:
                viewModel.navigateToDirectory(path: selectedItem.path)
            }
        }
    }
    
    private func getItemsFromIds(_ ids: Set<Item.ID>) -> [Item] {
        ids.flatMap { id in
            viewModel.items.filter { $0.id == id }
        }
    }
}

#Preview {
    DirectoryView()
        .environmentObject(ContentViewModel(adbService: MockAdbService(
            adbState: .running,
            connectedDevices: (0...10).map {
                .init(bluetoothName: "Device \($0)", serial: "\($0)")
            }
        )))
}
