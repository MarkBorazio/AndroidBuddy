//
//  ConditionalView.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 6/5/2024.
//

import SwiftUI

// Ref: https://www.avanderlee.com/swiftui/conditional-view-modifier/
extension View {
    
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: @autoclosure () -> Bool, transform: (Self) -> Content) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }
}
