//
//  FileTransferProgressView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 21/4/2024.
//

import SwiftUI

struct FileTransferProgressView: View {
    
    struct Model: Identifiable {
        let id = UUID()
        let title: String
        let completionPercentage: Double?
        let transferDetails: String
    }
    
    let model: Model
    @EnvironmentObject var viewModel: ContentViewModel
    @State var isHoveringOverCancel = false
    
    // This needs to be non-optional, even if I end up making transfer details optional.
    // This is due to how the Progress view gets laid out when the current value label is and isn't provided.
    private var descriptionText: String {
        isHoveringOverCancel ? "Cancel" : model.transferDetails
    }
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.down.circle")
                .resizable()
                .scaledToFill()
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 25)

            ProgressView(
                value: model.completionPercentage,
                label: { Text(model.title) },
                currentValueLabel: { Text(descriptionText) }
            )
            
            Image(systemName: "xmark.circle.fill")
                .onHover { hovering in
                    isHoveringOverCancel = hovering
                }
                .onTapGesture {
                    viewModel.cancelTransfer()
                }
        }
        .frame(width: 500)
        .padding(20)
    }
}

#Preview("Determinate") {
    FileTransferProgressView(model: .init(
        title: "Downloading...",
        completionPercentage: 0.35,
        transferDetails: "/sdcard/roms/SuperMarioStrikers.iso → Downloads"
    ))
}

#Preview("Indeterminate") {
    FileTransferProgressView(model: .init(
        title: "Installing youtube.apk...",
        completionPercentage: nil,
        transferDetails: ""
    ))
}
