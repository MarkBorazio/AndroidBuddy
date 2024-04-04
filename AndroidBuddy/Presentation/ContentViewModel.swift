//
//  ContentViewModel.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 2/4/2024.
//

import Foundation
import Combine

class ContentViewModel: ObservableObject {
    
    @Published var currentPath: URL = URL(string: "/")!
    @Published var items: [DirectoryView.Item] = []
    @Published var backButtonEnabled: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $currentPath
            .map { [weak self] path -> [DirectoryView.Item] in
                guard let self else { return [] }
                return self.getItems(path: path)
            }
            .assign(to: \.items, on: self)
            .store(in: &cancellables)
        
        $currentPath
            .map { $0.pathComponents.count > 1 }
            .assign(to: \.backButtonEnabled, on: self)
            .store(in: &cancellables)
    }
    
    func getItems(path: URL) -> [DirectoryView.Item] {
        let response = try! AdbService.shared.listCommand(path: path)
        
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
        try! AdbService.shared.pullCommand(remotePath: remotePath)
    }
    
    func uploadFile(localPath: URL) {
        print("Uploading file...")
        try! AdbService.shared.pushCommand(localPath: localPath, remotePath: currentPath)
        print("...file uploaded (or failed...)!")
    }
    
    func back() {
        guard backButtonEnabled else { return }
        currentPath = currentPath.deletingLastPathComponent()
    }
}
