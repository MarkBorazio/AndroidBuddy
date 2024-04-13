//
//  StandardDependencies.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 13/4/2024.
//

import Foundation

class StandardDependencies {
    
    static let shared = StandardDependencies()
    
    let adbService: ADBService
    
    init() {
        adbService = StandardAdbService()
    }
}
