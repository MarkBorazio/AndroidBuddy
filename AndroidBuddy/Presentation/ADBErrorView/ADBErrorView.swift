//
//  ADBErrorView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 12/4/2024.
//

import SwiftUI

struct ADBErrorView: View {
    
    let viewModel = ADBErrorViewModel()
    
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
    ADBErrorView()
}
