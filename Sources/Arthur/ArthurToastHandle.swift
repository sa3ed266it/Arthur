import Foundation

/// An opaque, copyable identity for one toast lifecycle.
///
/// A handle does not retain Arthur or a view. Once its toast is dismissed or
/// replaced, updates using the handle safely return `false` and do nothing.
public struct ArthurToastHandle: Hashable, Sendable {
    let id: UUID

    init(id: UUID) {
        self.id = id
    }
}
