//
//  AndroidBuddyApp.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 1/4/2024.
//

import SwiftUI

@main
struct AndroidBuddyApp: App {
    
    init() {
        _ = AdbService.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
