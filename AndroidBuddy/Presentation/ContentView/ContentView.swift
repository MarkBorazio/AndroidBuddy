//
//  ContentView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 1/4/2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    
    private static let contentType: UTType = .fileURL
    private static let contentTypeEncoding: UInt = 4
    
    @StateObject var viewModel: ContentViewModel
    @State private var isDraggingFileOverView = false
    
    init(adbService: ADBService) {
        _viewModel = StateObject(wrappedValue: { ContentViewModel(adbService: adbService) }())
    }
    
    var body: some View {
        switch viewModel.viewState {
        case .loading:
            LoadingView()
        case .loaded:
            loadedView
        case .error:
            ADBErrorView(viewModel: viewModel.createAdbErrorViewModel())
        }
    }
    
    @ViewBuilder
    var loadedView: some View {
        if viewModel.allDevices.isEmpty {
            NoDevicesView()
        } else {
            navigationSplitView
        }
    }
    
    var navigationSplitView: some View {
        NavigationSplitView {
            SideBarView()
        } detail: {
            DirectoryView()
                .border(isDraggingFileOverView ? Color.accentColor : Color.clear, width: 5)
        }
        .navigationTitle(viewModel.title)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                backButton
            }
            ToolbarItem(placement: .primaryAction) {
                refreshButton
            }
        }
        .onDrop(of: [Self.contentType], isTargeted: $isDraggingFileOverView, perform: onDropItem)
        .environmentObject(viewModel)
    }
    
    var backButton: some View {
        Button {
            viewModel.back()
        } label: {
            Label("Back", systemImage: "chevron.backward")
        }
        .disabled(!viewModel.backButtonEnabled)
    }
    
    var refreshButton: some View {
        Button {
            viewModel.refreshItems()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }
    
    // Handler for when file is dropped onto window
    private func onDropItem(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadDataRepresentation(forTypeIdentifier: Self.contentType.identifier, completionHandler: { (data, error) in
            guard
                let data = data,
                let path = NSString(data: data, encoding: Self.contentTypeEncoding),
                let url = URL(string: path as String)
            else {
                return
            }
            print(url)
            viewModel.uploadFile(localPath: url)
        })
        return true
    }
}

#Preview("Not Running") {
    ContentView(adbService: MockAdbService(adbState: .notRunning, devices: []))
}

#Preview("Setting Up") {
    ContentView(adbService: MockAdbService(adbState: .settingUp, devices: []))
}

#Preview("Running - No Devices Connected") {
    ContentView(adbService: MockAdbService(adbState: .running, devices: []))
}

#Preview("Running - Devices Connected") {
    ContentView(adbService: MockAdbService(
        adbState: .running,
        devices: [
            .init(bluetoothName: "Device 1", serial: "1"),
            .init(bluetoothName: "Device 2", serial: "2")
        ]
    ))
}

#Preview("Error") {
    ContentView(adbService: MockAdbService(adbState: .error, devices: []))
}
