//
//  InteractiveADBCommand.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 11/5/2024.
//

import Foundation
import Combine

typealias ADBWriteHandler = ((String) -> Void)

/// A convenience struct for an interactive ADB command that allows writing to the process' input.
struct InteractiveADBCommand<T> {
    let publisher: any Publisher<T, Error>
    /// Invoke this handler to write to the input file for the process of the ADB command.
    let writeHandler: ADBWriteHandler
}

// MARK: - Combine Wrappers

extension InteractiveADBCommand {
    
    func map<G>(_ transform: @escaping (T) -> G) -> InteractiveADBCommand<G> {
        let transformedPublisher = publisher
            .eraseToAnyPublisher()
            .map(transform)
        
        return InteractiveADBCommand<G>(publisher: transformedPublisher, writeHandler: writeHandler)
    }
    
    func tryMap<G>(_ transform: @escaping (T) throws -> G) -> InteractiveADBCommand<G> {
        let transformedPublisher = publisher
            .eraseToAnyPublisher()
            .tryMap(transform)
        
        return InteractiveADBCommand<G>(publisher: transformedPublisher, writeHandler: writeHandler)
    }
}
