# Arthur API Reference

## Installation and root setup

For a reproducible release dependency, use the public GitHub package and pin
the exact `1.5.0` release in Xcode or `Package.swift`:

```text
https://github.com/sa3ed266it/Arthur
```

```swift
.package(
    url: "https://github.com/sa3ed266it/Arthur.git",
    exact: "1.5.0"
)
```

For local development, use Xcode's **File → Add Package Dependencies… → Add
Local…** workflow. Then import the package:

```swift
import Arthur
```

Install the host once at the app root:

```swift
ContentView()
    .arthur()
```

`arthur()` installs the overlay that observes Arthur's main-actor coordinator. It should normally be applied once to the app's root content.

## Configuration

Update global settings with `Arthur.configure`:

```swift
Arthur.configure {
    $0.defaultDuration = .normal
    $0.hapticsEnabled = true
    $0.position = .top
    $0.swipeToDismiss = true
    $0.surfaceStyle = .material
}
```

See [Configuration.md](Configuration.md) for every configuration property and its default.

## Presentation

All presentation methods are main-actor isolated. Each optional `duration` overrides `defaultDuration`. Each optional `onDismiss` callback receives one `ArthurDismissReason` when that toast is finalized.

```swift
Arthur.success(
    "Saved",
    subtitle: "Your changes were saved.",
    duration: .normal,
    action: .init("Undo") {
        restoreItem()
    },
    onDismiss: { reason in print(reason) }
)

Arthur.error("Something went wrong")
Arthur.warning("Check your connection")
Arthur.info("Updated")
```

Semantic presentation methods also accept optional `systemImage` and `tint`
overrides. These change only the rendered visual metadata; haptics continue to
derive from `ArthurStyle`:

```swift
Arthur.success(
    "Entrata aggiunta",
    subtitle: "150,00 € • Fondo attività",
    systemImage: "arrow.down.circle.fill",
    tint: .green,
    duration: .long
)
```

`Arthur.show` supports the complete parameter set:

```swift
Arthur.show(
    title: "Added to favorites",
    subtitle: "You can find it in your saved items.",
    style: .custom(systemImage: "heart.fill", tint: .pink),
    duration: .seconds(3),
    accessibilityAnnouncement: "Added to favorites",
    onDismiss: { reason in print(reason) }
)
```

`Arthur.dismiss()` manually dismisses the current toast and reports `.manual` to its callback.

## Loading and in-place updates

`ArthurToastHandle` is a lightweight, copyable identity for one toast lifecycle. It does not retain Arthur, a view, or a closure. A handle becomes stale after timeout, swipe, manual dismissal, replacement, or action dismissal.

Create a loading toast with a default persistent duration:

```swift
let toast = Arthur.loading("Uploading...")
```

Loading supports subtitle, finite or `.untilDismissed` duration, action, and the original `onDismiss` callback:

```swift
let toast = Arthur.loading(
    "Connecting...",
    action: .init("Cancel") {
        cancelConnection()
    },
    onDismiss: { reason in print(reason) }
)
```

Update the same toast in place:

```swift
Arthur.update(toast, to: .success("Uploaded"))
```

`Arthur.update` returns `true` when the handle is current and the update commits, or `false` for a stale/dismissed handle. Updates preserve the toast UUID, do not emit `.replaced`, do not call `onDismiss`, and do not replay the entrance or exit presentation animation. Visible content changes transition subtly in place while the same surface and lifecycle remain mounted. The updated duration starts when the update commits; non-loading updates default to the configured duration and loading updates default to `.untilDismissed`.

Updates can be repeated and can change style, title, subtitle, duration, and action:

```swift
Arthur.update(
    toast,
    to: .error(
        "Connection failed",
        duration: .untilDismissed,
        action: .init("Retry") {
            retry()
        }
    )
)
```

`ArthurUpdate.success`, `.error`, `.warning`, and `.info` accept the same
optional `systemImage` and `tint` overrides. Updates keep the same toast ID and
semantic style while replacing only the visual metadata.

An update with no action removes the previous action. The original lifecycle callback survives all updates and is delivered once only when the final toast is dismissed. An updated action still dismisses with `.action`, executes before `onDismiss(.action)`, and may present another toast safely. Loading uses the native SwiftUI `ProgressView`; determinate progress values are not part of this API.

## Async tracking

Use `Arthur.track` to orchestrate a loading toast around an async throwing operation:

```swift
let user = try await Arthur.track(
    loading: "Signing in...",
    success: "Welcome back",
    error: "Sign in failed"
) {
    try await auth.signIn()
}
```

The generic return value is the operation's value unchanged. Non-cancellation errors are rethrown unchanged after Arthur attempts the error update, so callers can catch their original error type. The operation closure is not MainActor-isolated; only Arthur's UI mutations are main-actor isolated.

For subtitles, durations, and actions, use the existing `ArthurUpdate` value:

```swift
let value = try await Arthur.track(
    loading: .loading("Uploading...", subtitle: "Please wait"),
    success: .success(
        "Uploaded",
        duration: .long,
        action: .init("Open") { openFile() }
    ),
    error: .error(
        "Upload failed",
        duration: .untilDismissed,
        action: .init("Retry") { retry() }
    )
) {
    try await upload()
}
```

The rich `loading` value must be created with `.loading(...)`. Track always uses `Arthur.loading` followed by `Arthur.update`, so success and error remain same-identity in-place updates with no replacement or new presentation lifecycle. If the handle is stale because the toast timed out, was dismissed, swiped, replaced, or action-dismissed, the final update returns `false` internally and no result toast is created or announced.

If the tracked task is cancelled, Arthur removes the loading toast only when that handle is still current, does not show success or error, and rethrows cancellation. Cancellation cleanup has no public dismissal reason in this version, so the original `onDismiss` callback is not invoked for that cleanup. Dismissing, swiping, or replacing the loading toast does not cancel the operation; the operation continues and its later final update is ignored. Rich action buttons retain the normal bordered capsule styling and `.action` dismissal behavior.

## Styles

The built-in styles are `.success`, `.error`, `.warning`, and `.info`. They provide the corresponding semantic icon and tint. Use `.custom(systemImage:tint:)` to supply an SF Symbol name and a SwiftUI `Color`:

```swift
Arthur.show(
    title: "Loved",
    style: .custom(systemImage: "heart.fill", tint: .pink)
)
```

## Durations

- `.short`: 1.5 seconds
- `.normal`: 2.2 seconds and the default
- `.long`: 4 seconds
- `.seconds(TimeInterval)`: custom finite duration
- `.untilDismissed`: no timer; remains until manually dismissed or replaced

Invalid `.seconds(...)` values are normalized safely: negative and zero values become an immediate zero-second timeout, while NaN and infinity also become zero seconds.

## Persistent toasts

Use `duration: .untilDismissed` for a toast with no auto-dismiss task:

```swift
Arthur.info("Uploading", duration: .untilDismissed)
```

It can still be dismissed manually, by swipe, or by replacement.

## Dismiss reasons

`ArthurDismissReason` contains exactly these cases:

- `.timeout`: finite duration elapsed
- `.swipe`: swipe-to-dismiss completed
- `.manual`: `Arthur.dismiss()` was called
- `.replaced`: a newer toast became current
- `.action`: the toast's action button was triggered

Callbacks are delivered on the main actor and exactly once for each toast ID.

## Actions

`ArthurAction` represents one synchronous main-actor action button:

```swift
Arthur.error(
    "Connection failed",
    duration: .untilDismissed,
    action: .init("Retry") {
        retry()
    }
)
```

Actions are supported by `success`, `error`, `warning`, `info`, and `show`. Only one action is supported per toast. In this version, triggering the action always dismisses the toast. The action handler runs first; then `onDismiss(.action)` is delivered. This ordering allows the handler to present another Arthur toast safely while the old toast remains resolved as `.action`.

Action handlers are stored internally by toast identity rather than in the toast's executable value data. A stale action for a replaced or dismissed toast is ignored, and action, timer, manual, swipe, and replacement paths share the same exactly-once identity protection.

When an action exists, its native SwiftUI `Button` is exposed separately to accessibility services while the toast title and subtitle remain understandable. Without an action, Arthur preserves its existing combined accessibility element behavior.

## Swipe-to-dismiss

Swipe direction follows the configured position:

- `.top` toast → swipe upward
- `.bottom` toast → swipe downward

Swipe-to-dismiss is enabled by default. Disable it with `$0.swipeToDismiss = false`. During an active drag, finite auto-dismiss pauses. A cancelled drag resumes using the remaining duration; a completed swipe reports `.swipe`.

## Position

Configure `.top` or `.bottom`:

```swift
Arthur.configure {
    $0.position = .bottom
}
```

## Surface style

`ArthurSurfaceStyle.material` is the default and preserves Arthur's regular material capsule. `.glass` is opt-in:

```swift
Arthur.configure {
    $0.surfaceStyle = .glass
}
```

On supported systems, `.glass` uses native regular Liquid Glass. On unsupported systems or toolchains it falls back to `.regularMaterial`. Consumers do not need their own availability checks.

## Haptics and accessibility

`hapticsEnabled` defaults to `true` and controls semantic notification haptics on supported devices. Arthur combines title and subtitle for VoiceOver announcements, hides decorative icons, supports multiline Dynamic Type, and respects Reduce Motion for presentation and floating behavior.

## Public value types

`ArthurToast` is the public value type containing `id`, `title`, optional `subtitle`, `style`, `duration`, and `accessibilityAnnouncement`. It can be initialized directly when a value is useful to an integrating app, although presentation normally goes through `Arthur`.
