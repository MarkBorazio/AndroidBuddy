//
//  Device.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 13/4/2024.
//

import Foundation

// Colated device information that comes from multiple adb commands
struct Device: Equatable, Hashable {
    let bluetoothName: String?
    let serial: String
}
