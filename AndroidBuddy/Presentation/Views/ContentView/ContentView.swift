//
//  ContentView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 1/4/2024.
//

import SwiftUI

struct ContentView: View {
    
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
            ToolbarItemGroup(placement: .primaryAction) {
                createNewFolderButton
                refreshButton
            }
        }
        .onDrop(of: [ContentViewModel.contentType], isTargeted: $isDraggingFileOverView, perform: viewModel.handleItemDrop)
        .sheet(item: $viewModel.fileTransferModel) { model in
            FileTransferProgressView(model: model)
        }
        .environmentObject(viewModel)
        .alert(
            LocalizedStringKey(viewModel.alertModel?.title ?? "Alert"),
            dataSource: $viewModel.alertModel,
            actions: { data in
                ForEach(data.buttons) { button in
                    let role: ButtonRole? = switch button.type {
                    case .standard: nil
                    case .destructive: .destructive
                    case .cancel: .cancel
                    }
                    Button(button.title, role: role, action: button.action)
                }
            },
            message: { data in
                if let message = data.message {
                    Text(message)
                }
            }
        )
    }
    
    private var backButton: some View {
        Button {
            viewModel.back()
        } label: {
            Label("Back", systemImage: "chevron.backward")
        }
        .disabled(!viewModel.backButtonEnabled)
    }
    
    private var refreshButton: some View {
        Button {
            viewModel.refreshItems()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }
    
    private var createNewFolderButton: some View {
        Button {
            // TODO: Auto highlight folder to set the name...
            viewModel.createNewFolder()
        } label: {
            Label("Create New Folder", systemImage: "folder.fill.badge.plus")
        }
    }
}

#Preview("Not Running") {
    ContentView(adbService: MockAdbService(adbState: .notRunning, connectedDevices: []))
}

#Preview("Setting Up") {
    ContentView(adbService: MockAdbService(adbState: .settingUp, connectedDevices: []))
}

#Preview("Running - No Devices Connected") {
    ContentView(adbService: MockAdbService(adbState: .running, connectedDevices: []))
}

#Preview("Running - Devices Connected") {
    ContentView(adbService: MockAdbService(
        adbState: .running,
        connectedDevices: [
            .init(bluetoothName: "Device 1", serial: "1"),
            .init(bluetoothName: "Device 2", serial: "2")
        ]
    ))
}

#Preview("Error") {
    ContentView(adbService: MockAdbService(adbState: .error, connectedDevices: []))
}
