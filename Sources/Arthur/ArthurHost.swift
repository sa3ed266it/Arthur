import SwiftUI

/// Installs Arthur's toast overlay. Add it once at an app root.
public struct ArthurHost: ViewModifier {
    /// Overlays the current Arthur toast above the modified content.
    public func body(content: Content) -> some View {
        ArthurHostView(content: content)
    }
}

private struct ArthurHostView<Content: View>: View {
    let content: Content
    @StateObject private var coordinator: ArthurCoordinator

    init(content: Content) {
        self.content = content
        _coordinator = StateObject(wrappedValue: Arthur.coordinator)
    }

    var body: some View {
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
