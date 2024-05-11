//
//  DirectoryView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 2/4/2024.
//

import SwiftUI

struct DirectoryView: View {
    
    @EnvironmentObject private var viewModel: ContentViewModel
    @State private var selectedItemIds: Set<DirectoryItem.ID> = []
    @FocusState private var renamableIdFocus: DirectoryItem.ID?
    @State private var hoveredItemId: DirectoryItem.ID?
    
    var body: some View {
        ScrollViewReader { proxy in
            Table(
                of: DirectoryItem.self,
                selection: $selectedItemIds,
                columns: {
                    TableColumn("Name") { item in
                        nameCell(item)
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
                },
                rows: {
                    ForEach(viewModel.items) { item in
                        TableRow(item)
                    }
                }
            )
            .contextMenu(
                forSelectionType: DirectoryItem.ID.self,
                menu: rightClickMenu,
                primaryAction: doubleClickHandler
            )
            .contextMenu { // When right clicking part of table that isn't an item
                Button("Create New Folder") {
                    viewModel.createNewFolder()
                }
            }
            .onChange(of: viewModel.currentDeviceSerial) { _ in
                onItemReload(proxy: proxy)
            }
            .onChange(of: viewModel.currentPath) { _ in
                onItemReload(proxy: proxy)
            }
        }
    }
    
    // There's a bit of bullshit going on here with the dragging.
    // There seems to be no good way to make use of the built-in selection and highlighting
    // that Table offers, and also have things be draggable at the same time.
    // To get around this, items are only draggable only when they are selected.
    // If we ever update to MacOS 14, we can apply the draggable and dropDestination methods
    // to the TableRow directly instead of just on this view.
    // Also, forget about making things draggable to other apps like Finder; that requires
    // implementation of the NSFilePromiseProviderDelegate which isn't supported by SwiftUI.
    // Implementing it with a UIView wrapper would mess with the other gestures.
    private func nameCell(_ item: DirectoryItem) -> some View {
        DirectoryNameCell(
            item: item,
            renamableIdFocus: $renamableIdFocus,
            onRename: { newName in
                viewModel.rename(remoteSource: item.path, newName: newName)
                selectedItemIds = []
            }
        )
        .border(hoveredItemId == item.id ? Color.accentColor : Color.clear, width: 1)
        .id(item.name)
        .if(selectedItemIds.contains(item.id)) { view in
            view.draggable(draggableItems(item: item))
        }
        .if(item.type == .directory) { view in
            view.dropDestination(
                for: TransferableDirectoryItems.self,
                action: { transferableItemsArray, location in
                    guard
                        transferableItemsArray.count == 1,
                        let transferableItems = transferableItemsArray.first,
                        !transferableItems.items.contains(where: { $0.id == item.id }), // Don't want to move folder to self
                        item.type == .directory
                    else {
                        return false
                    }
                    
                    let paths = transferableItems.items.map(\.path)
                    viewModel.move(sourceDeviceSerial: transferableItems.sourceDeviceSerial, remoteSources: paths, remoteDestination: item.path)
                    return true
                },
                isTargeted: { isTargeted in
                    hoveredItemId = isTargeted ? item.id : nil
                }
            )
        }
    }
    
    private func onItemReload(proxy: ScrollViewProxy) {
        selectedItemIds = []
        if let firstId = viewModel.items.first?.id {
            proxy.scrollTo(firstId)
        }
    }
    
    @ViewBuilder
    private func rightClickMenu(selectedItemIds: Set<DirectoryItem.ID>) -> some View {
        if selectedItemIds.isEmpty {
            EmptyView()
        } else {
            let selectedItems = getItemsFromIds(selectedItemIds)
            
            Button("Save to downloads") {
                viewModel.requestFileDownload(remotePaths: selectedItems.map(\.path))
            }
            
            if selectedItems.count == 1, let selectedItem = selectedItems.first {
                Button("Rename") {
                    self.selectedItemIds = [selectedItem.id]
                    renamableIdFocus = selectedItem.id
                }
            }
            
            if viewModel.backButtonEnabled {
                Button("Move to parent") {
                    viewModel.moveToParent(remoteSources: selectedItems.map(\.path))
                }
            }
            
            Button("Delete", role: .destructive) {
                viewModel.requestItemDeletion(items: selectedItems)
            }
        }
    }
    
    private func doubleClickHandler(selectedItemIds: Set<DirectoryItem.ID>) {
        let selectedItems = getItemsFromIds(selectedItemIds)
        if selectedItems.count == 1, let selectedItem = selectedItems.first {
            switch selectedItem.type {
            case .file:
                viewModel.requestFileDownload(remotePaths: [selectedItem.path])
            case .directory:
                viewModel.navigateToDirectory(path: selectedItem.path)
            }
        }
    }
    
    // If attempting to drag an item that is already selected, also drag any other selected items.
    private func draggableItems(item: DirectoryItem) -> TransferableDirectoryItems {
        guard let serial = viewModel.currentDeviceSerial else {
            Logger.error("Current device serial was nil when attempting to create TransferableDirectoryItems.")
            return .init(sourceDeviceSerial: "", items: [])
        }
        let items = if selectedItemIds.contains(item.id) {
            getItemsFromIds(selectedItemIds)
        } else {
            [item]
        }
        return TransferableDirectoryItems(sourceDeviceSerial: serial, items: items)
    }
    
    private func getItemsFromIds(_ ids: Set<DirectoryItem.ID>) -> [DirectoryItem] {
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
