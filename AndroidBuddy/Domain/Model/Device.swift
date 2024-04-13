//
//  Device.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 13/4/2024.
//

import Foundation

// Colated device information that comes from multiple adb commands
struct Device: Equatable, Hashable {
    let bluetoothName: String // For now I am assuming this can just be treated as the name - not sure what happens if device has no blueooth
    let serial: String
}
