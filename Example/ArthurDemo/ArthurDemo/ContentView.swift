import Arthur
import SwiftUI

private enum DemoTrackError: Error {
    case offline
}

struct ContentView: View {
    @State private var duration = 2.2
    @State private var hapticsEnabled = true
    @State private var position: ArthurPosition = .top
    @State private var swipeToDismiss = true
    @State private var surfaceStyle: ArthurSurfaceStyle = .material
    @State private var lastDismissReason: ArthurDismissReason?
    @State private var lastAction = "None"
    @State private var updateStatus = "Idle"
    @State private var trackStatus = "Idle"
    @State private var trackCancellationTask: Task<Void, Never>?

    private let durations = [1.0, 2.2, 4.0]

    var body: some View {
        NavigationStack {
            Form {
                Section("Toast Styles") {
                    Button("Success") { Arthur.success("Saved", subtitle: "Your changes were saved.") }
                    Button("Error") { Arthur.error("Something went wrong", subtitle: "Please try again.") }
                    Button("Warning") { Arthur.warning("Check your connection", subtitle: "Some data may be outdated.") }
                    Button("Info") { Arthur.info("Updated", subtitle: "New information is available.") }
                    Button("Custom") {
                        Arthur.show(
                            title: "Added to favorites",
                            subtitle: "You can find it in your saved items.",
                            style: .custom(systemImage: "heart.fill", tint: .pink),
                            duration: .seconds(duration),
                            onDismiss: recordDismissal
                        )
                    }
                }

                Section("Lifecycle") {
                    Button("Short") {
                        Arthur.info("Short toast", duration: .short, onDismiss: recordDismissal)
                    }
                    Button("Persistent") {
                        Arthur.info("Persistent toast", subtitle: "Dismiss manually or swipe.", duration: .untilDismissed, onDismiss: recordDismissal)
                    }
                    Button("Dismiss Reason") {
                        Arthur.success("Dismiss me", duration: .seconds(6), onDismiss: recordDismissal)
                    }
                    Button("Pause Timer Test") {
                        Arthur.info("Pause timer", subtitle: "Drag and cancel to resume the remaining time.", duration: .seconds(4.5), onDismiss: recordDismissal)
                    }
                    if let lastDismissReason {
                        Text("Last dismiss reason: \(dismissReasonLabel(lastDismissReason))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Actions") {
                    Button("Show Undo Toast") {
                        Arthur.success(
                            "Item deleted",
                            subtitle: "You can restore it.",
                            duration: .untilDismissed,
                            action: ArthurAction("Undo") {
                                lastAction = "Undo"
                                Arthur.success("Restored")
                            },
                            onDismiss: recordDismissal
                        )
                    }
                    Button("Show Retry Toast") {
                        Arthur.error(
                            "Connection failed",
                            duration: .untilDismissed,
                            action: ArthurAction("Retry") {
                                lastAction = "Retry"
                            },
                            onDismiss: recordDismissal
                        )
                    }
                    Text("Last action: \(lastAction)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Content Updates") {
                    Button("Upload → Success") { uploadSuccess() }
                    Button("Upload → Error + Retry") { uploadError() }
                    Button("Loading → Warning") { loadingToWarning() }
                    Button("Multiple Updates") { multipleUpdates() }
                    Button("Short → Long Content") { shortToLong() }
                    Button("Long → Short Content") { longToShort() }
                    Button("Action Added") { actionAdded() }
                    Button("Action Removed") { actionRemoved() }
                    Button("Loading → Persistent Error") { persistentErrorUpdate() }
                    Button("Stale Handle Test") { staleHandleTest() }
                    Text("Update status: \(updateStatus)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Async Track") {
                    Button("Track Success") { trackSuccess() }
                    Button("Track Failure") { trackFailure() }
                    Button("Track Cancellation") { startTrackCancellation() }
                    Button("Cancel Tracked Work", role: .destructive) { cancelTrackCancellation() }
                    Button("Dismiss While Running") { trackDismissWhileRunning() }
                    Button("Replace While Running") { trackReplaceWhileRunning() }
                    Text("Track status: \(trackStatus)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Configuration") {
                    Picker("Duration", selection: $duration) {
                        ForEach(durations, id: \.self) { value in
                            Text("\(value, specifier: "%.1f") s").tag(value)
                        }
                    }
                    .onChange(of: duration) { _, value in applyConfiguration(duration: value) }

                    Toggle("Haptics", isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { _, value in
                            Arthur.configure { $0.hapticsEnabled = value }
                        }

                    Toggle("Swipe to dismiss", isOn: $swipeToDismiss)
                        .onChange(of: swipeToDismiss) { _, value in
                            Arthur.configure { $0.swipeToDismiss = value }
                        }

                    Picker("Position", selection: $position) {
                        Text("Top").tag(ArthurPosition.top)
                        Text("Bottom").tag(ArthurPosition.bottom)
                    }
                    .onChange(of: position) { _, value in
                        Arthur.configure { $0.position = value }
                    }
                }

                Section("Surface") {
                    Picker("Style", selection: $surfaceStyle) {
                        Text("Material").tag(ArthurSurfaceStyle.material)
                        Text("Glass").tag(ArthurSurfaceStyle.glass)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: surfaceStyle) { _, value in
                        Arthur.configure { $0.surfaceStyle = value }
                    }
                    Text("Liquid Glass requires iOS 26+; older systems use material.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Stress Test") {
                    Button("Rapid Replacement") { rapidReplacement() }
                    Button("Dismiss Current Toast", role: .destructive) { Arthur.dismiss() }
                }

                Section("Swipe Test") {
                    Button("Show Swipe Test Toast") {
                        Arthur.show(
                            title: "Swipe to dismiss",
                            subtitle: "Drag this toast away",
                            duration: .seconds(7),
                            onDismiss: recordDismissal
                        )
                    }
                }

                Section("Accessibility") {
                    Text("Try VoiceOver announcements, Reduce Motion, Dynamic Type, and Light/Dark Mode while exercising the toasts.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Arthur")
        }
        .task {
            applyConfiguration(duration: duration)
        }
    }

    private func applyConfiguration(duration: Double) {
        Arthur.configure {
            $0.defaultDuration = .seconds(duration)
            $0.hapticsEnabled = hapticsEnabled
            $0.position = position
            $0.swipeToDismiss = swipeToDismiss
            $0.surfaceStyle = surfaceStyle
        }
    }

    private func rapidReplacement() {
        Task { @MainActor in
            Arthur.info("Step 1", subtitle: "Replacement test started.", duration: .seconds(0.6), onDismiss: recordDismissal)
            try? await Task.sleep(for: .milliseconds(140))
            Arthur.warning("Step 2", subtitle: "The latest toast should win.", duration: .seconds(0.6), onDismiss: recordDismissal)
            try? await Task.sleep(for: .milliseconds(140))
            Arthur.error("Step 3", subtitle: "Checking stale dismissal protection.", duration: .seconds(0.6), onDismiss: recordDismissal)
            try? await Task.sleep(for: .milliseconds(140))
            Arthur.success("Complete", subtitle: "Latest toast remains visible.", duration: .seconds(duration), onDismiss: recordDismissal)
        }
    }

    private func uploadSuccess() {
        updateStatus = "Uploading"
        let handle = Arthur.loading("Uploading...", subtitle: "Preparing...", onDismiss: recordDismissal)
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            if Arthur.update(handle, to: .success("Uploaded", subtitle: "Ready to view")) {
                updateStatus = "Uploaded"
            }
        }
    }

    private func uploadError() {
        updateStatus = "Connecting"
        let handle = Arthur.loading("Connecting...", onDismiss: recordDismissal)
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            if Arthur.update(handle, to: .error(
                "Connection failed",
                duration: .untilDismissed,
                action: ArthurAction("Retry") {
                    lastAction = "Retry"
                    updateStatus = "Retry tapped"
                }
            )) {
                updateStatus = "Connection failed"
            }
        }
    }

    private func loadingToWarning() {
        updateStatus = "Checking"
        let handle = Arthur.loading("Checking connection...", subtitle: "One moment", onDismiss: recordDismissal)
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            if Arthur.update(handle, to: .warning("Connection is slow", subtitle: "Some data may be outdated.")) {
                updateStatus = "Warning"
            }
        }
    }

    private func multipleUpdates() {
        updateStatus = "Starting"
        let handle = Arthur.loading("Starting...", onDismiss: recordDismissal)
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard Arthur.update(handle, to: .loading("Uploading...")) else { return }
            updateStatus = "Uploading"
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard Arthur.update(handle, to: .info("Processing...")) else { return }
            updateStatus = "Processing"
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            if Arthur.update(handle, to: .success("Done")) {
                updateStatus = "Done"
            }
        }
    }

    private func shortToLong() {
        let handle = Arthur.loading("Saving...", onDismiss: recordDismissal)
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            if Arthur.update(handle, to: .success(
                "Saved successfully",
                subtitle: "Your changes are now synchronized across all of your devices."
            )) {
                updateStatus = "Long content"
            }
        }
    }

    private func longToShort() {
        let handle = Arthur.loading(
            "Saving your changes",
            subtitle: "This may take a moment while we sync everything.",
            onDismiss: recordDismissal
        )
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            if Arthur.update(handle, to: .success("Saved")) {
                updateStatus = "Short content"
            }
        }
    }

    private func actionAdded() {
        let handle = Arthur.loading("Uploading...", onDismiss: recordDismissal)
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            if Arthur.update(handle, to: .success(
                "Uploaded",
                subtitle: "Ready to view",
                action: ArthurAction("Open") { lastAction = "Open" }
            )) {
                updateStatus = "Action added"
            }
        }
    }

    private func actionRemoved() {
        let handle = Arthur.loading("Uploading...", onDismiss: recordDismissal)
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            guard Arthur.update(handle, to: .success(
                "Uploaded",
                subtitle: "Ready to view",
                action: ArthurAction("Open") { lastAction = "Open" }
            )) else { return }
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            if Arthur.update(handle, to: .success("Uploaded", subtitle: "Ready to view")) {
                updateStatus = "Action removed"
            }
        }
    }

    private func persistentErrorUpdate() {
        let handle = Arthur.loading("Working...", onDismiss: recordDismissal)
        Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            if Arthur.update(handle, to: .error("Failed", duration: .untilDismissed)) {
                updateStatus = "Persistent error"
            }
        }
    }

    private func staleHandleTest() {
        let handle = Arthur.loading("Old request...")
        Arthur.info("New notification")
        updateStatus = Arthur.update(handle, to: .success("Should not appear"))
            ? "Unexpected update"
            : "Stale update ignored"
    }

    private func trackSuccess() {
        trackStatus = "Running"
        Task { @MainActor in
            do {
                let value = try await Arthur.track(
                    loading: "Signing in...",
                    success: "Welcome back",
                    error: "Sign in failed"
                ) {
                    try await Task.sleep(for: .milliseconds(700))
                    return "profile-42"
                }
                trackStatus = "Returned: \(value)"
            } catch {
                trackStatus = "Unexpected error: \(error)"
            }
        }
    }

    private func trackFailure() {
        trackStatus = "Running"
        Task { @MainActor in
            do {
                _ = try await Arthur.track(
                    loading: .loading("Saving...", subtitle: "Please wait"),
                    success: .success("Saved", duration: .long, action: ArthurAction("Open") {
                        trackStatus = "Open tapped"
                    }),
                    error: .error("Save failed", duration: .untilDismissed, action: ArthurAction("Retry") {
                        trackStatus = "Retry tapped"
                    })
                ) {
                    try await Task.sleep(for: .milliseconds(700))
                    throw DemoTrackError.offline
                }
            } catch DemoTrackError.offline {
                trackStatus = "Caught error: offline"
            } catch {
                trackStatus = "Caught error: \(error)"
            }
        }
    }

    private func startTrackCancellation() {
        trackCancellationTask?.cancel()
        trackStatus = "Running"
        trackCancellationTask = Task { @MainActor in
            do {
                _ = try await Arthur.track(loading: "Working...", success: "Finished", error: "Failed") {
                    try await Task.sleep(for: .seconds(3))
                    return true
                }
                trackStatus = "Unexpected success"
            } catch is CancellationError {
                trackStatus = "Cancellation reached caller"
            } catch {
                trackStatus = "Caught error: \(error)"
            }
        }
    }

    private func cancelTrackCancellation() {
        trackCancellationTask?.cancel()
        trackCancellationTask = nil
    }

    private func trackDismissWhileRunning() {
        trackStatus = "Running"
        Task { @MainActor in
            do {
                let value = try await Arthur.track(loading: "Working...", success: "Finished", error: "Failed") {
                    try await Task.sleep(for: .seconds(2))
                    return "completed"
                }
                trackStatus = "Completed without result toast: \(value)"
            } catch {
                trackStatus = "Caught error: \(error)"
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            Arthur.dismiss()
        }
    }

    private func trackReplaceWhileRunning() {
        trackStatus = "Running"
        Task { @MainActor in
            do {
                _ = try await Arthur.track(loading: "Working...", success: "Finished", error: "Failed") {
                    try await Task.sleep(for: .seconds(2))
                    return true
                }
                trackStatus = "Completed; replacement remained current"
            } catch {
                trackStatus = "Caught error: \(error)"
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            Arthur.info("Another notification", duration: .untilDismissed)
        }
    }

    private func recordDismissal(_ reason: ArthurDismissReason) {
        lastDismissReason = reason
    }

    private func dismissReasonLabel(_ reason: ArthurDismissReason) -> String {
        switch reason {
        case .timeout: return "timeout"
        case .swipe: return "swipe"
        case .manual: return "manual"
        case .replaced: return "replaced"
        case .action: return "action"
        }
    }
}
