import SwiftUI

/// The content and presentation policy applied by `Arthur.update(_:to:)`.
///
/// Updates retain the original toast lifecycle and dismissal callback.
@MainActor
public struct ArthurUpdate {
    enum Kind {
        case loading
        case style(ArthurStyle, systemImageOverride: String?, tintOverride: Color?)
    }

    let kind: Kind
    let title: String
    let subtitle: String?
    let duration: ArthurDuration?
    let action: ArthurAction?

    var systemImageOverride: String? {
        switch kind {
        case .loading: nil
        case let .style(_, systemImageOverride, _): systemImageOverride
        }
    }

    var tintOverride: Color? {
        switch kind {
        case .loading: nil
        case let .style(_, _, tintOverride): tintOverride
        }
    }

    var isLoadingUpdate: Bool {
        if case .loading = kind { return true }
        return false
    }

    /// Creates a loading update. Loading defaults to `.untilDismissed`.
    public static func loading(
        _ title: String,
        subtitle: String? = nil,
        duration: ArthurDuration = .untilDismissed,
        action: ArthurAction? = nil
    ) -> ArthurUpdate {
        ArthurUpdate(kind: .loading, title: title, subtitle: subtitle, duration: duration, action: action)
    }

    /// Creates a success update using the green semantic style.
    public static func success(
        _ title: String,
        subtitle: String? = nil,
        duration: ArthurDuration? = nil,
        action: ArthurAction? = nil,
        systemImage: String? = nil,
        tint: Color? = nil
    ) -> ArthurUpdate {
        ArthurUpdate(kind: .style(.success, systemImageOverride: systemImage, tintOverride: tint), title: title, subtitle: subtitle, duration: duration, action: action)
    }

    /// Creates an error update using the red semantic style.
    public static func error(
        _ title: String,
        subtitle: String? = nil,
        duration: ArthurDuration? = nil,
        action: ArthurAction? = nil,
        systemImage: String? = nil,
        tint: Color? = nil
    ) -> ArthurUpdate {
        ArthurUpdate(kind: .style(.error, systemImageOverride: systemImage, tintOverride: tint), title: title, subtitle: subtitle, duration: duration, action: action)
    }

    /// Creates a warning update using the orange semantic style.
    public static func warning(
        _ title: String,
        subtitle: String? = nil,
        duration: ArthurDuration? = nil,
        action: ArthurAction? = nil,
        systemImage: String? = nil,
        tint: Color? = nil
    ) -> ArthurUpdate {
        ArthurUpdate(kind: .style(.warning, systemImageOverride: systemImage, tintOverride: tint), title: title, subtitle: subtitle, duration: duration, action: action)
    }

    /// Creates an informational update using the blue semantic style.
    public static func info(
        _ title: String,
        subtitle: String? = nil,
        duration: ArthurDuration? = nil,
        action: ArthurAction? = nil,
        systemImage: String? = nil,
        tint: Color? = nil
    ) -> ArthurUpdate {
        ArthurUpdate(kind: .style(.info, systemImageOverride: systemImage, tintOverride: tint), title: title, subtitle: subtitle, duration: duration, action: action)
    }

    /// Creates a custom-style update using an SF Symbol and tint.
    public static func custom(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String,
        tint: Color,
        duration: ArthurDuration? = nil,
        action: ArthurAction? = nil
    ) -> ArthurUpdate {
        ArthurUpdate(kind: .style(.custom(systemImage: systemImage, tint: tint), systemImageOverride: nil, tintOverride: nil), title: title, subtitle: subtitle, duration: duration, action: action)
    }

    private init(kind: Kind, title: String, subtitle: String?, duration: ArthurDuration?, action: ArthurAction?) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.duration = duration
        self.action = action
    }
}
