# ArthurConfiguration

`ArthurConfiguration` is the complete global configuration surface used by `Arthur.configure`. Its initializer uses the defaults below.

| Property | Type | Default | Behavior |
| --- | --- | --- | --- |
| `defaultDuration` | `ArthurDuration` | `.normal` | Duration used when a presentation does not provide an override. |
| `hapticsEnabled` | `Bool` | `true` | Enables semantic notification haptics on supported devices. |
| `position` | `ArthurPosition` | `.top` | Places the overlay near the top or bottom safe area. |
| `swipeToDismiss` | `Bool` | `true` | Enables the position-aware vertical swipe gesture. |
| `surfaceStyle` | `ArthurSurfaceStyle` | `.material` | Selects the original material or opt-in native Liquid Glass surface. |

Example:

```swift
Arthur.configure {
    $0.defaultDuration = .long
    $0.hapticsEnabled = false
    $0.position = .bottom
    $0.swipeToDismiss = true
    $0.surfaceStyle = .glass
}
```

Changing configuration updates the host's current rendering settings without changing Arthur's public presentation methods.

Dismissal callbacks may now also receive `ArthurDismissReason.action` when a toast action button is triggered. This does not add a configuration property.
