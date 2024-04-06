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
                ForEach(viewModel.allDeviceSerials, id: \.self) { serial in
                    Text(serial)
                        .tag(serial)
                }
            }
        }
    }
}

#Preview {
    SideBarView()
}
