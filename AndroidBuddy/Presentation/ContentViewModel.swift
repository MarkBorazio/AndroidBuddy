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
            .asyncMap { [weak self] path in
                guard let self else { return [] }
                return await self.getItems(path: path)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.items, on: self)
            .store(in: &cancellables)
        
        $currentPath
            .map { $0.pathComponents.count > 1 }
            .assign(to: \.backButtonEnabled, on: self)
            .store(in: &cancellables)
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
            items = await getItems(path: currentPath)
        }
    }
    
    func back() {
        guard backButtonEnabled else { return }
        currentPath = currentPath.deletingLastPathComponent()
    }
}
