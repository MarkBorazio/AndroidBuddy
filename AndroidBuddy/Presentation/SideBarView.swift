//
//  SideBarView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 6/4/2024.
//

import SwiftUI

struct SideBarView: View {
    
    @EnvironmentObject var viewModel: ContentViewModel
    
    var body: some View {
        List(selection: $viewModel.currentDeviceSerial) {
            Section("Devices") {
                ForEach(viewModel.allDevices, id: \.serial) { device in
                    Text(device.bluetoothName)
                        .tag(device.serial)
                }
            }
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
