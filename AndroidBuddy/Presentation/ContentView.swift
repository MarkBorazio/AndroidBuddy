//
//  ContentView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 1/4/2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    
    let testDeviceNames = [
        "Device 1",
        "Device 2",
        "Device 3"
    ]
    
    private let type = UTType.fileURL
    private let encoding: UInt = 4 // Not sure what this actually represents...
    
    @StateObject var viewModel = ContentViewModel()
    @State private var isDraggingFileOverView = false
    
    var body: some View {
        NavigationSplitView {
            listView
        } detail: {
            DirectoryView()
                .border(isDraggingFileOverView ? Color.accentColor : Color.clear, width: 5)
        }
        .navigationTitle(viewModel.currentPath.path())
        .toolbar {
            ToolbarItem(placement: .navigation) {
                backButton
            }
            ToolbarItem(placement: .primaryAction) {
                refreshButton
            }
        }
        .onDrop(of: [type], isTargeted: $isDraggingFileOverView, perform: onDropItem)
        .environmentObject(viewModel)
    }
    
    var listView: some View {
        List {
            Section("Wired") {
                ForEach(testDeviceNames, id: \.self) { name in
                    Text(name)
                }
            }
            Section("Wireless") {
                ForEach(testDeviceNames, id: \.self) { name in
                    Text(name)
                }
            }
        }
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
        provider.loadDataRepresentation(forTypeIdentifier: type.identifier, completionHandler: { (data, error) in
            guard
                let data = data,
                let path = NSString(data: data, encoding: encoding),
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

#Preview {
    ContentView()
}
