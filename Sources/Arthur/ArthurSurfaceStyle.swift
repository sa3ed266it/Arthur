/// Controls the visual surface used by Arthur toast cards.
public enum ArthurSurfaceStyle: Sendable, Equatable {
    /// Arthur's original regular material surface.
    case material
    /// Native regular Liquid Glass on supported systems, otherwise regular material.
    case glass
}
