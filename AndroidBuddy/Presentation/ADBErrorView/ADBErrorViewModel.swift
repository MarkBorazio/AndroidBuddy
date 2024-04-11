//
//  ADBErrorViewModel.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 12/4/2024.
//

import Foundation

class ADBErrorViewModel {
    
    func restartAdb() {
        AdbService.shared.startServer()
    }
}
