//
//  FileTransferProgressViewModel.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 21/4/2024.
//

import Foundation
import Combine

class FileTransferProgressViewModel: ObservableObject {
    
    enum Action: Codable, Hashable {
        case download
        case upload
    }
    
    enum ViewState: Equatable {
        case inProgress
        case completed
        case failed
    }
    
    let action: Action
    let serial: String
    let remoteUrl: URL
    let adbService: ADBService
    let transferDescription: String
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published var viewState: ViewState = .inProgress
    @Published var completionPercentage: Double = 0 // 0 to 1
    @Published var showView = false // Only show view if download is taking longer than a second
    
    init(model: Model, adbService: ADBService) {
        action = model.action
        serial = model.serial
        remoteUrl = model.remoteUrl
        self.adbService = adbService
        
        transferDescription = switch action {
        case .download: "\(remoteUrl.path(percentEncoded: false)) → Downloads"
        case .upload: fatalError("TODO: Implement.")
        }
        
        beginTransfer()
    }
    
    func beginTransfer() {
        switch action {
        case .download: beginDownload()
        case .upload: beginUpload()
        }
    }
    
    func cancelTransfer() {
        cancellables.forEach {
            $0.cancel()
        }
    }
    
    private func show() {
        DispatchQueue.main.async { [weak self] in
            self?.showView = true
        }
    }
    
    private func beginDownload() {
        viewState = .inProgress
        completionPercentage = 0
        showView = false
        
        Task {
            do {
                try await Task.sleep(for: .seconds(1))
                show()
            } catch {
                show()
            }
        }
        
        adbService.pull(serial: serial, remotePath: remoteUrl)
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished: 
                        self?.viewState = .completed
                        self?.completionPercentage = 1
                    case .failure(_):
                        self?.viewState = .failed
                    }
                },
                receiveValue: { [weak self] value in
                    switch value.progress {
                    case let .inProgress(percentage): 
                        self?.viewState = .inProgress
                        self?.completionPercentage = percentage
                    case .completed:
                        self?.viewState = .completed
                        self?.completionPercentage = 1
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func beginUpload() {
        fatalError("TODO: Implement!")
    }
    
    // This exists so that we can pass it around for the Window presentation
    struct Model: Codable, Hashable {
        let action: Action
        let serial: String
        let remoteUrl: URL
    }
}
