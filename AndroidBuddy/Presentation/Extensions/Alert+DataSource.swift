//
//  Alert+DataSource.swift
//  AndroidBuddy
//
//  Created by Mark Borazio [Personal] on 25/4/2024.
//

import SwiftUI

// Presents an alert if a given data source is not nil.
// I didn't want to write this, but I didn't want to use SwiftUI's stock implementations either.
// For some reason they deprecated the function that did just this.
private struct AlertDataSourceViewModifier<T, A: View, M: View>: ViewModifier {
    
    private let titleKey: LocalizedStringKey
    private let dataSource: Binding<T?>
    @ViewBuilder private let actions: (T) -> A
    @ViewBuilder private let message: (T) -> M
    
    private let isShowing: Binding<Bool>
    
    init(
        titleKey: LocalizedStringKey,
        dataSource: Binding<T?>,
        @ViewBuilder actions: @escaping (T) -> A,
        @ViewBuilder message: @escaping (T) -> M
    ) {
        self.titleKey = titleKey
        self.dataSource = dataSource
        self.actions = actions
        self.message = message
        isShowing = Binding(
            get: {
                dataSource.wrappedValue != nil
            },
            set: { value in
                if !value {
                    dataSource.wrappedValue = nil
                }
            }
        )
    }
    
    func body(content: Content) -> some View {
        content
            .alert(
                titleKey,
                isPresented: isShowing,
                actions: {
                    if let data = dataSource.wrappedValue {
                        actions(data)
                    } else {
                        // This seems to get called once on initialisation of parent content and twice when the alert is dismissed.
                        EmptyView()
                    }
                },
                message: {
                    if let data = dataSource.wrappedValue {
                        message(data)
                    } else {
                        // This seems to get called once on initialisation of parent content and twice when the alert is dismissed.
                        EmptyView()
                    }
                }
            )
    }
}

extension View {
    
    /// Presents an alert when the data source is not nil.
    ///
    /// Set the data source to nil to dismiss the alert.
    /// The data source is also no expected to change while the alert is being presented.
    func alert<T, A: View, M: View>(
        _ titleKey: LocalizedStringKey,
        dataSource: Binding<T?>,
        @ViewBuilder actions: @escaping (T) -> A,
        @ViewBuilder message: @escaping (T) -> M
    ) -> some View {
        modifier(
            AlertDataSourceViewModifier(
                titleKey: titleKey,
                dataSource: dataSource,
                actions: actions,
                message: message
            )
        )
    }
}
