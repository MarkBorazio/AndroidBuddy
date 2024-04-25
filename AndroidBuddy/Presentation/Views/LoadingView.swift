//
//  LoadingView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 12/4/2024.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: ViewConstants.commonSpacing) {
            ProgressView()
            Text("Starting")
                .font(.largeTitle)
        }
    }
}

#Preview {
    LoadingView()
}
