//
//  DebugCommandMenu.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 1/5/2024.
//

import SwiftUI

struct DebugCommandMenu: Commands {
    
    @StateObject var viewModel = DebugCommandMenuViewModel()

    var body: some Commands {
        CommandMenu("Debug") {
            Toggle(isOn: $viewModel.verboseLoggingEnabled) {
                Button("Verbose Logging") {
                    viewModel.verboseLoggingEnabled.toggle()
                }
            }
        }
    }
}
