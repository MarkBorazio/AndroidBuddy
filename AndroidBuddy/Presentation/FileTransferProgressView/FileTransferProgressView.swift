//
//  FileTransferProgressView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 21/4/2024.
//

import SwiftUI

// TODO: Prevent window resizing?
struct FileTransferProgressView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    private let commonSpacing: CGFloat = 10
    
    @StateObject var viewModel: FileTransferProgressViewModel
    
    var body: some View {
        Group {
            switch viewModel.viewState {
            case .notStarted:
                EmptyView()
            case .inProgress(let percentage):
                inProgressView(percentage: percentage)
            case .completed:
                completedView
            case .failed:
                EmptyView()
            case .cancelled:
                cancelledView
            }
        }
    }
    
    private func inProgressView(percentage: Double) -> some View {
        HStack(spacing: commonSpacing) {
            
            Image(systemName: "arrow.down.circle")
                .resizable()
                .scaledToFill()
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 35)
                
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Downloading...")
                HStack(spacing: commonSpacing) {
                    ProgressView(value: percentage)
                    
                    Image(systemName: "xmark.circle.fill")
                        .onTapGesture {
                            viewModel.cancelTransfer()
                        }
                }
                Text(viewModel.transferDecription)
            }
        }
        .padding(commonSpacing)
    }
    
    private var completedView: some View {
        VStack {
            Text("Download complete")
            Button("Dismiss") {
                dismiss()
            }
        }
    }
    
    private var cancelledView: some View {
        VStack {
            Text("Download complete")
            HStack {
                Button("Retry") {
                    viewModel.beginTransfer()
                }
                Button("Dismiss") {
                    dismiss()
                }
            }
        }
    }
}

import Combine

#Preview("Downloading") {
    FileTransferProgressView(viewModel: .init(
        model: .init(
            action: .download,
            serial: "Cereal Box",
            remoteUrl: URL(string: "/sdcard/roms/gamecube/SuperMarioStrikers")!
        ),
        adbService: MockAdbService(adbState: .running, devices: [])
    ))
}

#Preview("Download Completed") {
    FileTransferProgressView(viewModel: .init(
        model: .init(
            action: .download,
            serial: "Cereal Box",
            remoteUrl: URL(string: "/sdcard/roms/gamecube/SuperMarioStrikers")!
        ),
        adbService: MockAdbService(
            adbState: .running,
            devices: [],
            pullBlock: {
                Just(.init(rawOutput: "[100%] /sdcard/Roms/Gamecube/Super Mario Strikers.iso"))
                    .setFailureType(to: Error.self)
            }
        )
    ))
}
