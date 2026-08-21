import XCTest
@testable import Arthur

@MainActor
final class ArthurTests: XCTestCase {
    private enum TrackError: Error, Equatable {
        case failed
    }

    override func setUp() {
        super.setUp()
        Arthur.dismiss()
        Arthur.configure {
            $0.defaultDuration = .normal
            $0.hapticsEnabled = true
            $0.position = .top
            $0.swipeToDismiss = true
            $0.surfaceStyle = .material
        }
    }

    func testNoToastInitially() {
        XCTAssertNil(Arthur.coordinator.currentToast)
    }

    func testSuccessPreservesTitleAndSubtitle() {
        Arthur.success("Saved", subtitle: "Expense added", duration: .seconds(1))
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Saved")
        XCTAssertEqual(Arthur.coordinator.currentToast?.subtitle, "Expense added")
        XCTAssertEqual(Arthur.coordinator.currentToast?.style, .success)
    }

    func testDefaultSuccessUsesSemanticIconAndTint() {
        Arthur.success("Saved")

        XCTAssertNil(Arthur.coordinator.currentToast?.systemImageOverride)
        XCTAssertNil(Arthur.coordinator.currentToast?.tintOverride)
        XCTAssertEqual(Arthur.coordinator.currentToast?.style, .success)
        XCTAssertEqual(Arthur.coordinator.currentToast?.style.systemImage, "checkmark.circle.fill")
        XCTAssertEqual(Arthur.coordinator.currentToast?.style.tint, .green)
    }

    func testSemanticSuccessPreservesStyleWithVisualOverrides() {
        Arthur.success("Income added", systemImage: "arrow.down.circle.fill", tint: .green)

        XCTAssertEqual(Arthur.coordinator.currentToast?.style, .success)
        XCTAssertEqual(Arthur.coordinator.currentToast?.systemImageOverride, "arrow.down.circle.fill")
        XCTAssertEqual(Arthur.coordinator.currentToast?.tintOverride, .green)
    }

    func testLoadingToSuccessUpdateRetainsToastIdentityWithVisualOverrides() {
        let handle = Arthur.loading("Saving...")
        let originalID = Arthur.coordinator.currentToast?.id

        XCTAssertTrue(Arthur.update(
            handle,
            to: .success(
                "Saved",
                systemImage: "arrow.uturn.backward.circle.fill",
                tint: .green
            )
        ))

        XCTAssertEqual(Arthur.coordinator.currentToast?.id, originalID)
        XCTAssertEqual(Arthur.coordinator.currentToast?.style, .success)
        XCTAssertEqual(Arthur.coordinator.currentToast?.systemImageOverride, "arrow.uturn.backward.circle.fill")
        XCTAssertEqual(Arthur.coordinator.currentToast?.tintOverride, .green)
        XCTAssertFalse(Arthur.coordinator.currentToast?.isLoading == true)
    }

    func testErrorUsesErrorStyle() {
        Arthur.error("Failed")
        XCTAssertEqual(Arthur.coordinator.currentToast?.style, .error)
    }

    func testNewToastReplacesPreviousToast() {
        Arthur.info("First", duration: .seconds(1))
        let firstID = Arthur.coordinator.currentToast?.id
        Arthur.warning("Second", duration: .seconds(1))
        XCTAssertNotEqual(Arthur.coordinator.currentToast?.id, firstID)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Second")
    }

    func testStaleDismissalCannotDismissReplacement() async throws {
        Arthur.info("First", duration: .seconds(0.03))
        Arthur.success("Second", duration: .seconds(0.15))
        try await Task.sleep(nanoseconds: 70_000_000)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Second")
    }

    func testAutomaticDismissalClearsToast() async throws {
        Arthur.info("Short", duration: .seconds(0.02))
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertNil(Arthur.coordinator.currentToast)
    }

    func testManualDismissalClearsToast() {
        Arthur.warning("Dismiss me")
        Arthur.dismiss()
        XCTAssertNil(Arthur.coordinator.currentToast)
    }

    func testCustomDurationIsStored() {
        Arthur.show(title: "Custom", style: .custom(systemImage: "heart.fill", tint: .pink), duration: .seconds(4.5))
        XCTAssertEqual(Arthur.coordinator.currentToast?.duration, .seconds(4.5))
    }

    func testCustomAccessibilityAnnouncementIsPreserved() {
        Arthur.show(title: "Saved", style: .success, accessibilityAnnouncement: "Save completed")
        XCTAssertEqual(Arthur.coordinator.currentToast?.accessibilityAnnouncement, "Save completed")
    }

    func testConfigurationChangesAreApplied() {
        Arthur.configure {
            $0.defaultDuration = .seconds(4)
            $0.hapticsEnabled = false
            $0.position = .bottom
            $0.swipeToDismiss = false
        }
        XCTAssertEqual(Arthur.coordinator.configuration.defaultDuration, .seconds(4))
        XCTAssertFalse(Arthur.coordinator.configuration.hapticsEnabled)
        XCTAssertEqual(Arthur.coordinator.configuration.position, .bottom)
        XCTAssertFalse(Arthur.coordinator.configuration.swipeToDismiss)
        Arthur.info("Uses configured duration")
        XCTAssertEqual(Arthur.coordinator.currentToast?.duration, .seconds(4))
    }

    func testSwipeToDismissDefaultsToEnabled() {
        XCTAssertTrue(Arthur.coordinator.configuration.swipeToDismiss)
        Arthur.configure { $0.swipeToDismiss = false }
        XCTAssertFalse(Arthur.coordinator.configuration.swipeToDismiss)
    }

    func testSurfaceStyleDefaultsToMaterialAndCanOptIntoGlass() {
        XCTAssertEqual(Arthur.coordinator.configuration.surfaceStyle, .material)
        Arthur.configure { $0.surfaceStyle = .glass }
        XCTAssertEqual(Arthur.coordinator.configuration.surfaceStyle, .glass)
    }

    func testActionMetadataBelongsToTheCurrentToastAndActionDismissesOnce() {
        var handlerCount = 0
        var reasons: [ArthurDismissReason] = []
        Arthur.success(
            "Deleted",
            action: ArthurAction("Undo") { handlerCount += 1 },
            onDismiss: { reasons.append($0) }
        )

        let toastID = Arthur.coordinator.currentToast?.id
        XCTAssertEqual(Arthur.coordinator.currentToast?.actionTitle, "Undo")
        if let toastID { Arthur.coordinator.performAction(for: toastID); Arthur.coordinator.performAction(for: toastID) }

        XCTAssertEqual(handlerCount, 1)
        XCTAssertEqual(reasons, [.action])
        XCTAssertNil(Arthur.coordinator.currentToast)
    }

    func testToastWithoutActionHasNoActionMetadataOrActionPath() {
        Arthur.info("No action", duration: .untilDismissed)
        let toastID = Arthur.coordinator.currentToast?.id
        XCTAssertNil(Arthur.coordinator.currentToast?.actionTitle)
        if let toastID { Arthur.coordinator.performAction(for: toastID) }
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "No action")
    }

    func testLoadingReturnsHandleAndDefaultsToPersistentLoadingToast() {
        let handle = Arthur.loading("Uploading...")
        XCTAssertEqual(Arthur.coordinator.currentToast?.id, handle.id)
        XCTAssertTrue(Arthur.coordinator.currentToast?.isLoading == true)
        XCTAssertEqual(Arthur.coordinator.currentToast?.duration, .untilDismissed)
    }

    func testTrackSuccessReturnsValueAndUpdatesCurrentToast() async throws {
        let value = try await Arthur.track(
            loading: "Saving...",
            success: "Saved",
            error: "Save failed"
        ) {
            "server-value"
        }

        XCTAssertEqual(value, "server-value")
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Saved")
        XCTAssertFalse(Arthur.coordinator.currentToast?.isLoading == true)
    }

    func testTrackSupportsVoidOperations() async throws {
        var completed = false
        try await Arthur.track(loading: "Uploading...", success: "Uploaded", error: "Upload failed") {
            completed = true
        }

        XCTAssertTrue(completed)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Uploaded")
    }

    func testTrackFailureRethrowsOriginalErrorAndUpdatesErrorToast() async {
        do {
            _ = try await Arthur.track(loading: "Signing in...", success: "Welcome", error: "Sign in failed") {
                throw TrackError.failed
            }
            XCTFail("Expected TrackError.failed")
        } catch let error as TrackError {
            XCTAssertEqual(error, .failed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Sign in failed")
    }

    func testTrackRichSuccessPreservesActionAndDuration() async throws {
        let value = try await Arthur.track(
            loading: .loading("Uploading...", subtitle: "Please wait"),
            success: .success("Uploaded", duration: .long, action: ArthurAction("Open") {}),
            error: .error("Upload failed")
        ) {
            42
        }

        XCTAssertEqual(value, 42)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Uploaded")
        XCTAssertEqual(Arthur.coordinator.currentToast?.duration, .long)
        XCTAssertEqual(Arthur.coordinator.currentToast?.actionTitle, "Open")
    }

    func testTrackStaleSuccessDoesNotAffectNewToast() async throws {
        let task = Task { @MainActor in
            try await Arthur.track(loading: "Working...", success: "Done", error: "Failed") {
                try await Task.sleep(for: .milliseconds(60))
                return true
            }
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        Arthur.info("New notification", duration: .untilDismissed)

        let result = try await task.value
        XCTAssertTrue(result)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "New notification")
    }

    func testTrackStaleFailureRethrowsAndDoesNotAffectNewToast() async throws {
        let task = Task { @MainActor in
            do {
                _ = try await Arthur.track(loading: "Working...", success: "Done", error: "Failed") {
                    try await Task.sleep(for: .milliseconds(60))
                    throw TrackError.failed
                }
                XCTFail("Expected TrackError.failed")
                return TrackError.failed
            } catch let error as TrackError {
                return error
            } catch {
                XCTFail("Unexpected error: \(error)")
                return .failed
            }
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        Arthur.info("New notification", duration: .untilDismissed)

        let result = await task.value
        XCTAssertEqual(result, TrackError.failed)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "New notification")
    }

    func testTrackCancellationCleansCurrentToastWithoutCallingDismissalCallback() async throws {
        var callbackCount = 0
        let task = Task { @MainActor in
            try await Arthur.track(
                loading: "Working...",
                success: "Done",
                error: "Failed",
                onDismiss: { _ in callbackCount += 1 }
            ) {
                try await Task.sleep(for: .seconds(1))
                return true
            }
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertNil(Arthur.coordinator.currentToast)
            XCTAssertEqual(callbackCount, 0)
        }
    }

    func testTrackCancellationCannotDismissNewerToast() async throws {
        let task = Task { @MainActor in
            try await Arthur.track(loading: "Working...", success: "Done", error: "Failed") {
                try await Task.sleep(for: .seconds(1))
                return true
            }
        }
        try await Task.sleep(nanoseconds: 20_000_000)
        Arthur.info("New notification", duration: .untilDismissed)
        task.cancel()

        do { _ = try await task.value } catch is CancellationError {}
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "New notification")
    }

    func testLoadingAcceptsExplicitFiniteDuration() {
        let handle = Arthur.loading("Connecting...", duration: .long)
        XCTAssertEqual(Arthur.coordinator.currentToast?.id, handle.id)
        XCTAssertEqual(Arthur.coordinator.currentToast?.duration, .long)
    }

    func testUpdatePreservesIdentityWithoutReplacementOrDismissal() {
        var reasons: [ArthurDismissReason] = []
        let handle = Arthur.loading("Uploading...", onDismiss: { reasons.append($0) })
        let originalID = Arthur.coordinator.currentToast?.id

        XCTAssertTrue(Arthur.update(handle, to: .success("Uploaded")))
        XCTAssertEqual(Arthur.coordinator.currentToast?.id, originalID)
        XCTAssertFalse(Arthur.coordinator.currentToast?.isLoading == true)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Uploaded")
        XCTAssertTrue(reasons.isEmpty)
    }

    func testLoadingAndRepeatedUpdatesStayInOneLifecycle() {
        let handle = Arthur.loading("Starting...")
        let originalID = Arthur.coordinator.currentToast?.id

        XCTAssertTrue(Arthur.update(handle, to: .loading("Uploading...", subtitle: "70%")))
        XCTAssertTrue(Arthur.update(handle, to: .info("Processing...")))
        XCTAssertTrue(Arthur.update(handle, to: .success("Done")))
        XCTAssertEqual(Arthur.coordinator.currentToast?.id, originalID)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Done")
    }

    func testUpdatedDurationStartsFromUpdateMomentAndOldTimerIsCancelled() async throws {
        let handle = Arthur.loading("Uploading...", duration: .seconds(0.2))
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(Arthur.update(handle, to: .success("Uploaded", duration: .seconds(0.25))))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Uploaded")
        try await Task.sleep(nanoseconds: 220_000_000)
        XCTAssertNil(Arthur.coordinator.currentToast)
    }

    func testUpdateToPersistentFinalStateHasNoAutoDismissTimer() async throws {
        let handle = Arthur.loading("Uploading...", duration: .seconds(0.03))
        XCTAssertTrue(Arthur.update(handle, to: .error("Failed", duration: .untilDismissed)))
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Failed")
    }

    func testStaleOrDismissedHandlesCannotUpdateCurrentToast() {
        let staleHandle = Arthur.loading("A")
        Arthur.success("B")
        XCTAssertFalse(Arthur.update(staleHandle, to: .success("A finished")))
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "B")

        let dismissedHandle = Arthur.loading("Dismiss me")
        Arthur.dismiss()
        XCTAssertFalse(Arthur.update(dismissedHandle, to: .success("Resurrected")))
        XCTAssertNil(Arthur.coordinator.currentToast)
    }

    func testUpdateReplacesAndRemovesActionsSafely() {
        var oldCount = 0
        var newCount = 0
        let handle = Arthur.loading(
            "Working",
            action: ArthurAction("Cancel") { oldCount += 1 }
        )

        XCTAssertTrue(Arthur.update(handle, to: .error("Failed")))
        Arthur.coordinator.performAction(for: handle.id)
        XCTAssertEqual(oldCount, 0)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Failed")

        XCTAssertTrue(Arthur.update(handle, to: .error("Failed", action: ArthurAction("Retry") { newCount += 1 })))
        Arthur.coordinator.performAction(for: handle.id)
        XCTAssertEqual(newCount, 1)
    }

    func testUpdatedActionDismissesWithActionAndPreservesOriginalCallbackOrdering() {
        var events: [String] = []
        let handle = Arthur.loading("Connecting...", onDismiss: { reason in
            events.append("dismiss:\(reason)")
        })
        XCTAssertTrue(Arthur.update(handle, to: .error("Failed", action: ArthurAction("Retry") {
            events.append("handler")
        })))
        Arthur.coordinator.performAction(for: handle.id)
        XCTAssertEqual(events, ["handler", "dismiss:action"])
    }

    func testUpdatedActionCanPresentAnotherToastAndOldTimerCannotAffectIt() async throws {
        var reasons: [ArthurDismissReason] = []
        let handle = Arthur.loading("Connecting...", duration: .seconds(0.03), onDismiss: { reasons.append($0) })
        XCTAssertTrue(Arthur.update(handle, to: .error("Failed", action: ArthurAction("Retry") {
            Arthur.success("Restored", duration: .untilDismissed)
        })))
        Arthur.coordinator.performAction(for: handle.id)
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(reasons, [.action])
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Restored")
    }

    func testUpdateWhileDragPausedKeepsNewFiniteTimerPausedUntilResume() async throws {
        let handle = Arthur.loading("Uploading...", duration: .seconds(0.25))
        Arthur.coordinator.pauseAutoDismiss(for: handle.id)
        XCTAssertTrue(Arthur.update(handle, to: .success("Uploaded", duration: .seconds(0.20))))
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Uploaded")
        Arthur.coordinator.resumeAutoDismiss(for: handle.id)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertNil(Arthur.coordinator.currentToast)
    }

    func testDismissalReasonsRemainCorrectAfterUpdate() {
        var reasons: [ArthurDismissReason] = []
        let handle = Arthur.loading("Working", onDismiss: { reasons.append($0) })
        XCTAssertTrue(Arthur.update(handle, to: .warning("Almost full")))
        Arthur.coordinator.dismissFromSwipe()
        XCTAssertEqual(reasons, [.swipe])

        let replacementHandle = Arthur.loading("Working", onDismiss: { reasons.append($0) })
        XCTAssertTrue(Arthur.update(replacementHandle, to: .success("Done")))
        Arthur.info("Another")
        XCTAssertEqual(reasons, [.swipe, .replaced])
    }

    func testActionHandlerRunsBeforeActionDismissCallback() {
        var events: [String] = []
        Arthur.info(
            "Deleted",
            duration: .untilDismissed,
            action: ArthurAction("Undo") { events.append("handler") },
            onDismiss: { _ in events.append("dismiss") }
        )

        let toastID = Arthur.coordinator.currentToast?.id
        if let toastID { Arthur.coordinator.performAction(for: toastID) }
        XCTAssertEqual(events, ["handler", "dismiss"])
    }

    func testActionCancelsFiniteTimerAndPersistentToastCanUseAction() async throws {
        var finiteReasons: [ArthurDismissReason] = []
        Arthur.info(
            "Finite",
            duration: .seconds(0.02),
            action: ArthurAction("Undo") {},
            onDismiss: { finiteReasons.append($0) }
        )
        let finiteID = try XCTUnwrap(Arthur.coordinator.currentToast?.id)
        Arthur.coordinator.performAction(for: finiteID)
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(finiteReasons, [.action])

        var persistentReasons: [ArthurDismissReason] = []
        Arthur.info(
            "Persistent",
            duration: .untilDismissed,
            action: ArthurAction("Done") {},
            onDismiss: { persistentReasons.append($0) }
        )
        let persistentID = try XCTUnwrap(Arthur.coordinator.currentToast?.id)
        Arthur.coordinator.performAction(for: persistentID)
        XCTAssertEqual(persistentReasons, [.action])
    }

    func testStaleActionCannotExecuteAfterReplacement() {
        var staleHandlerCount = 0
        var staleReasons: [ArthurDismissReason] = []
        Arthur.info(
            "First",
            duration: .untilDismissed,
            action: ArthurAction("Undo") { staleHandlerCount += 1 },
            onDismiss: { staleReasons.append($0) }
        )
        let staleID = Arthur.coordinator.currentToast?.id
        Arthur.success("Second", duration: .untilDismissed)

        if let staleID { Arthur.coordinator.performAction(for: staleID) }
        XCTAssertEqual(staleHandlerCount, 0)
        XCTAssertEqual(staleReasons, [.replaced])
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Second")
    }

    func testActionHandlerCanPresentAnotherToastWithoutOldToastBecomingReplaced() {
        var reasons: [ArthurDismissReason] = []
        Arthur.info(
            "Deleted",
            duration: .untilDismissed,
            action: ArthurAction("Undo") {
                Arthur.success("Restored", duration: .untilDismissed)
            },
            onDismiss: { reasons.append($0) }
        )
        let toastID = Arthur.coordinator.currentToast?.id
        if let toastID { Arthur.coordinator.performAction(for: toastID) }

        XCTAssertEqual(reasons, [.action])
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Restored")
        Arthur.dismiss()
    }

    func testOldTimerCannotDismissToastPresentedByActionHandler() async throws {
        Arthur.info(
            "First",
            duration: .seconds(0.02),
            action: ArthurAction("Next") {
                Arthur.info("Second", duration: .untilDismissed)
            }
        )
        let toastID = try XCTUnwrap(Arthur.coordinator.currentToast?.id)
        Arthur.coordinator.performAction(for: toastID)
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Second")
    }


    func testDurationValuesAndInvalidSeconds() {
        XCTAssertEqual(ArthurDuration.short.timeoutInterval!, 1.5, accuracy: 0.001)
        XCTAssertEqual(ArthurDuration.normal.timeoutInterval!, 2.2, accuracy: 0.001)
        XCTAssertEqual(ArthurDuration.long.timeoutInterval!, 4.0, accuracy: 0.001)
        XCTAssertEqual(ArthurDuration.seconds(3.5).timeoutInterval!, 3.5, accuracy: 0.001)
        XCTAssertEqual(ArthurDuration.seconds(-1).timeoutInterval!, 0)
        XCTAssertEqual(ArthurDuration.seconds(.nan).timeoutInterval!, 0)
        XCTAssertEqual(ArthurDuration.seconds(.infinity).timeoutInterval!, 0)
        XCTAssertNil(ArthurDuration.untilDismissed.timeoutInterval)
    }

    func testPersistentToastDoesNotAutoDismissAndManualReasonIsDeliveredOnce() async throws {
        var reasons: [ArthurDismissReason] = []
        Arthur.info("Persistent", duration: .untilDismissed) { reason in
            reasons.append(reason)
        }
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertNotNil(Arthur.coordinator.currentToast)
        Arthur.dismiss()
        Arthur.dismiss()
        XCTAssertEqual(reasons, [.manual])
    }

    func testTimeoutReasonIsDelivered() async throws {
        var reasons: [ArthurDismissReason] = []
        Arthur.info("Timeout", duration: .seconds(0.03)) { reason in
            reasons.append(reason)
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(reasons, [.timeout])
    }

    func testReplacementReasonIsDeliveredAndStaleTimerCannotAffectNewToast() async throws {
        var reasons: [ArthurDismissReason] = []
        Arthur.info("First", duration: .seconds(0.03)) { reason in
            reasons.append(reason)
        }
        Arthur.success("Second", duration: .seconds(0.15))
        try await Task.sleep(nanoseconds: 70_000_000)
        XCTAssertEqual(reasons, [.replaced])
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Second")
        try await Task.sleep(nanoseconds: 140_000_000)
        XCTAssertEqual(reasons, [.replaced])
    }

    func testSwipeReasonIsDelivered() {
        var reasons: [ArthurDismissReason] = []
        Arthur.info("Swipe", duration: .untilDismissed) { reason in
            reasons.append(reason)
        }
        Arthur.coordinator.dismissFromSwipe()
        XCTAssertEqual(reasons, [.swipe])
    }

    func testPauseAndResumePreserveRemainingDuration() async throws {
        Arthur.info("Pause", duration: .seconds(0.5))
        let toastID = try XCTUnwrap(Arthur.coordinator.currentToast?.id)
        try await Task.sleep(nanoseconds: 100_000_000)
        Arthur.coordinator.pauseAutoDismiss(for: toastID)
        Arthur.coordinator.pauseAutoDismiss(for: toastID)
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertNotNil(Arthur.coordinator.currentToast)
        Arthur.coordinator.resumeAutoDismiss(for: toastID)
        Arthur.coordinator.resumeAutoDismiss(for: toastID)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNotNil(Arthur.coordinator.currentToast)
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertNil(Arthur.coordinator.currentToast)
    }

    func testPauseResumeAreNoOpsForPersistentAndStaleIDs() {
        Arthur.info("Persistent", duration: .untilDismissed)
        let persistentID = Arthur.coordinator.currentToast?.id
        Arthur.coordinator.pauseAutoDismiss(for: UUID())
        if let persistentID { Arthur.coordinator.pauseAutoDismiss(for: persistentID); Arthur.coordinator.resumeAutoDismiss(for: persistentID) }
        XCTAssertNotNil(Arthur.coordinator.currentToast)

        Arthur.success("Replacement", duration: .untilDismissed)
        if let persistentID { Arthur.coordinator.pauseAutoDismiss(for: persistentID); Arthur.coordinator.resumeAutoDismiss(for: persistentID) }
        XCTAssertEqual(Arthur.coordinator.currentToast?.title, "Replacement")
    }
}
