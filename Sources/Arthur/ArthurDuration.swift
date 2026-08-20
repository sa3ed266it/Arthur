import Foundation

/// Controls how long a toast remains visible.
public enum ArthurDuration: Sendable, Equatable {
    /// A brief notification of approximately 1.5 seconds.
    case short
    /// Arthur's default notification duration of 2.2 seconds.
    case normal
    /// A longer notification of approximately 4 seconds.
    case long
    /// A custom finite duration. Invalid values are normalized to zero seconds.
    case seconds(TimeInterval)
    /// Keeps the toast visible until it is explicitly dismissed or replaced.
    case untilDismissed

    /// The finite timeout in seconds, or `nil` for `.untilDismissed`.
    var timeoutInterval: TimeInterval? {
        switch self {
        case .short: return 1.5
        case .normal: return 2.2
        case .long: return 4.0
        case let .seconds(value):
            guard value.isFinite else { return 0 }
            return max(0, value)
        case .untilDismissed: return nil
        }
    }
}
