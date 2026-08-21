import SwiftUI

/// ObservableObject wrapper for a single mutable value.
/// Used as a replacement for @State when the SwiftUI macros plugin is unavailable.
final class StateValue<T>: ObservableObject {
    @Published var value: T
    init(_ value: T) { self.value = value }
}

/// ObservableObject wrapper for an optional mutable value.
final class OptionalStateValue<T>: ObservableObject {
    @Published var value: T?
    init(_ value: T? = nil) { self.value = value }
}
