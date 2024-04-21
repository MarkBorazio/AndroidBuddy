//
//  AndroidBuddyApp.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 1/4/2024.
//

import SwiftUI

@main
struct AndroidBuddyApp: App {
    
    var body: some Scene {
        WindowGroup {
            ContentView(adbService: StandardDependencies.shared.adbService)
        }
        
        WindowGroup("", for: FileTransferProgressViewModel.Model.self) { $model in
            if let model {
                let viewModel = FileTransferProgressViewModel(model: model, adbService: StandardDependencies.shared.adbService)
                FileTransferProgressView(viewModel: viewModel)
            }
        }
    }
}
