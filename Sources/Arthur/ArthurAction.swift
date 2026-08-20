/// A single synchronous main-actor action shown inside a toast.
///
/// Triggering an action dismisses its toast and invokes the handler once.
@MainActor
public struct ArthurAction {
    /// The text displayed by the action button.
    public let title: String

    private let handler: @MainActor () -> Void

    /// Creates an action with a button title and synchronous handler.
    public init(_ title: String, action: @escaping @MainActor () -> Void) {
        self.title = title
        self.handler = action
    }

    func perform() {
        handler()
    }
}
