import SwiftUI

/// Applies only the toast card's background surface and its existing decoration.
struct ArthurToastSurfaceModifier: ViewModifier {
    let style: ArthurSurfaceStyle

    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if style == .glass {
            if #available(iOS 26.0, macOS 26.0, *) {
                content
                    .glassEffect(.regular, in: Capsule())
                    .overlay(Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
            } else {
                materialSurface(content)
            }
        } else {
            materialSurface(content)
        }
#else
        materialSurface(content)
#endif
    }

    private func materialSurface(_ content: Content) -> some View {
        content
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}

extension View {
    func arthurToastSurface(_ style: ArthurSurfaceStyle) -> some View {
        modifier(ArthurToastSurfaceModifier(style: style))
    }
}
