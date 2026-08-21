import Foundation
import SwiftUI

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
    /// Optional SF Symbol override; semantic style remains unchanged.
    public let systemImageOverride: String?
    /// Optional tint override; semantic style remains unchanged.
    public let tintOverride: Color?
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
        accessibilityAnnouncement: String? = nil,
        systemImageOverride: String? = nil,
        tintOverride: Color? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.systemImageOverride = systemImageOverride
        self.tintOverride = tintOverride
        self.duration = duration
        self.actionTitle = nil
        self.isLoading = false
        self.accessibilityAnnouncement = accessibilityAnnouncement ?? [title, subtitle]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
