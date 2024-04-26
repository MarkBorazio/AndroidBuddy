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
        let completionPercentage: Double
        let transferDetails: String
    }
    
    let model: Model
    @EnvironmentObject var viewModel: ContentViewModel
    @State var isHoveringOverCancel = false
    
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
                
            VStack(alignment: .leading, spacing: 0) {
                Text(model.title)
                HStack {
                    ProgressView(value: model.completionPercentage)
                    
                    Image(systemName: "xmark.circle.fill")
                        .onHover { hovering in
                            isHoveringOverCancel = hovering
                        }
                        .onTapGesture {
                            viewModel.cancelTransfer()
                        }
                }
                Text(descriptionText)
            }
        }
        .frame(width: 500)
        .padding(20)
    }
}

#Preview("Downloading") {
    FileTransferProgressView(model: .init(
        title: "Downloading...",
        completionPercentage: 35,
        transferDetails: "/sdcard/roms/SuperMarioStrikers.iso → Downloads"
    ))
}
