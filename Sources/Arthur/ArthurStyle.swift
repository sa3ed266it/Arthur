import SwiftUI

/// The visual treatment and semantic meaning of a toast.
public enum ArthurStyle: Equatable {
    /// Uses Arthur's success icon and green semantic tint.
    case success
    /// Uses Arthur's error icon and red semantic tint.
    case error
    /// Uses Arthur's warning icon and orange semantic tint.
    case warning
    /// Uses Arthur's information icon and blue semantic tint.
    case info
    /// Uses a custom SF Symbol name and tint color.
    case custom(systemImage: String, tint: Color)

    var systemImage: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        case let .custom(systemImage, _): systemImage
        }
    }

    var tint: Color {
        switch self {
        case .success: .green
        case .error: .red
        case .warning: .orange
        case .info: .blue
        case let .custom(_, tint): tint
        }
    }
}
