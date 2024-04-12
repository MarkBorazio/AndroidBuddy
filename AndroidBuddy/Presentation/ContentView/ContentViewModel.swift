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
    
    @Published var viewState: ViewState = .loading
    @Published var title: String = ""
    @Published var currentDeviceSerial: String? = nil
    @Published var allDevices: [Device] = []
    @Published var items: [DirectoryView.Item] = []
    @Published var backButtonEnabled: Bool = false
    @Published private var currentPath: URL = URL(string: "/")!
    
    var currentDevice: Device? {
        guard let currentDeviceSerial else { return nil }
        return allDevices.first { $0.serial == currentDeviceSerial }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    
    init() {
        
        AdbService.shared.state
            .map { state -> ViewState in
                return switch state {
                case .notRunning, .settingUp: .loading
                case .running: .loaded
                case .error: .error
                }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$viewState)

        $currentPath
            .receive(on: DispatchQueue.main)
            .sink { [weak self] path in
                guard let self else { return }
                refreshItems()
                backButtonEnabled = path.pathComponents.count > 1
            }
            .store(in: &cancellables)
        
        $currentPath
            .map {
                $0.path(percentEncoded: false)
                    .replacingOccurrences(of: "/", with: " / ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .assign(to: &$title)
        
        AdbService.shared
            .connectedDevices
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                guard let self else { return }
                allDevices = devices
                if currentDevice == nil {
                    currentDeviceSerial = devices.first?.serial
                }
            }
            .store(in: &cancellables)
        
        $currentDeviceSerial
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                currentPath = URL(string: "/")!
            }
            .store(in: &cancellables)
    }
    
    func refreshItems() {
        Task {
            items = await getItems(path: currentPath)
        }
    }
    
    private func getItems(path: URL) async -> [DirectoryView.Item] {
        guard let currentDevice else {
            return []
        }
        let response = try! await ADB.list(serial: currentDevice.serial, path: path)
        
        return response.items.map { responseItem in
            let itemType: DirectoryView.Item.ItemType = switch responseItem.fileType {
            case .directory: .directory
            case .file: .file
            case .symlink: .directory
            }
            
            return DirectoryView.Item(
                path: responseItem.path,
                name: responseItem.name,
                isSymlink: responseItem.fileType == .symlink,
                type: itemType
            )
        }
    }
    
    func downloadFile(remotePath: URL) {
        guard let currentDevice else {
            print("Tried to download file when no serial was selected")
            return
        }
        Task {
            print("Downloading file...")
            try! await ADB.pull(serial: currentDevice.serial, remotePath: remotePath)
            print("...file downloaded (or failed...)!")
        }
    }
    
    func uploadFile(localPath: URL) {
        guard let currentDevice else {
            print("Tried to upload file when no serial was selected")
            return
        }
        Task {
            print("Uploading file...")
            try! await ADB.push(serial: currentDevice.serial, localPath: localPath, remotePath: currentPath)
            print("...file uploaded (or failed...)!")
            refreshItems()
        }
    }
    
    func deleteFile(remotePath: URL) {
        guard let currentDevice else {
            print("Tried to delete file when no serial was selected")
            return
        }
        print("Deleting file at \(remotePath.path())")
        Task {
            print("Deleting file...")
            try! await ADB.delete(serial: currentDevice.serial, remotePath: remotePath)
            print("...file deleted (or failed...)!")
            refreshItems()
        }
    }
    
    func back() {
        guard backButtonEnabled else { return }
        currentPath = currentPath.deletingLastPathComponent()
    }
    
    func navigateToDirectory(path: URL) {
        currentPath = path
    }
    
    enum ViewState {
        case loading
        case loaded
        case error
    }
}
