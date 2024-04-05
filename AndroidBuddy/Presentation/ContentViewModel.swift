//
//  ContentViewModel.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 2/4/2024.
//

import Foundation
import Combine

@MainActor
class ContentViewModel: ObservableObject {
    
    @Published var currentPath: URL = URL(string: "/")!
    @Published var items: [DirectoryView.Item] = []
    @Published var backButtonEnabled: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $currentPath
            .sink(receiveValue: { [weak self] _ in
                guard let self else { return }
                self.refreshItems()
            })
            .store(in: &cancellables)
        
        $currentPath
            .map { $0.pathComponents.count > 1 }
            .assign(to: \.backButtonEnabled, on: self)
            .store(in: &cancellables)
        
        AdbService.shared
            .deviceCountChanged
            .sink(
                receiveCompletion: { error in
                    fatalError("Device count publisher got error: \(error)")
                },
                receiveValue: { [weak self] in
                    print("Test for now. TODO: Move this somewhere else...")
                    guard let self else { return }
                    refreshItems()
                }
            )
            .store(in: &cancellables)
    }
    
    func refreshItems() {
        Task {
            items = await getItems(path: currentPath)
        }
    }
    
    private func getItems(path: URL) async -> [DirectoryView.Item] {
        let response = try! await AdbService.shared.listCommand(path: path)
        
        return response.items.map { responseItem in
//            let indentationLevel = response.path.pathComponents.count - 1
//            let sanitisedIndentationLevel = max(0, indentationLevel)
            
            let itemType: DirectoryView.Item.ItemType = switch responseItem.fileType {
            case .directory: .directory
            case .file: .file
            case .symlink: .directory
            }
            
            return DirectoryView.Item(
                path: responseItem.path,
                name: responseItem.name,
                isSymlink: responseItem.fileType == .symlink,
                indentationLevel: 0, //sanitisedIndentationLevel, // TODO: Add back in if I ever decide to have vertical list view
                type: itemType
            )
        }
    }
    
    func downloadFile(remotePath: URL) {
        Task {
            print("Downloading file...")
            try! await AdbService.shared.pullCommand(remotePath: remotePath)
            print("...file downloaded (or failed...)!")
        }
    }
    
    func uploadFile(localPath: URL) {
        Task {
            print("Uploading file...")
            try! await AdbService.shared.pushCommand(localPath: localPath, remotePath: currentPath)
            print("...file uploaded (or failed...)!")
            refreshItems()
        }
    }
    
    func back() {
        guard backButtonEnabled else { return }
        currentPath = currentPath.deletingLastPathComponent()
    }
}
