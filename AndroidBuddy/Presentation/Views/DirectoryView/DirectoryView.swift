//
//  DirectoryView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 2/4/2024.
//

import SwiftUI

struct DirectoryView: View {
    
    
    @EnvironmentObject private var viewModel: ContentViewModel
    @State private var selection: Set<DirectoryViewRow.Item.ID> = []
    @FocusState private var renamableIdFocus: DirectoryViewRow.Item.ID?
    
    var body: some View {
        Table(viewModel.items, selection: $selection) {
            TableColumn("Name") { item in
                DirectoryViewRow(
                    item: item,
                    renamableIdFocus: $renamableIdFocus,
                    onRename: { newName in
                        viewModel.rename(remoteSource: item.path, newName: newName)
                        selection = []
                    }
                )
            }
        }
        .contextMenu(
            forSelectionType: DirectoryViewRow.Item.ID.self,
            menu: rightClickMenu,
            primaryAction: doubleClickHandler
        )
    }
    
    @ViewBuilder
    private func rightClickMenu(selectedItemIds: Set<DirectoryViewRow.Item.ID>) -> some View {
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
                    viewModel.deleteFile(remotePath: selectedItem.path)
                }
            } else { // Multi-item menu.
                Button("Delete Selected", role: .destructive) { }
                Button("Save to downloads") {}
            }
        }
    }
    
    private func doubleClickHandler(selectedItemIds: Set<DirectoryViewRow.Item.ID>) {
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
    
    private func getItemsFromIds(_ ids: Set<DirectoryViewRow.Item.ID>) -> [DirectoryViewRow.Item] {
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
