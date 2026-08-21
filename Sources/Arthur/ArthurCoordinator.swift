import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ArthurCoordinator: ObservableObject {
    @Published private(set) var currentToast: ArthurToast?
    @Published private(set) var configuration = ArthurConfiguration()

    private struct TimerState {
        let toastID: UUID
        var remaining: Duration
        var segmentStartedAt: ContinuousClock.Instant?
        var isPaused: Bool
    }

    private let clock = ContinuousClock()
    private var timerState: TimerState?
    private var dismissalTask: Task<Void, Never>?
    private var dismissalCallbacks: [UUID: @MainActor (ArthurDismissReason) -> Void] = [:]
    private var actionHandlers: [UUID: @MainActor () -> Void] = [:]
    private var activeDragToastIDs: Set<UUID> = []

    deinit { dismissalTask?.cancel() }

    func configure(_ update: (inout ArthurConfiguration) -> Void) {
        var next = configuration
        update(&next)
        configuration = next
    }

    func show(
        title: String,
        subtitle: String?,
        style: ArthurStyle,
        systemImageOverride: String? = nil,
        tintOverride: Color? = nil,
        duration: ArthurDuration?,
        action: ArthurAction?,
        isLoading: Bool = false,
        accessibilityAnnouncement: String?,
        onDismiss: (@MainActor (ArthurDismissReason) -> Void)?
    ) -> ArthurToastHandle {
        if let currentToast {
            finalize(toastID: currentToast.id, reason: .replaced)
        }

        var toast = ArthurToast(
            title: title,
            subtitle: subtitle,
            style: style,
            duration: duration ?? configuration.defaultDuration,
            accessibilityAnnouncement: accessibilityAnnouncement,
            systemImageOverride: systemImageOverride,
            tintOverride: tintOverride
        )
        toast.actionTitle = action?.title
        toast.isLoading = isLoading
        currentToast = toast
        if let onDismiss { dismissalCallbacks[toast.id] = onDismiss }
        if let action { actionHandlers[toast.id] = action.perform }
        ArthurFeedback.play(for: style, enabled: configuration.hapticsEnabled)
        ArthurAccessibility.announce(toast.accessibilityAnnouncement)
        startTimer(for: toast)
        return ArthurToastHandle(id: toast.id)
    }

    func dismiss() {
        guard let currentToast else { return }
        finalize(toastID: currentToast.id, reason: .manual)
    }

    func dismissFromSwipe() {
        guard let currentToast else { return }
        finalize(toastID: currentToast.id, reason: .swipe)
    }

    /// Removes a tracked toast without presenting it as a user dismissal.
    /// The callback is discarded because there is no public cancellation reason
    /// in this version of Arthur.
    func cancelTrackedToast(_ toastID: UUID) {
        guard currentToast?.id == toastID else { return }
        dismissalTask?.cancel()
        dismissalTask = nil
        timerState = nil
        actionHandlers.removeValue(forKey: toastID)
        activeDragToastIDs.remove(toastID)
        currentToast = nil
        dismissalCallbacks.removeValue(forKey: toastID)
    }

    func performAction(for toastID: UUID) {
        guard currentToast?.id == toastID else { return }
        guard let handler = actionHandlers.removeValue(forKey: toastID) else { return }

        dismissalTask?.cancel()
        dismissalTask = nil
        timerState = nil
        currentToast = nil

        handler()
        let callback = dismissalCallbacks.removeValue(forKey: toastID)
        callback?(.action)
    }

    @discardableResult
    func update(_ handle: ArthurToastHandle, to update: ArthurUpdate) -> Bool {
        guard let currentToast = self.currentToast, currentToast.id == handle.id else { return false }

        let wasLoading = currentToast.isLoading
        let dragIsActive = activeDragToastIDs.contains(handle.id)
        let updatedStyle: ArthurStyle
        let updatedSystemImageOverride: String?
        let updatedTintOverride: Color?
        let updatedIsLoading: Bool
        switch update.kind {
        case .loading:
            updatedStyle = .info
            updatedSystemImageOverride = update.systemImageOverride
            updatedTintOverride = update.tintOverride
            updatedIsLoading = true
        case let .style(style, systemImageOverride, tintOverride):
            updatedStyle = style
            updatedSystemImageOverride = systemImageOverride
            updatedTintOverride = tintOverride
            updatedIsLoading = false
        }

        actionHandlers.removeValue(forKey: handle.id)
        var updatedToast = ArthurToast(
            id: currentToast.id,
            title: update.title,
            subtitle: update.subtitle,
            style: updatedStyle,
            duration: update.duration ?? (updatedIsLoading ? .untilDismissed : configuration.defaultDuration),
            accessibilityAnnouncement: nil,
            systemImageOverride: updatedSystemImageOverride,
            tintOverride: updatedTintOverride
        )
        updatedToast.actionTitle = update.action?.title
        updatedToast.isLoading = updatedIsLoading
        self.currentToast = updatedToast
        if let action = update.action { actionHandlers[handle.id] = action.perform }

        startTimer(for: updatedToast)
        if dragIsActive, updatedToast.duration.timeoutInterval != nil {
            pauseAutoDismiss(for: handle.id)
        }

        if wasLoading, !updatedIsLoading {
            ArthurFeedback.play(for: updatedStyle, enabled: configuration.hapticsEnabled)
        }
        ArthurAccessibility.announce(updatedToast.accessibilityAnnouncement)
        return true
    }

    func pauseAutoDismiss(for toastID: UUID) {
        guard currentToast?.id == toastID else { return }
        activeDragToastIDs.insert(toastID)
        guard var state = timerState, state.toastID == toastID, !state.isPaused else { return }
        guard let startedAt = state.segmentStartedAt else { return }
        let elapsed = startedAt.duration(to: clock.now)
        state.remaining = max(.zero, state.remaining - elapsed)
        state.segmentStartedAt = nil
        state.isPaused = true
        timerState = state
        dismissalTask?.cancel()
        dismissalTask = nil
    }

    func resumeAutoDismiss(for toastID: UUID) {
        activeDragToastIDs.remove(toastID)
        guard currentToast?.id == toastID, var state = timerState, state.toastID == toastID, state.isPaused else { return }
        state.isPaused = false
        state.segmentStartedAt = clock.now
        timerState = state
        scheduleTimer(for: toastID)
    }

    private func startTimer(for toast: ArthurToast) {
        dismissalTask?.cancel()
        dismissalTask = nil
        timerState = nil

        guard let seconds = toast.duration.timeoutInterval else { return }
        let remaining = Duration.seconds(seconds)
        timerState = TimerState(toastID: toast.id, remaining: remaining, segmentStartedAt: clock.now, isPaused: false)
        scheduleTimer(for: toast.id)
    }

    private func scheduleTimer(for toastID: UUID) {
        dismissalTask?.cancel()
        guard let state = timerState, state.toastID == toastID, !state.isPaused else { return }
        let remaining = state.remaining
        dismissalTask = Task { [weak self] in
            do { try await Task.sleep(for: remaining) } catch { return }
            guard !Task.isCancelled else { return }
            guard let self,
                  self.currentToast?.id == toastID,
                  self.timerState?.toastID == toastID,
                  self.timerState?.isPaused == false
            else { return }
            self.finalize(toastID: toastID, reason: .timeout)
        }
    }

    private func finalize(toastID: UUID, reason: ArthurDismissReason) {
        guard currentToast?.id == toastID else { return }
        dismissalTask?.cancel()
        dismissalTask = nil
        timerState = nil
        actionHandlers.removeValue(forKey: toastID)
        activeDragToastIDs.remove(toastID)
        currentToast = nil
        let callback = dismissalCallbacks.removeValue(forKey: toastID)
        callback?(reason)
    }
}

private enum ArthurFeedback {
    static func play(for style: ArthurStyle, enabled: Bool) {
        guard enabled else { return }
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        switch style {
        case .success: generator.notificationOccurred(.success)
        case .error: generator.notificationOccurred(.error)
        case .warning: generator.notificationOccurred(.warning)
        case .info, .custom: break
        }
        #endif
    }
}

private enum ArthurAccessibility {
    static func announce(_ message: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
}
