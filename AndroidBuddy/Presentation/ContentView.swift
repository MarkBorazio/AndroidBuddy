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
    
    @StateObject var viewModel = ContentViewModel()
    @State private var isDraggingFileOverView = false
    private let type = UTType.fileURL
    private let encoding: UInt = 4 // Not sure what this actually represents...
    
    var body: some View {
        NavigationSplitView {
            listView
        } detail: {
            DirectoryView()
        }
        .navigationTitle(viewModel.currentPath.path())
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    viewModel.back()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                .disabled(!viewModel.backButtonEnabled)
            }
        }
        .onDrop(of: [type], isTargeted: $isDraggingFileOverView, perform: { providers in
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
        })
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
}

#Preview {
    ContentView()
}
