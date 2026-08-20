import Foundation

extension Arthur {
    /// Tracks an async operation with a loading toast and static success/error messages.
    ///
    /// The operation's value is returned unchanged and its original error is rethrown.
    /// Cancelling the task removes the tracked toast if it is still current, does not
    /// show a success or error toast, and rethrows cancellation. Dismissing or replacing
    /// the loading toast does not cancel the operation; its later update is ignored.
    /// The operation closure is not MainActor-isolated.
    public static func track<T>(
        loading: String,
        success: String,
        error: String,
        onDismiss: (@MainActor (ArthurDismissReason) -> Void)? = nil,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await track(
            loading: .loading(loading),
            success: .success(success),
            error: .error(error),
            onDismiss: onDismiss,
            operation: operation
        )
    }

    /// Tracks an async operation using existing loading and update payloads.
    ///
    /// `loading` must be created with `ArthurUpdate.loading(...)`. The operation's
    /// value is returned unchanged and its original error is rethrown. Cancelling
    /// the task removes the tracked toast if it is still current, without showing
    /// a success or error toast. Dismissing or replacing the loading toast does not
    /// cancel the operation; its later update is a harmless stale-handle no-op.
    /// Rich success and error updates retain their duration, subtitle, and action
    /// behavior. The operation closure is not MainActor-isolated.
    public static func track<T>(
        loading: ArthurUpdate,
        success: ArthurUpdate,
        error: ArthurUpdate,
        onDismiss: (@MainActor (ArthurDismissReason) -> Void)? = nil,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        guard loading.isLoadingUpdate else {
            throw ArthurTrackError.invalidLoadingUpdate
        }

        let handle = Arthur.loading(
            loading.title,
            subtitle: loading.subtitle,
            duration: loading.duration ?? .untilDismissed,
            action: loading.action,
            onDismiss: onDismiss
        )

        do {
            let result = try await operation()
            guard !Task.isCancelled else {
                cancelTrackedToast(handle)
                throw CancellationError()
            }
            _ = Arthur.update(handle, to: success)
            return result
        } catch let operationError {
            if operationError is CancellationError || Task.isCancelled {
                cancelTrackedToast(handle)
                if operationError is CancellationError { throw operationError }
                throw CancellationError()
            }

            _ = Arthur.update(handle, to: error)
            throw operationError
        }
    }
}

private enum ArthurTrackError: Error {
    case invalidLoadingUpdate
}
