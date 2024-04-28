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
    @Published var items: [DirectoryViewRow.Item] = []
    @Published var backButtonEnabled: Bool = false
    @Published var fileTransferModel: FileTransferProgressView.Model? = nil
    @Published var alertModel: AlertModel? = nil
    
    @Published private var currentPath: URL = .shellRoot
    
    
    var currentDevice: Device? {
        guard let currentDeviceSerial else { return nil }
        return allDevices.first { $0.serial == currentDeviceSerial }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var fileTransferCancellable: AnyCancellable? = nil
    private let adbService: ADBService
    
    init(adbService: ADBService) {
        self.adbService = adbService
        
        adbService.state
            .eraseToAnyPublisher()
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
        
        adbService.connectedDevices
            .eraseToAnyPublisher()
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
                currentPath = .shellRoot
            }
            .store(in: &cancellables)
    }
    
    func refreshItems() {
        guard let currentDevice else { return }
        Task {
            do {
                let response = try await adbService.list(serial: currentDevice.serial, path: currentPath)
                items = Self.mapListResponseToItems(response)
            } catch {
                Logger.error("Failed to load directory.", error: error)
                presentErrorAlert(message: "Failed to load directory.") { [weak self] in
                    self?.refreshItems()
                }
            }
        }
    }
    
    private static func mapListResponseToItems(_ response: ListResponse) -> [DirectoryViewRow.Item] {
        return response.items.map { responseItem in
            let itemType: DirectoryViewRow.Item.ItemType = switch responseItem.fileType {
            case .directory: .directory
            case .file: .file
            case .symlink: .directory
            }
            
            return DirectoryViewRow.Item(
                path: responseItem.path,
                name: responseItem.name,
                isSymlink: responseItem.fileType == .symlink,
                type: itemType
            )
        }
    }
    
    func requestFileDownload(remotePath: URL) {
        guard let currentDevice else {
            Logger.error("Tried to download file when no device was selected.")
            return
        }
        
        let localPath = URL(string: "/Users/Mark/Downloads")! // TODO: Choose directory instead of always goind to Downloads folder.
        
        let fileName = remotePath.lastPathComponent
        let potentialLocalPath = localPath.appending(path: fileName)
        let fileExists = FileManager.default.fileExists(atPath: potentialLocalPath.path(percentEncoded: false))
        if fileExists {
            presentDuplicateFileAlert(fileName: fileName) { [weak self] in
                self?.downloadFile(serial: currentDevice.serial, remotePath: remotePath, localPath: localPath)
            }
        } else {
            downloadFile(serial: currentDevice.serial, remotePath: remotePath, localPath: localPath)
        }
    }
    
    private func downloadFile(serial: String, remotePath: URL, localPath: URL) {
        let transferDetails = "\(remotePath.path(percentEncoded: false)) → Downloads"
        
        func updateTransfer(_ percentage: Double) {
            fileTransferModel = .init(
                title: "Downloading...",
                completionPercentage: percentage,
                transferDetails: transferDetails
            )
        }
        
        updateTransfer(0)
        
        fileTransferCancellable = adbService.pull(serial: serial, remotePath: remotePath, localPath: localPath)
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.fileTransferModel = nil
                    switch completion {
                    case .finished:
                        self?.refreshItems()
                    case .failure(_):
                        self?.presentErrorAlert(message: "Download failed") { [weak self] in
                            self?.downloadFile(serial: serial, remotePath: remotePath, localPath: localPath)
                        }
                    }
                },
                receiveValue: { value in
                    switch value.progress {
                    case let .inProgress(percentage):
                        updateTransfer(percentage)
                    case .completed:
                        updateTransfer(1)
                    }
                }
            )
    }
    
    func requestFileUpload(localPath: URL) {
        guard let currentDevice else {
            Logger.error("Tried to upload file when no device was selected.")
            return
        }
        
        Task {
            do {
                let fileName = localPath.lastPathComponent
                let potentialRemotePath = currentPath.appending(path: fileName)
                let fileExists = try await adbService.doesFileExist(serial: currentDevice.serial, remotePath: potentialRemotePath)
                if fileExists {
                    presentDuplicateFileAlert(fileName: fileName) { [weak self] in
                        self?.uploadFile(serial: currentDevice.serial, localPath: localPath)
                    }
                } else {
                    uploadFile(serial: currentDevice.serial, localPath: localPath)
                }
            } catch {
                presentErrorAlert(message: "Failed to upload file.") { [weak self] in
                    self?.requestFileUpload(localPath: localPath)
                }
            }
        }
    }
    
    private func uploadFile(serial: String, localPath: URL) {
        let transferDetails = "\(localPath.path(percentEncoded: false)) → \(currentPath.path(percentEncoded: false))"
        
        func updateTransfer(_ percentage: Double) {
            fileTransferModel = .init(
                title: "Uploading...",
                completionPercentage: percentage,
                transferDetails: transferDetails
            )
        }
        
        updateTransfer(0)
        
        fileTransferCancellable = adbService.push(serial: serial, localPath: localPath, remotePath: currentPath)
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.fileTransferModel = nil
                    switch completion {
                    case .finished:
                        self?.refreshItems()
                    case .failure(_):
                        self?.presentErrorAlert(message: "Upload failed") { [weak self] in
                            self?.uploadFile(serial: serial, localPath: localPath)
                        }
                    }
                },
                receiveValue: { value in
                    switch value.progress {
                    case let .inProgress(percentage):
                        updateTransfer(percentage)
                    case .completed:
                        updateTransfer(1)
                    }
                }
            )
    }
    
    func requestItemDeletion(item: DirectoryViewRow.Item) {
        guard let currentDevice else {
            Logger.error("Tried to delete item when no device was selected.")
            return
        }
        
        presentItemDeletionConfirmationAlert(itemName: item.name) { [weak self] in
            self?.deleteFile(
                serial: currentDevice.serial,
                path: item.path,
                isDirectory: item.type == .directory
            )
        }
    }
    
    func deleteFile(serial: String, path: URL, isDirectory: Bool) {
        Task {
            do {
                try await adbService.delete(
                    serial: serial,
                    remotePath: path,
                    isDirectory: isDirectory
                )
                refreshItems()
            } catch {
                Logger.error("Failed to delete item.", error: error)
                presentErrorAlert(message: "Failed to delete file.") { [weak self] in
                    self?.deleteFile(serial: serial, path: path, isDirectory: isDirectory)
                }
            }
        }
    }
    
    func cancelTransfer() {
        fileTransferCancellable?.cancel()
        fileTransferCancellable = nil
        fileTransferModel = nil
    }
    
    func back() {
        guard backButtonEnabled else { return }
        currentPath = currentPath.deletingLastPathComponent()
    }
    
    func navigateToDirectory(path: URL) {
        currentPath = path
    }
    
    func createNewFolder() {
        guard let currentDevice else {
            Logger.error("Tried to create new folder when no device was selected.")
            return
        }
        
        let folderName = "untitled folder"
        func newDirectory(suffix: Int) -> URL {
            currentPath.appendingPathComponent("\(folderName) \(suffix)")
        }
        
        var remotePath = currentPath.appendingPathComponent(folderName)
        var suffix = 2
        let paths = items.map(\.path)
        while paths.contains(remotePath) {
            remotePath = currentPath.appendingPathComponent("\(folderName) \(suffix)")
            suffix += 1
        }
        
        Task {
            do {
                try await adbService.createNewFolder(serial: currentDevice.serial, remotePath: remotePath)
            } catch {
                Logger.error("Failed to create folder.", error: error)
                presentErrorAlert(message: "Failed to create folder.") { [weak self] in
                    self?.createNewFolder()
                }
            }
            refreshItems() // Yes, do this regardless of success or failure
        }
    }
    
    func rename(remoteSource: URL, newName: String) {
        guard let currentDevice else {
            Logger.error("Tried to rename when no device was selected.")
            return
        }
        
        let remoteDestination = remoteSource.deletingLastPathComponent().appendingPathComponent(newName)
        Task {
            do {
                try await adbService.rename(serial: currentDevice.serial, remoteSourcePath: remoteSource, remoteDestinationPath: remoteDestination)
                refreshItems()
            } catch {
                Logger.error("Failed to rename item.", error: error)
                presentErrorAlert(message: "Failed to rename item.") { [weak self] in
                    self?.rename(remoteSource: remoteSource, newName: newName)
                }
            }
        }
    }
    
    func createAdbErrorViewModel() -> ADBErrorViewModel {
        ADBErrorViewModel(adbService: adbService)
    }
    
    private func presentItemDeletionConfirmationAlert(itemName: String, delete: @escaping () -> Void) {
        alertModel = .init(
            title: "Are you sure you want to permanently delete \(itemName)?",
            message: "This action cannot be undone.",
            primaryButton: nil,
            destructiveButton: .init(title: "Delete", action: delete),
            cancelButton: .init(title: "Cancel", action: { [weak self] in
                self?.alertModel = nil
            })
        )
    }
    
    private func presentDuplicateFileAlert(fileName: String, replace: @escaping () -> Void) {
        alertModel = .init(
            title: "An item named \(fileName) already exists in this folder.",
            message: "Would you like to replace the existing item with the one being copied?",
            primaryButton: .init(title: "Replace", action: replace),
            destructiveButton: nil,
            cancelButton: .init(title: "Skip", action: { [weak self] in
                self?.alertModel = nil
            })
        )
    }
    
    private func presentErrorAlert(message: String, retry: @escaping () -> Void) {
        alertModel = .init(
            title: "Something went wrong",
            message: message,
            primaryButton: .init(title: "Retry", action: retry),
            destructiveButton: nil,
            cancelButton: .init(title: "Cancel", action: { [weak self] in
                self?.alertModel = nil
            })
        )
    }
    
    enum ViewState {
        case loading
        case loaded
        case error
    }
    
    struct AlertModel: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let primaryButton: Button?
        let destructiveButton: Button?
        let cancelButton: Button
        
        struct Button: Identifiable {
            let id = UUID()
            let title: String
            let action: () -> Void
        }
    }
}
