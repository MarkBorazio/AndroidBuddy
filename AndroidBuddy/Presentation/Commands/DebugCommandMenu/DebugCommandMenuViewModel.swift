//
//  DebugCommandMenuViewModel.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 1/5/2024.
//

import Foundation
import Combine

class DebugCommandMenuViewModel: ObservableObject {
    
    @Published var verboseLoggingEnabled: Bool
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        verboseLoggingEnabled = Logger.verboseLoggingEnabled
        
        $verboseLoggingEnabled
            .sink {
                Logger.verboseLoggingEnabled = $0
            }
            .store(in: &cancellables)
    }
}
