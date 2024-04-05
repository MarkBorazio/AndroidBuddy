//
//  AsyncCombineExtensions.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 4/4/2024.
//

import Combine

// Ref: https://www.swiftbysundell.com/articles/calling-async-functions-within-a-combine-pipeline/
extension Publisher {
    
    func asyncMap<T>(
        _ transform: @escaping (Output) async -> T
    ) -> Publishers.FlatMap<Future<T, Never>, Self> {
        flatMap { value in
            Future { promise in
                Task {
                    let output = await transform(value)
                    promise(.success(output))
                }
            }
        }
    }
    
    func asyncTryMap<T>(
        _ transform: @escaping (Output) async throws -> T
    ) -> Publishers.FlatMap<Future<T, Error>, Self> {
        flatMap { value in
            Future { promise in
                Task {
                    do {
                        let output = try await transform(value)
                        promise(.success(output))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }
    }
    
    func asyncTryMap<T>(
        _ transform: @escaping (Output) async throws -> T
    ) -> Publishers.FlatMap<Future<T, Error>, Publishers.SetFailureType<Self, Error>> {
        flatMap { value in
            Future { promise in
                Task {
                    do {
                        let output = try await transform(value)
                        promise(.success(output))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }
    }
    
    func asyncCompactMap<T>(
        _ transform: @escaping (Output) async -> T?
    ) -> Publishers.CompactMap<Publishers.FlatMap<Future<T?, Never>, Self>, T> {
        asyncMap(transform)
            .compactMap { $0 }
    }
    
    func asyncTryCompactMap<T>(
        _ transform: @escaping (Output) async throws -> T?
    ) -> Publishers.CompactMap<Publishers.FlatMap<Future<T?, Error>, Self>, T> {
        asyncTryMap(transform)
            .compactMap { $0 }
    }
    
    func asyncTryCompactMap<T>(
        _ transform: @escaping (Output) async throws -> T?
    ) -> Publishers.CompactMap<Publishers.FlatMap<Future<T?, Error>, Publishers.SetFailureType<Self, Error>>, T> {
        asyncTryMap(transform)
            .compactMap { $0 }
    }
    
}
