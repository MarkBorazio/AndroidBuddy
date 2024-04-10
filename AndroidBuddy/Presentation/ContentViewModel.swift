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
    
    @Published var currentDeviceSerial: String? = nil
    @Published var allDeviceSerials: [String] = []
    @Published var currentPath: URL = URL(string: "/")!
    @Published var items: [DirectoryView.Item] = []
    @Published var backButtonEnabled: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $currentPath
            .receive(on: DispatchQueue.main)
            .sink { [weak self] path in
                guard let self else { return }
                refreshItems()
                backButtonEnabled = path.pathComponents.count > 1
            }
            .store(in: &cancellables)
        
        AdbService.shared
            .connectedDevices
            .map(\.connectedDeviceSerials)
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                guard let self else { return }
                allDeviceSerials = devices
                if currentDeviceSerial == nil {
                    currentDeviceSerial = devices.first
                }
            }
            .store(in: &cancellables)
        
        $currentDeviceSerial
            .removeDuplicates()
            .sink { [weak self] serial in
                guard let self else { return }
                currentPath = URL(string: "/")!
                refreshItems() // TODO: Reconsider this... The same thing happens when currentPath changes...
            }
            .store(in: &cancellables)
        
        // TODO: Move elsewhere...
        AdbService.shared
            .connectedDevices
            .sink(
                receiveCompletion: { error in
                    fatalError("Device count publisher got error: \(error)")
                },
                receiveValue: { [weak self] _ in
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
        guard let currentDeviceSerial else {
            return []
        }
        let response = try! await ADB.list(serial: currentDeviceSerial, path: path)
        
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
        guard let currentDeviceSerial else {
            print("Tried to download file when no serial was selected")
            return
        }
        Task {
            print("Downloading file...")
            try! await ADB.pull(serial: currentDeviceSerial, remotePath: remotePath)
            print("...file downloaded (or failed...)!")
        }
    }
    
    func uploadFile(localPath: URL) {
        guard let currentDeviceSerial else {
            print("Tried to upload file when no serial was selected")
            return
        }
        Task {
            print("Uploading file...")
            try! await ADB.push(serial: currentDeviceSerial, localPath: localPath, remotePath: currentPath)
            print("...file uploaded (or failed...)!")
            refreshItems()
        }
    }
    
    func deleteFile(remotePath: URL) {
        guard let currentDeviceSerial else {
            print("Tried to delete file when no serial was selected")
            return
        }
        print("Deleting file at \(remotePath.path())")
        Task {
            print("Deleting file...")
            try! await ADB.delete(serial: currentDeviceSerial, remotePath: remotePath)
            print("...file deleted (or failed...)!")
            refreshItems()
        }
    }
    
    func back() {
        guard backButtonEnabled else { return }
        currentPath = currentPath.deletingLastPathComponent()
    }
}
