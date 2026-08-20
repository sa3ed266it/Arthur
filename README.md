# Arthur

Arthur is a small Apple-native SwiftUI toast library for iOS 17 and later.

## Features

- Success, error, warning, info, and custom SF Symbol styles
- Safe-area material or optional native Liquid Glass surfaces
- Animated presentation, replacement, floating motion, and swipe-to-dismiss
- Typed finite and persistent durations with dismissal reasons
- Pause/resume of finite auto-dismiss during an active drag
- VoiceOver, Dynamic Type, Reduce Motion, and semantic haptics support
- No third-party dependencies

## Requirements

- iOS 17+
- Swift Package Manager
- Xcode 15+

## Installation

Add the local package in Xcode with **File → Add Package Dependencies… → Add Local…**, then import it:

```swift
import Arthur
```

## Quick start

Install the host once at the app root:

```swift
ContentView()
    .arthur()
```

Present a toast from main-actor UI code:

```swift
Arthur.success("Saved")
Arthur.error("Something went wrong", subtitle: "Please try again.")
Arthur.warning("Check your connection")
Arthur.info("Updated")
```

To add one action button:

```swift
Arthur.success(
    "Item deleted",
    action: .init("Undo") {
        restoreItem()
    }
)
```

See the complete reference in [Documentation/API.md](Documentation/API.md).

## Surface style

Arthur uses `.material` by default. Liquid Glass is opt-in:

```swift
Arthur.configure {
    $0.surfaceStyle = .glass
}
```

Supported systems use native Liquid Glass. Older systems automatically fall back to `.regularMaterial`; consuming apps do not need availability checks.

## Durations

Use `.short` (1.5 seconds), `.normal` (2.2 seconds), `.long` (4 seconds), `.seconds(_:)`, or `.untilDismissed`:

```swift
Arthur.info("Syncing", duration: .untilDismissed)
```

Invalid custom values—negative, zero, NaN, or infinity—are normalized to a safe immediate dismissal.

## Swipe to dismiss

Swipe top toasts upward and bottom toasts downward. Swipe-to-dismiss is enabled by default and can be disabled:

```swift
Arthur.configure {
    $0.swipeToDismiss = false
}
```

Finite auto-dismiss pauses during an active drag and resumes with the remaining duration when the drag is cancelled.

## Dismiss reasons

Dismissal callbacks receive `.timeout`, `.swipe`, `.manual`, `.replaced`, or `.action` exactly once per toast. An action always dismisses its toast in this version:

```swift
Arthur.success("Saved", onDismiss: { reason in
    print(reason)
})
```

## Loading and in-place updates

Loading returns a handle that can update the same mounted toast without replacement. Visible content changes use a subtle in-place transition while the surface, identity, and lifecycle remain unchanged:

```swift
let toast = Arthur.loading("Uploading...")

Arthur.update(toast, to: .success("Uploaded"))
```

Loading defaults to `.untilDismissed`. Updates keep the same lifecycle and original dismissal callback; stale or dismissed handles return `false` and do nothing.

## Async tracking

`Arthur.track` wraps an async throwing operation with the existing loading and in-place update APIs:

```swift
let user = try await Arthur.track(
    loading: "Signing in...",
    success: "Welcome back",
    error: "Sign in failed"
) {
    try await auth.signIn()
}
```

The operation's value is returned unchanged and its original error is rethrown. Rich loading, success, and error states use `ArthurUpdate`, including subtitles, durations, and actions:

```swift
let value = try await Arthur.track(
    loading: .loading("Uploading...", subtitle: "Please wait"),
    success: .success("Uploaded", duration: .long),
    error: .error("Upload failed", duration: .untilDismissed)
) {
    try await upload()
}
```

Cancellation removes the tracked toast only if it is still current, shows no final toast, and rethrows cancellation. Dismissing, swiping, or replacing the loading toast does not cancel the operation; its later success or error update is ignored and no result toast is resurrected.

## Configuration

```swift
Arthur.configure {
    $0.defaultDuration = .normal
    $0.hapticsEnabled = true
    $0.position = .top // or .bottom
    $0.swipeToDismiss = true
    $0.surfaceStyle = .material // or .glass
}
```

See [Documentation/Configuration.md](Documentation/Configuration.md) for the complete configuration reference.

## Demo App

The standalone `ArthurDemo` app lives at `Example/ArthurDemo`. Open it with:

```sh
open Example/ArthurDemo/ArthurDemo.xcodeproj
```

It demonstrates styles, durations, lifecycle behavior, surfaces, positioning, swipe-to-dismiss, and accessibility.

## Accessibility

Arthur posts combined VoiceOver announcements, hides decorative icons, supports multiline Dynamic Type, and respects Reduce Motion.

## Development and testing

```sh
cd /path/to/Arthur
swift package resolve
swift build
swift test
```

Any new public API or behavior should be completed together with its source documentation, relevant README or API-reference updates, and tests.

## License

Arthur is released under the MIT License. See [LICENSE](LICENSE).
