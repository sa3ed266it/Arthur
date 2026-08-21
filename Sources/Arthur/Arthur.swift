import SwiftUI

/// The public entry point for configuring and presenting lightweight toasts.
@MainActor
public enum Arthur {
    static let coordinator = ArthurCoordinator()

    /// Updates Arthur's global configuration.
    public static func configure(_ update: (inout ArthurConfiguration) -> Void) {
        coordinator.configure(update)
    }

    /// Presents a toast with the supplied content and style.
    ///
    /// An action button always dismisses the toast and reports `.action`.
    /// The action handler runs before `onDismiss`.
    public static func show(
        title: String,
        subtitle: String? = nil,
        style: ArthurStyle = .info,
        duration: ArthurDuration? = nil,
        action: ArthurAction? = nil,
        accessibilityAnnouncement: String? = nil,
        onDismiss: (@MainActor (ArthurDismissReason) -> Void)? = nil,
        systemImage: String? = nil,
        tint: Color? = nil
    ) {
        _ = coordinator.show(title: title, subtitle: subtitle, style: style, systemImageOverride: systemImage, tintOverride: tint, duration: duration, action: action, accessibilityAnnouncement: accessibilityAnnouncement, onDismiss: onDismiss)
    }

    /// Presents a loading toast and returns its lifecycle handle.
    ///
    /// Loading defaults to `.untilDismissed`. Supply a finite duration to opt
    /// into automatic dismissal before updating or dismissing the toast.
    @discardableResult
    public static func loading(
        _ title: String,
        subtitle: String? = nil,
        duration: ArthurDuration = .untilDismissed,
        action: ArthurAction? = nil,
        onDismiss: (@MainActor (ArthurDismissReason) -> Void)? = nil,
        systemImage: String? = nil,
        tint: Color? = nil
    ) -> ArthurToastHandle {
        coordinator.show(title: title, subtitle: subtitle, style: .info, systemImageOverride: systemImage, tintOverride: tint, duration: duration, action: action, isLoading: true, accessibilityAnnouncement: nil, onDismiss: onDismiss)
    }

    /// Updates the current toast in place without replacing its identity.
    ///
    /// Returns `false` for stale or dismissed handles. The original dismissal
    /// callback remains attached to the lifecycle across all updates.
    @discardableResult
    public static func update(_ handle: ArthurToastHandle, to update: ArthurUpdate) -> Bool {
        coordinator.update(handle, to: update)
    }

    /// Presents a success toast using the green semantic style.
    public static func success(_ title: String, subtitle: String? = nil, duration: ArthurDuration? = nil, action: ArthurAction? = nil, onDismiss: (@MainActor (ArthurDismissReason) -> Void)? = nil, systemImage: String? = nil, tint: Color? = nil) {
        show(title: title, subtitle: subtitle, style: .success, duration: duration, action: action, onDismiss: onDismiss, systemImage: systemImage, tint: tint)
    }

    /// Presents an error toast using the red semantic style.
    public static func error(_ title: String, subtitle: String? = nil, duration: ArthurDuration? = nil, action: ArthurAction? = nil, onDismiss: (@MainActor (ArthurDismissReason) -> Void)? = nil, systemImage: String? = nil, tint: Color? = nil) {
        show(title: title, subtitle: subtitle, style: .error, duration: duration, action: action, onDismiss: onDismiss, systemImage: systemImage, tint: tint)
    }

    /// Presents a warning toast using the orange semantic style.
    public static func warning(_ title: String, subtitle: String? = nil, duration: ArthurDuration? = nil, action: ArthurAction? = nil, onDismiss: (@MainActor (ArthurDismissReason) -> Void)? = nil, systemImage: String? = nil, tint: Color? = nil) {
        show(title: title, subtitle: subtitle, style: .warning, duration: duration, action: action, onDismiss: onDismiss, systemImage: systemImage, tint: tint)
    }

    /// Presents an informational toast using the blue semantic style.
    public static func info(_ title: String, subtitle: String? = nil, duration: ArthurDuration? = nil, action: ArthurAction? = nil, onDismiss: (@MainActor (ArthurDismissReason) -> Void)? = nil, systemImage: String? = nil, tint: Color? = nil) {
        show(title: title, subtitle: subtitle, style: .info, duration: duration, action: action, onDismiss: onDismiss, systemImage: systemImage, tint: tint)
    }

    /// Dismisses the currently visible toast, if any, reporting `.manual`.
    public static func dismiss() { coordinator.dismiss() }

    static func performAction(for toastID: UUID) { coordinator.performAction(for: toastID) }

    static func dismissFromSwipe() { coordinator.dismissFromSwipe() }

    static func cancelTrackedToast(_ handle: ArthurToastHandle) {
        coordinator.cancelTrackedToast(handle.id)
    }

    static func pauseAutoDismiss(for toastID: UUID) { coordinator.pauseAutoDismiss(for: toastID) }

    static func resumeAutoDismiss(for toastID: UUID) { coordinator.resumeAutoDismiss(for: toastID) }
}
