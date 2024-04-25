//
//  FileTransferProgressView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 21/4/2024.
//

import SwiftUI

struct FileTransferProgressView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    private let commonSpacing: CGFloat = 10
    @State var isHoveringOverCancel = false
    
    private var descriptionText: String {
        isHoveringOverCancel ? "Cancel" : viewModel.transferDescription
    }
    
    @StateObject var viewModel: FileTransferProgressViewModel
    
    var body: some View {
        Group {
            if viewModel.showView {
                inProgressView(percentage: viewModel.completionPercentage)
            } else {
                EmptyView()
            }
        }
        .frame(height: 80)
        .frame(idealWidth: 500)
        .frame(minWidth: 500)
        .onChange(of: viewModel.viewState) { newValue in
            if newValue == .completed {
                dismiss()
            }
        }
    }
    
    private func inProgressView(percentage: Double) -> some View {
        HStack(spacing: commonSpacing) {
            
            Image(systemName: "arrow.down.circle")
                .resizable()
                .scaledToFill()
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 25)
                
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Downloading...")
                HStack(spacing: commonSpacing) {
                    ProgressView(value: percentage)
                    
                    Image(systemName: "xmark.circle.fill")
                        .onHover { hovering in
                            isHoveringOverCancel = hovering
                        }
                        .onTapGesture {
                            viewModel.cancelTransfer()
                            dismiss()
                        }
                }
                Text(descriptionText)
            }
        }
        .padding(commonSpacing)
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
        adbService: MockAdbService(adbState: .running, connectedDevices: [])
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
            connectedDevices: [],
            pull: {
                Just(try! .init(rawOutput: "[100%] /sdcard/Roms/Gamecube/Super Mario Strikers.iso"))
                    .setFailureType(to: Error.self)
            }
        )
    ))
}
