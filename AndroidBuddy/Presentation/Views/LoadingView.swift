//
//  LoadingView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 12/4/2024.
//

import SwiftUI

struct LoadingView: View {
    
    @State var opacity: CGFloat = 1
    private let animation = Animation.bouncy(duration: 2)
        .repeatForever(autoreverses: true)
    
    var body: some View {
        Image(.androidLogo)
            .resizable()
            .scaledToFit()
            .frame(width: 300)
            .opacity(opacity)
            .onAppear {
                withAnimation(animation) {
                    opacity = 0.2
                }
            }
    }
}

#Preview {
    LoadingView()
}
