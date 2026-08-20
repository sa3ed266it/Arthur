/// Explains why a toast stopped being the active presentation.
public enum ArthurDismissReason: Sendable, Equatable {
    /// The toast's finite duration elapsed.
    case timeout
    /// The user completed a swipe-to-dismiss gesture.
    case swipe
    /// `Arthur.dismiss()` was called.
    case manual
    /// A newer toast replaced this toast.
    case replaced
    /// The toast's action button was triggered.
    case action
}
