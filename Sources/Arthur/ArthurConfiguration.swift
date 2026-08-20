import Foundation

/// The vertical placement of Arthur's toast overlay.
public enum ArthurPosition: Sendable, Equatable {
    /// Places the toast near the top safe area; toasts swipe upward.
    case top
    /// Places the toast near the bottom safe area; toasts swipe downward.
    case bottom
}

/// Global presentation settings for Arthur.
public struct ArthurConfiguration: Sendable {
    /// The duration used when `show` does not specify one. Defaults to `.normal` (2.2 seconds).
    public var defaultDuration: ArthurDuration = .normal
    /// Whether semantic notification haptics are generated on supported devices.
    public var hapticsEnabled = true
    /// Whether to present the toast near the top or bottom safe area.
    public var position: ArthurPosition = .top
    /// Whether visible toasts can be dismissed with a position-aware vertical swipe.
    public var swipeToDismiss = true
    /// The toast card surface. Defaults to Arthur's original material appearance.
    public var surfaceStyle: ArthurSurfaceStyle = .material

    /// Creates configuration with Arthur's default settings.
    public init() {}
}
