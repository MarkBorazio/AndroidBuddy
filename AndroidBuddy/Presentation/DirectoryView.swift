//
//  DirectoryView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 2/4/2024.
//

import SwiftUI

struct DirectoryView: View {
    
    @Environment(\.openWindow) private var openWindow
    
    struct Item: Identifiable {
        
        var id: URL { path } // Based on assumption that two things can't have same path in unix TODO: I think the assumption is wrong - double check it.
        
        let path: URL
        let name: String
        let isSymlink: Bool
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
                Label(
                    title: { Text(item.name) },
                    icon: { Self.getSymbol(for: item.type) }
                )
            }
        }
        .contextMenu(forSelectionType: DirectoryView.Item.ID.self) { selectedItemIds in
            let selectedItems = getItemsFromIds(selectedItemIds)
            if selectedItems.count == 1, let selectedItem = selectedItems.first { // Single item menu.
                Button("Delete", role: .destructive) {
                    viewModel.deleteFile(remotePath: selectedItem.path)
                }
                Button("Save to downloads") {
                    openFileTransferWindow(remoteUrl: selectedItem.path, action: .download)
                }
            } else { // Multi-item menu.
                Button("Delete Selected", role: .destructive) { }
                Button("Save to downloads") {}
            }
        } primaryAction: { selectedItemIds in
            // This is executed when the row is double clicked
            let selectedItems = getItemsFromIds(selectedItemIds)
            if selectedItems.count == 1, let selectedItem = selectedItems.first {
                switch selectedItem.type {
                case .file:
                    openFileTransferWindow(remoteUrl: selectedItem.path, action: .download)
                case .directory:
                    viewModel.navigateToDirectory(path: selectedItem.path)
                }
            }
        }
    }
    
    private func getItemsFromIds(_ ids: Set<DirectoryView.Item.ID>) -> [DirectoryView.Item] {
        ids.flatMap { id in
            viewModel.items.filter { $0.id == id }
        }
    }
    
    private static func getSymbol(for type: Item.ItemType) -> some View {
        let image: some View = switch type {
        case .file: Image(systemName: "doc.fill").foregroundStyle(Color.primary)
        case .directory: Image(systemName: "folder.fill").foregroundStyle(Color.mint)
        }
        
        return image.frame(width: 20, height: 20)
    }
    
    private func openFileTransferWindow(remoteUrl: URL, action: FileTransferProgressViewModel.Action) {
        guard let currentSerial = viewModel.currentDeviceSerial else {
            Logger.error("Attempted to open transfer file window when no serial was selected.")
            return
        }
        openWindow(value: FileTransferProgressViewModel.Model(
            action: action,
            serial: currentSerial,
            remoteUrl: remoteUrl
        ))
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
