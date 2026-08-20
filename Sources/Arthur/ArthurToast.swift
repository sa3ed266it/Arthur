import Foundation

/// A single notification presented by Arthur.
public struct ArthurToast: Identifiable, Equatable {
    /// Stable identity used to protect replacement and dismissal lifecycles.
    public let id: UUID
    /// Primary toast message.
    public let title: String
    /// Optional secondary message.
    public let subtitle: String?
    /// Semantic or custom visual style.
    public let style: ArthurStyle
    /// Auto-dismiss policy for this toast.
    public let duration: ArthurDuration
    /// VoiceOver label; generated from title and subtitle when omitted.
    public let accessibilityAnnouncement: String

    /// Internal display metadata for the optional action button.
    var actionTitle: String?
    /// Internal rendering state for native loading content.
    var isLoading: Bool

    /// Creates a toast value for presentation through Arthur.
    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        style: ArthurStyle = .info,
        duration: ArthurDuration = .normal,
        accessibilityAnnouncement: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.duration = duration
        self.actionTitle = nil
        self.isLoading = false
        self.accessibilityAnnouncement = accessibilityAnnouncement ?? [title, subtitle]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
