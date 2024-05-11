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
    @Published var items: [DirectoryItem] = []
    @Published var backButtonEnabled: Bool = false
    @Published var fileTransferModel: FileTransferProgressView.Model? = nil
    @Published var alertModel: AlertModel? = nil
    
    @Published var currentPath: URL = .shellRoot
    
    var currentDevice: Device? {
        guard let currentDeviceSerial else { return nil }
        return allDevices.first { $0.serial == currentDeviceSerial }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var fileTransferCancellable: AnyCancellable? = nil
    private let adbService: ADBService
    
    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
    
    private static let forceRefreshNotification = NSNotification.Name(rawValue: "forceRefreshNotification")
    
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
        
        NotificationCenter.default
            .publisher(for: Self.forceRefreshNotification)
            .sink { [weak self] _ in self?.refreshItems() }
            .store(in: &cancellables)
    }
    
    private static func forceRefeshAllDevices() {
        NotificationCenter.default.post(Notification(name: Self.forceRefreshNotification))
    }
    
    func refreshItems() {
        guard let currentDeviceSerial else { return }
        Task {
            do {
                let response = try await adbService.list(serial: currentDeviceSerial, path: currentPath)
                items = Self.mapListResponseToItems(response)
            } catch {
                Logger.error("Failed to load directory.", error: error)
                presentErrorAlert(title: "Failed To Load Directory", error: error) { [weak self] in
                    self?.refreshItems()
                }
            }
        }
    }
    
    private static func mapListResponseToItems(_ response: ListResponse) -> [DirectoryItem] {
        return response.items.map { responseItem in
            let itemType: DirectoryItem.ItemType = switch responseItem.fileType {
            case .directory: .directory
            case .file: .file
            case .symlink: .directory
            }
            
            let sizeString = switch itemType {
            case .file: byteCountFormatter.string(fromByteCount: Int64(responseItem.size))
            case .directory: "--"
            }
            
            return DirectoryItem(
                path: responseItem.path,
                name: responseItem.name,
                dateModified: responseItem.lastModifiedDate.formatted(date: .abbreviated, time: .shortened),
                size: sizeString,
                isSymlink: responseItem.fileType == .symlink,
                type: itemType
            )
        }
    }
    
    func requestFileDownload(remotePaths: [URL]) {
        guard let currentDeviceSerial else {
            Logger.error("Tried to download file when no device was selected.")
            return
        }
        
        let localPath = URL(string: "/Users/Mark/Downloads")! // TODO: Choose directory instead of always going to Downloads folder.
        
        Task {
            var pathsToDownload: [URL] = remotePaths
            for remotePath in remotePaths {
                let fileName = remotePath.lastPathComponent
                let potentialLocalPath = localPath.appending(path: fileName)
                let fileExists = FileManager.default.fileExists(atPath: potentialLocalPath.path(percentEncoded: false))
                if fileExists {
                    let result = await presentDuplicateFileAlert(fileName: fileName)
                    switch result {
                    case .replace: break
                    case .skip: pathsToDownload.removeAll { $0 == remotePath }
                    case .cancel: return
                    }
                }
            }
            
            guard !pathsToDownload.isEmpty else { return }
            
            downloadFiles(serial: currentDeviceSerial, remotePaths: pathsToDownload, localPath: localPath)
        }
    }
    
    private func downloadFiles(serial: String, remotePaths: [URL], localPath: URL) {
        guard let nextRemotePath = remotePaths.first else {
            fileTransferModel = nil
            refreshItems()
            return
        }
        
        let remainingRemotePaths = Array(remotePaths.dropFirst())
        let remoteFileName = nextRemotePath.path(percentEncoded: false)
        let transferDetails = "\(remoteFileName) → Downloads"
        
        func updateTransfer(_ percentage: Double) {
            fileTransferModel = .init(
                title: "Downloading...",
                completionPercentage: percentage,
                transferDetails: transferDetails,
                transferType: .download
            )
        }
        
        updateTransfer(0)
        
        fileTransferCancellable = adbService.pull(serial: serial, remotePath: nextRemotePath, localPath: localPath)
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.fileTransferModel = nil
                    switch completion {
                    case .finished:
                        self?.downloadFiles(serial: serial, remotePaths: remainingRemotePaths, localPath: localPath)
                    case let .failure(error):
                        self?.refreshItems() // In case cancel is pressed
                        self?.presentErrorAlert(title: "Failed To Download \(remoteFileName)", error: error) { [weak self] in
                            self?.downloadFiles(serial: serial, remotePaths: remotePaths, localPath: localPath)
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
        guard let currentDeviceSerial else {
            Logger.error("Tried to upload file when no device was selected.")
            return
        }
        
        Task {
            do {
                let fileName = localPath.lastPathComponent
                let potentialRemotePath = currentPath.appending(path: fileName)
                let fileExists = try await adbService.doesFileExist(serial: currentDeviceSerial, remotePath: potentialRemotePath)
                if fileExists {
                    presentDuplicateFileAlert(fileName: fileName) { [weak self] in
                        self?.uploadFile(serial: currentDeviceSerial, localPath: localPath)
                    }
                } else {
                    uploadFile(serial: currentDeviceSerial, localPath: localPath)
                }
            } catch {
                presentErrorAlert(title: "Failed To Upload File", error: error) { [weak self] in
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
                    self?.refreshItems()
                    switch completion {
                    case .finished:
                        break
                    case let .failure(error):
                        self?.presentErrorAlert(title: "Upload Failed", error: error) { [weak self] in
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
    
    func requestItemDeletion(items: [DirectoryItem]) {
        guard let currentDeviceSerial else {
            Logger.error("Tried to delete item when no device was selected.")
            return
        }
        
        func deletion() {
            deleteFiles(serial: currentDeviceSerial, items: items)
        }
        
        if items.count > 1 {
            presentDeletionConfirmationAlertPlural(itemCount: items.count, delete: deletion)
        } else if items.count == 1 {
            presentDeletionConfirmationAlertSingular(itemName: items[0].name, delete: deletion)
        }
    }
    
    private func deleteFiles(serial: String, items: [DirectoryItem]) {
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for item in items {
                        group.addTask { [weak self] in
                            try await self?.adbService.delete(
                                serial: serial,
                                remotePath: item.path,
                                isDirectory: item.type == .directory
                            )
                        }
                    }
                    try await group.waitForAll()
                }
                refreshItems()
            } catch {
                Logger.error("Failed to delete item.", error: error)
                presentErrorAlert(title: "Failed To Delete", error: error) { [weak self] in
                    if items.count > 1 {
                        // It's possible that half the files get deleted and then this errors out.
                        // In this case if we recursively re-run the deletion function with the same parameters,
                        // we will be attempting to delete files that don't exist anymore.
                        // TODO: Fix here, it isn't retrying...
                        self?.refreshItems()
                    } else {
                        self?.deleteFiles(serial: serial, items: items)
                    }
                }
            }
        }
    }
    
    func createNewFolder() {
        guard let currentDeviceSerial else {
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
                try await adbService.createNewFolder(serial: currentDeviceSerial, remotePath: remotePath)
            } catch {
                Logger.error("Failed to create folder.", error: error)
                presentErrorAlert(title: "Failed To Create Folder", error: error) { [weak self] in
                    self?.createNewFolder()
                }
            }
            refreshItems()
        }
    }
    
    func rename(remoteSource: URL, newName: String) {
        guard let currentDeviceSerial else {
            Logger.error("Tried to rename when no device was selected.")
            return
        }
        
        let remoteDestination = remoteSource.deletingLastPathComponent().appendingPathComponent(newName)
        Task {
            do {
                try await adbService.rename(serial: currentDeviceSerial, remoteSourcePath: remoteSource, remoteDestinationPath: remoteDestination)
            } catch {
                Logger.error("Failed to rename item.", error: error)
                presentErrorAlert(title: "Failed To Rename Item", error: error) { [weak self] in
                    self?.rename(remoteSource: remoteSource, newName: newName)
                }
            }
            refreshItems()
        }
    }
    
    func move(sourceDeviceSerial: String, remoteSources: [URL], remoteDestination: URL) {
        guard let currentDeviceSerial else {
            Logger.error("Tried to move item when no device was selected.")
            return
        }
        
        // Guard against having two windows open and trying to drag/drop from one device to a different device
        guard sourceDeviceSerial == currentDeviceSerial else {
            presentStandardAlert(
                title: "Failed to move item(s)",
                message: "Android Buddy does not support directly moving or copying items from one Android device to another."
            )
            return
        }
        
        let command = adbService.move(serial: currentDeviceSerial, remoteSourcePaths: remoteSources, remoteDestinationPath: remoteDestination)
        
        command.publisher
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    Self.forceRefeshAllDevices()
                    switch completion {
                    case .finished:
                        Logger.verbose("Move operation completed successfully.")
                        break
                    case let .failure(error):
                        self?.presentErrorAlert(title: "Failed to move item(s)", error: error)
                    }
                },
                receiveValue: { [weak self] value in
                    switch value.type {
                    case .nothing:
                        break
                    case let .requestingOverwriteConfirmation(url):
                        self?.presentFileOverwriteConfirmationAlert(
                            path: url,
                            confirm: { command.writeHandler("y") },
                            deny: { command.writeHandler("n") }
                        )
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func moveToParent(remoteSources: [URL]) {
        guard let currentDeviceSerial else {
            return
        }
        // If back is enabled then logically we should have a parent directory
        guard backButtonEnabled else { return }
        
        let parent = currentPath.deletingLastPathComponent()
        move(sourceDeviceSerial: currentDeviceSerial, remoteSources: remoteSources, remoteDestination: parent)
    }
    
    private func installAPK(localFilePath: URL) {
        guard let currentDeviceSerial else {
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
        
        fileTransferCancellable = adbService.installAPK(serial: currentDeviceSerial, localPath: localFilePath)
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.fileTransferModel = nil
                    switch completion {
                    case .finished:
                        self?.presentAPKInstallingSuccessAlert()
                    case let .failure(error):
                        self?.presentErrorAlert(title: "Installation Failed", error: error) { [weak self] in
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
        refreshItems()
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
    
    private func presentDeletionConfirmationAlertPlural(itemCount: Int, delete: @escaping () -> Void) {
        let title = "Are you sure you want to permanently delete \(itemCount) items?"
        presentDeletionConfirmationAlert(title: title, delete: delete)
    }
    
    private func presentDeletionConfirmationAlertSingular(itemName: String, delete: @escaping () -> Void) {
        let title = "Are you sure you want to permanently delete \(itemName)?"
        presentDeletionConfirmationAlert(title: title, delete: delete)
    }
    
    private func presentDeletionConfirmationAlert(title: String, delete: @escaping () -> Void) {
        alertModel = .init(
            title: title,
            message: "This action cannot be undone.",
            buttons: [
                .init(title: "Delete", type: .destructive, action: delete),
                alertCancelButton
            ]
        )
    }
    
    private enum DuplicateFileAlertResult {
        case replace
        case skip
        case cancel
    }
    private func presentDuplicateFileAlert(fileName: String) async -> DuplicateFileAlertResult {
        await withCheckedContinuation { continuation in
            alertModel = .init(
                title: "An item named \(fileName) already exists in this folder.",
                message: "Would you like to replace the existing item with the one being copied?",
                buttons: [
                    .init(title: "Replace", type: .standard) {
                        continuation.resume(returning: .replace)
                    },
                    .init(title: "Skip", type: .standard) {
                        continuation.resume(returning: .skip)
                    },
                    .init(title: "Cancel", type: .cancel) {
                        continuation.resume(returning: .cancel)
                    }
                ]
            )
        }
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
    
    private func presentErrorAlert(title: String, error: Error, retry: @escaping () -> Void) {
        alertModel = .init(
            title: title,
            message: Self.errorAlertMessage(error: error),
            buttons: [
                .init(title: "Retry", type: .standard, action: retry),
                alertCancelButton
            ]
        )
    }
    
    private func presentErrorAlert(title: String, error: Error) {
        alertModel = .init(
            title: title,
            message: Self.errorAlertMessage(error: error),
            buttons: [
                .init(title: "OK", type: .standard, action: {})
            ]
        )
    }
    
    private static func errorAlertMessage(error: Error) -> String {
        // We'll see how this goes for now. We might remove this if it looks weird.
        let message = if case let ADB.AdbError.adbError(output) = error {
            output
        } else if case let ADB.AdbError.commandError(output) = error {
            output
        } else {
            "\(error)"
        }
        
        let sanitisedMessage = message
            .replacingOccurrences(of: #"\n"#, with: "")
            .replacingOccurrences(of: #"\"#, with: #""#)
        
        return sanitisedMessage
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
    
    private func presentFileOverwriteConfirmationAlert(path: URL, confirm: @escaping () -> Void, deny: @escaping () -> Void) {
        alertModel = .init(
            title: "An item named \(path.lastPathComponent) already exists at this location",
            message: "Do you want to replace it with the file you are moving?",
            buttons: [
                .init(title: "Yes", type: .standard, action: confirm),
                .init(title: "No", type: .standard, action: deny)
            ]
        )
    }
    
    private func presentStandardAlert(title: String, message: String? = nil) {
        alertModel = .init(
            title: title,
            message: message,
            buttons: [
                .init(title: "OK", type: .standard, action: {})
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
