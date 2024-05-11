//
//  AndroidBuddyApp.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 1/4/2024.
//

import SwiftUI

@main
struct AndroidBuddyApp: App {
    
    static let usbDebuggingIntructionsWindowId = "usbDebuggingIntructionsWindowId"
    
    var body: some Scene {
        WindowGroup {
            ContentView(adbService: StandardDependencies.shared.adbService)
        }
        .commands {
            #if DEBUG
            DebugCommandMenu()
            #endif
        }
        
        WindowGroup(id: Self.usbDebuggingIntructionsWindowId) {
            EnableUSBDebuggingInstructionsView()
        }
    }
}
