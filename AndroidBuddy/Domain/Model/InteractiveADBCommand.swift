//
//  InteractiveADBCommand.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 11/5/2024.
//

import Foundation
import Combine

/// Invoke this handler to write to the input file for the process of the ADB command
typealias ADBWriteHandler = ((String) -> Void)

/// A convenience struct that for an interactive ADB command that allows writing to the processes input.
struct InteractiveADBCommand<T> {
    let publisher: any Publisher<T, Error>
    let writeHandler: ADBWriteHandler
}

// MARK: - Combine Wrappers

extension InteractiveADBCommand {
    
    func map<G>(_ transform: @escaping (T) -> G) -> InteractiveADBCommand<G> {
        let transformedPublisher = publisher
            .eraseToAnyPublisher()
            .map(transform)
            .eraseToAnyPublisher()
        
        return InteractiveADBCommand<G>(publisher: transformedPublisher, writeHandler: writeHandler)
    }
    
    func tryMap<G>(_ transform: @escaping (T) throws -> G) -> InteractiveADBCommand<G> {
        let transformedPublisher = publisher
            .eraseToAnyPublisher()
            .tryMap(transform)
            .eraseToAnyPublisher()
        
        return InteractiveADBCommand<G>(publisher: transformedPublisher, writeHandler: writeHandler)
    }
}
