//
//  ContentViewModel.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 2/4/2024.
//

import Foundation
import Combine
import UniformTypeIdentifiers

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
                transferDetails: transferDetails,
                transferType: .download
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
    
    private func requestFileUpload(localPath: URL) {
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
                transferDetails: transferDetails,
                transferType: .upload
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
    
    private func installAPK(localFilePath: URL) {
        guard let currentDevice else {
            Logger.error("Tried to install APK when no device was selected.")
            return
        }
        
        let fileName = localFilePath.lastPathComponent
        
        fileTransferModel = .init(
            title: "Installing \(fileName)...",
            completionPercentage: nil,
            transferDetails: "",
            transferType: .installation
        )
        
        fileTransferCancellable = adbService.installAPK(serial: currentDevice.serial, localPath: localFilePath)
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.fileTransferModel = nil
                    switch completion {
                    case .finished:
                        self?.presentAPKInstallingSuccessAlert()
                    case .failure(_):
                        self?.presentErrorAlert(message: "Download failed") { [weak self] in
                            self?.installAPK(localFilePath: localFilePath)
                        }
                    }
                },
                receiveValue: { _ in }
            )
    }
    
    static let contentType: UTType = .fileURL
    static let contentTypeEncoding: UInt = 4
    
    func handleItemDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadDataRepresentation(forTypeIdentifier: Self.contentType.identifier) { [weak self] (data, error) in
            guard
                let self,
                let data = data,
                let path = NSString(data: data, encoding: Self.contentTypeEncoding),
                let url = URL(string: path as String)
            else {
                return
            }
            
            Task {
                if url.pathExtension == "apk" {
                    await self.presentApkFileActionAlert(localFilePath: url)
                } else {
                    await self.requestFileUpload(localPath: url)
                }
            }
        }
        return true
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
    
    func createAdbErrorViewModel() -> ADBErrorViewModel {
        ADBErrorViewModel(adbService: adbService)
    }
    
    private func presentItemDeletionConfirmationAlert(itemName: String, delete: @escaping () -> Void) {
        alertModel = .init(
            title: "Are you sure you want to permanently delete \(itemName)?",
            message: "This action cannot be undone.",
            buttons: [
                .init(title: "Delete", type: .destructive, action: delete),
                alertCancelButton
            ]
        )
    }
    
    private func presentDuplicateFileAlert(fileName: String, replace: @escaping () -> Void) {
        alertModel = .init(
            title: "An item named \(fileName) already exists in this folder.",
            message: "Would you like to replace the existing item with the one being copied?",
            buttons: [
                .init(title: "Replace", type: .standard, action: replace),
                alertCancelButton
            ]
        )
    }
    
    private func presentErrorAlert(message: String, retry: @escaping () -> Void) {
        alertModel = .init(
            title: "Something went wrong",
            message: message,
            buttons: [
                .init(title: "Retry", type: .standard, action: retry),
                alertCancelButton
            ]
        )
    }
    
    private func presentApkFileActionAlert(localFilePath: URL) {
        alertModel = .init(
            title: localFilePath.lastPathComponent,
            message: "Do you want to install this APK or upload it to your device?",
            buttons: [
                .init(title: "Install", type: .standard) { [weak self] in
                    self?.installAPK(localFilePath: localFilePath)
                },
                .init(title: "Upload", type: .standard) { [weak self] in
                    self?.requestFileUpload(localPath: localFilePath)
                },
                alertCancelButton
            ]
        )
    }
    
    private func presentAPKInstallingSuccessAlert() {
        alertModel = .init(
            title: "APK successfully installed.",
            message: nil,
            buttons: [
                .init(title: "OK", type: .standard) {}
            ]
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
        let message: String?
        let buttons: [Button]
        
        struct Button: Identifiable {
            let id = UUID()
            let title: String
            let type: ButtonType
            let action: () -> Void
            
            enum ButtonType {
                case standard
                case destructive
                case cancel
            }
        }
    }
    
    private var alertCancelButton: AlertModel.Button {
        .init(title: "Cancel", type: .cancel) { [weak self] in
            self?.alertModel = nil
        }
    }
}
