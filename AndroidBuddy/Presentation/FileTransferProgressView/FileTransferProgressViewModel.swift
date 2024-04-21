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
        case notStarted
        case inProgress(percentage: Double) // 0 to 1
        case completed
        case failed
        case cancelled
    }
    
    let action: Action
    let serial: String
    let remoteUrl: URL
    let adbService: ADBService
    let transferDecription: String
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published var viewState: ViewState = .notStarted
    
    init(model: Model, adbService: ADBService) {
        action = model.action
        serial = model.serial
        remoteUrl = model.remoteUrl
        self.adbService = adbService
        
        transferDecription = switch action {
        case .download: "\(remoteUrl.absoluteString) → Downloads"
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
        viewState = .cancelled
    }
    
    private func beginDownload() {
        viewState = .inProgress(percentage: 0)
        adbService.pull(serial: serial, remotePath: remoteUrl)
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.viewState = switch completion {
                    case .finished: .completed
                    case .failure(_): .failed
                    }
                },
                receiveValue: { [weak self] value in
                    self?.viewState = switch value.progress {
                    case let .inProgress(percentage): .inProgress(percentage: percentage)
                    case .completed: .completed
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
