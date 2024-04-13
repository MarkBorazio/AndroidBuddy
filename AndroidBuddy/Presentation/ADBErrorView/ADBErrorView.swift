//
//  ADBErrorView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 12/4/2024.
//

import SwiftUI

struct ADBErrorView: View {
    
    let viewModel: ADBErrorViewModel
    
    init(viewModel: ADBErrorViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: ViewConstants.commonSpacing) {
            Text("Something went wrong")
                .font(.largeTitle)
            
            Button("Restart ADB") {
                viewModel.restartAdb()
            }
        }
    }
}

#Preview {
    ADBErrorView(viewModel: .init(adbService: MockAdbService(adbState: .error, devices: [])))
}
