//
//  NoDevicesView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 5/4/2024.
//

import SwiftUI

struct NoDevicesView: View {
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: ViewConstants.commonSpacing) {
            Text("No Devices Connected")
                .font(.largeTitle)

            Button("Can't see your Device? Ensure USB Debugging is enabled.") {
                openWindow(id: AndroidBuddyApp.usbDebuggingIntructionsWindowId)
            }
            .buttonStyle(.plain)
            .underline()
            .foregroundStyle(Color.accentColor)
        }
    }
}

#Preview {
    NoDevicesView()
}
