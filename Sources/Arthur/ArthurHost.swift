import SwiftUI

/// Installs Arthur's toast overlay. Add it once at an app root.
public struct ArthurHost: ViewModifier {
    @ObservedObject private var coordinator = Arthur.coordinator

    /// Overlays the current Arthur toast above the modified content.
    public func body(content: Content) -> some View {
        content.overlay(alignment: coordinator.configuration.position == .top ? .top : .bottom) {
            ArthurToastView(
                toast: coordinator.currentToast,
                position: coordinator.configuration.position,
                swipeToDismiss: coordinator.configuration.swipeToDismiss,
                surfaceStyle: coordinator.configuration.surfaceStyle,
                dismiss: Arthur.dismissFromSwipe
            )
                .padding(.horizontal, 16)
                .padding(.top, coordinator.configuration.position == .top ? 8 : 0)
                .padding(.bottom, coordinator.configuration.position == .bottom ? 12 : 0)
        }
    }
}

public extension View {
    /// Adds Arthur's toast presentation host. Call this once on the app's root view.
    func arthur() -> some View { modifier(ArthurHost()) }
}
