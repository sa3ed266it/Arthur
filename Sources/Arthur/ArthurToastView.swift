import SwiftUI

struct ArthurToastView: View {
    let toast: ArthurToast?
    let position: ArthurPosition
    let swipeToDismiss: Bool
    let surfaceStyle: ArthurSurfaceStyle
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedToast: ArthurToast?
    @State private var outgoingContent: ArthurToast?
    @State private var presentationPhase: PresentationPhase = .hidden
    @State private var isFloating = false
    @State private var dragOffset: CGFloat = 0
    @State private var hasPausedTimerForDrag = false
    @State private var incomingContentVisible = true
    @State private var outgoingContentVisible = false
    @State private var contentTransitionGeneration = 0

    private enum PresentationPhase {
        case hidden
        case visible
        case disappearing
    }

    private var exitDuration: UInt64 {
        reduceMotion ? 180_000_000 : 310_000_000
    }

    private var contentTransitionDuration: UInt64 {
        reduceMotion ? 160_000_000 : 210_000_000
    }

    private var cardScale: CGFloat {
        guard !reduceMotion else { return 1 }
        return presentationPhase == .visible ? 1 : 0.82
    }

    private var cardOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        let hiddenOffset: CGFloat = position == .top ? -30 : 30
        return presentationPhase == .visible ? 0 : hiddenOffset
    }

    private var cardOpacity: Double {
        presentationPhase == .visible ? 1 : 0
    }

    private var cardBlur: CGFloat {
        guard !reduceMotion else { return 0 }
        return presentationPhase == .visible ? 0 : 4
    }

    private var dragScale: CGFloat {
        guard outwardDragDistance > 0 else { return 1 }
        return 1 - min(outwardDragDistance / 100 * 0.03, 0.03)
    }

    private var dragOpacity: Double {
        guard outwardDragDistance > 0 else { return 1 }
        return max(0.72, 1 - min(Double(outwardDragDistance) / 120, 0.28))
    }

    private var outwardDragDistance: CGFloat {
        let signedDistance = position == .top ? -dragOffset : dragOffset
        return max(0, signedDistance)
    }

    var body: some View {
        ZStack {
            if let displayedToast {
                toastCard(displayedToast)
                    .scaleEffect(cardScale * dragScale)
                    .offset(y: cardOffset + dragOffset)
                    .offset(y: isFloating && presentationPhase == .visible ? 1.5 : 0)
                    .opacity(cardOpacity * dragOpacity)
                    .blur(radius: cardBlur)
            }
        }
        .task(id: toast?.id) {
            await reconcilePresentation(with: toast)
        }
        .onChange(of: toast) { _, updatedToast in
            guard let updatedToast, displayedToast?.id == updatedToast.id else { return }
            guard presentationPhase == .visible else {
                displayedToast = updatedToast
                return
            }
            startContentUpdate(to: updatedToast)
        }
    }

    private func toastCard(_ toast: ArthurToast) -> some View {
        toastContent(toast)
            .opacity(incomingContentVisible ? 1 : 0)
            .offset(y: incomingContentVisible || reduceMotion ? 0 : 5)
            .blur(radius: incomingContentVisible || reduceMotion ? 0 : 1.8)
            .overlay {
                if let outgoingContent {
                    toastContent(outgoingContent)
                        .opacity(outgoingContentVisible ? 1 : 0)
                        .offset(y: reduceMotion || outgoingContentVisible ? 0 : -5)
                        .blur(radius: outgoingContentVisible ? 0 : (reduceMotion ? 0 : 1.8))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .arthurToastSurface(surfaceStyle)
            .animation(
                reduceMotion ? .easeInOut(duration: 0.16) : .easeInOut(duration: 0.21),
                value: contentTransitionGeneration
            )
    }

    @ViewBuilder
    private func toastContent(_ toast: ArthurToast) -> some View {
        HStack(spacing: 10) {
            if toast.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: toast.systemImageOverride ?? toast.style.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(toast.tintOverride ?? toast.style.tint)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(3)
                if let subtitle = toast.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
            .multilineTextAlignment(.leading)
            .layoutPriority(1)

            if let actionTitle = toast.actionTitle {
                Spacer(minLength: 4)
                Button(actionTitle) {
                    Arthur.performAction(for: toast.id)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .buttonBorderShape(.capsule)
                .accessibilityLabel(actionTitle)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .frame(minHeight: 56)
        .frame(maxWidth: 390, alignment: .leading)
        .modifier(ArthurToastAccessibilityModifier(
            hasAction: toast.actionTitle != nil,
            announcement: toast.accessibilityAnnouncement
        ))
        .gesture(swipeGesture, including: swipeToDismiss ? .all : .none)
        .allowsHitTesting(swipeToDismiss || toast.actionTitle != nil)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard presentationPhase == .visible else { return }
                if !hasPausedTimerForDrag, let displayedToast {
                    hasPausedTimerForDrag = true
                    Arthur.pauseAutoDismiss(for: displayedToast.id)
                }
                dragOffset = effectiveDragOffset(value.translation.height)
            }
            .onEnded { value in
                guard presentationPhase == .visible else {
                    dragOffset = 0
                    hasPausedTimerForDrag = false
                    return
                }

                guard let displayedToast, Arthur.coordinator.currentToast?.id == displayedToast.id else {
                    dragOffset = 0
                    hasPausedTimerForDrag = false
                    return
                }

                let currentOffset = effectiveDragOffset(value.translation.height)
                let projectedOffset = effectiveDragOffset(value.predictedEndTranslation.height)
                let currentOutwardDistance = outwardDistance(for: currentOffset)
                let projectedOutwardDistance = outwardDistance(for: projectedOffset)
                let shouldDismiss = max(currentOutwardDistance, projectedOutwardDistance) >= 50

                if shouldDismiss {
                    // Keep the interactive position in place while the coordinator
                    // hands off to the existing disappearing lifecycle.
                    dragOffset = currentOffset
                    hasPausedTimerForDrag = false
                    dismiss()
                } else {
                    withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                    Arthur.resumeAutoDismiss(for: displayedToast.id)
                    hasPausedTimerForDrag = false
                }
            }
    }

    private func effectiveDragOffset(_ translation: CGFloat) -> CGFloat {
        isOutward(translation) ? translation : translation * 0.18
    }

    private func outwardDistance(for offset: CGFloat) -> CGFloat {
        max(0, position == .top ? -offset : offset)
    }

    private func isOutward(_ translation: CGFloat) -> Bool {
        position == .top ? translation < 0 : translation > 0
    }

    @MainActor
    private func reconcilePresentation(with incomingToast: ArthurToast?) async {
        guard !Task.isCancelled else { return }

        if let incomingToast {
            if displayedToast?.id == incomingToast.id, presentationPhase == .visible {
                return
            }

            if displayedToast != nil {
                invalidateContentTransition()
                isFloating = false
                withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : .easeInOut(duration: 0.31)) {
                    presentationPhase = .disappearing
                }
                await waitForExit()
                guard !Task.isCancelled else { return }
            }

            guard Arthur.coordinator.currentToast?.id == incomingToast.id else { return }
            displayedToast = incomingToast
            incomingContentVisible = true
            outgoingContentVisible = false
            outgoingContent = nil
            presentationPhase = .hidden
            isFloating = false
            dragOffset = 0
            hasPausedTimerForDrag = false

            // Commit the hidden frame before starting the entrance animation.
            await Task.yield()
            guard !Task.isCancelled else { return }
            guard Arthur.coordinator.currentToast?.id == incomingToast.id else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.42, dampingFraction: 0.82)) {
                presentationPhase = .visible
            }

            guard !reduceMotion else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            guard Arthur.coordinator.currentToast?.id == incomingToast.id else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        } else if displayedToast != nil {
            let exitingID = displayedToast?.id
            invalidateContentTransition()
            isFloating = false
            withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : .easeInOut(duration: 0.31)) {
                presentationPhase = .disappearing
            }
            await waitForExit()
            guard !Task.isCancelled else { return }
            guard Arthur.coordinator.currentToast == nil else { return }
            guard displayedToast?.id == exitingID else { return }
            displayedToast = nil
            presentationPhase = .hidden
            dragOffset = 0
            hasPausedTimerForDrag = false
        }
    }

    private func waitForExit() async {
        do {
            try await Task.sleep(nanoseconds: exitDuration)
        } catch {
            return
        }
    }

    private func startContentUpdate(to updatedToast: ArthurToast) {
        guard let previousToast = displayedToast,
              previousToast.id == updatedToast.id,
              contentSignature(previousToast) != contentSignature(updatedToast)
        else {
            displayedToast = updatedToast
            return
        }

        contentTransitionGeneration &+= 1
        let generation = contentTransitionGeneration
        outgoingContent = previousToast
        outgoingContentVisible = true
        incomingContentVisible = false
        displayedToast = updatedToast

        Task { @MainActor in
            await Task.yield()
            guard contentTransitionGeneration == generation,
                  presentationPhase == .visible,
                  displayedToast?.id == updatedToast.id
            else { return }

            withAnimation(reduceMotion ? .easeInOut(duration: 0.14) : .easeOut(duration: 0.10)) {
                outgoingContentVisible = false
            }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.16) : .easeIn(duration: 0.16)) {
                incomingContentVisible = true
            }

            do {
                try await Task.sleep(nanoseconds: contentTransitionDuration)
            } catch {
                return
            }

            guard contentTransitionGeneration == generation,
                  presentationPhase == .visible,
                  displayedToast?.id == updatedToast.id
            else { return }
            outgoingContent = nil
        }
    }

    private func invalidateContentTransition() {
        contentTransitionGeneration &+= 1
        outgoingContent = nil
        outgoingContentVisible = false
        incomingContentVisible = true
    }

    private func contentSignature(_ toast: ArthurToast) -> ContentSignature {
        ContentSignature(
            isLoading: toast.isLoading,
            title: toast.title,
            subtitle: toast.subtitle,
            style: toast.style,
            actionTitle: toast.actionTitle
        )
    }
}

private struct ContentSignature: Equatable {
    let isLoading: Bool
    let title: String
    let subtitle: String?
    let style: ArthurStyle
    let actionTitle: String?
}

private struct ArthurToastAccessibilityModifier: ViewModifier {
    let hasAction: Bool
    let announcement: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if hasAction {
            content.accessibilityElement(children: .contain)
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(announcement)
        }
    }
}
