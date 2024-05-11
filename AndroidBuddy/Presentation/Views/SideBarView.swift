//
//  SideBarView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 6/4/2024.
//

import SwiftUI

struct SideBarView: View {
    
    @EnvironmentObject var viewModel: ContentViewModel
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading) {
            List(selection: $viewModel.currentDeviceSerial) {
                Section("Devices") {
                    ForEach(viewModel.allDevices, id: \.serial) { device in
                        Text(device.bluetoothName ?? device.serial)
                            .tag(device.serial)
                    }
                }
            }
            
            Spacer()
            
            Button("Can't see your Device?") {
                openWindow(id: AndroidBuddyApp.usbDebuggingIntructionsWindowId)
            }
            .buttonStyle(.plain)
            .underline()
            .foregroundStyle(Color.secondary)
            .padding(ViewConstants.commonSpacing)
            
        }
    }
}

#Preview {
    SideBarView()
        .environmentObject(ContentViewModel(adbService: MockAdbService(
            adbState: .running,
            connectedDevices: (0...10).map {
                .init(bluetoothName: "Device \($0)", serial: "\($0)")
            }
        )))
}
