//
//  ADBErrorViewModel.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 12/4/2024.
//

import Foundation

class ADBErrorViewModel {
    
    private let adbService: ADBService
    
    init(adbService: ADBService) {
        self.adbService = adbService
    }
    
    func restartAdb() {
        adbService.resetServer()
    }
}
