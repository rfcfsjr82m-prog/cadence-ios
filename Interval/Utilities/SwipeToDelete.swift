import SwiftUI

// MARK: - SwipeToDelete
//
// Drag-gesture swipe-to-delete wrapper — works inside LazyVStack / VStack /
// ScrollView anywhere List's .swipeActions isn't available.
//
// Behaviour:
//   • Drag left ≥ 45 % of button width → springs open
//   • Drag left ≥ deleteThreshold      → full swipe, fires onDelete automatically
//   • Tap revealed button / drag right → collapses
//
// Uses simultaneousGesture (not .gesture) so vertical pans pass through to the
// parent ScrollView.  A horizontal-bias guard (|dx| > |dy|) ensures only
// intentional left-swipes are handled.

struct SwipeToDelete<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    private let buttonWidth: CGFloat    = 80
    private let deleteThreshold: CGFloat = 240

    @State private var offset: CGFloat = 0
    @State private var revealed = false

    var body: some View {
        ZStack(alignment: .trailing) {

            // ── Delete button (behind content) ────────────────────────────────
            Button { triggerDelete() } label: {
                VStack(spacing: 5) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .regular))
                    Text("Delete")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(width: buttonWidth)
                .frame(maxHeight: .infinity)
                .background(Color(red: 1, green: 0.23, blue: 0.19))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            // Reveal button by growing its visible width as the content slides left.
            // Guard ≥ 1 to avoid an "invalid frame dimension = 0" SwiftUI warning.
            .frame(width: max(1, -offset))
            .clipped()
            .opacity(offset < -2 ? 1 : 0)

            // ── Content row ───────────────────────────────────────────────────
            content()
                .offset(x: offset)
                // simultaneousGesture lets the parent ScrollView handle vertical
                // pans while we intercept clearly horizontal (left-swipe) ones.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            // Pass through to ScrollView when gesture is more
                            // vertical than horizontal and the row is closed.
                            guard abs(dx) > abs(dy) || revealed else { return }

                            if dx > 0 {
                                offset   = 0
                                revealed = false
                            } else {
                                let base   = revealed ? -buttonWidth : CGFloat(0)
                                let rubber = base + dx
                                if rubber < -buttonWidth {
                                    offset = -buttonWidth - (-(rubber + buttonWidth)) * 0.3
                                } else {
                                    offset = rubber
                                }
                                offset = max(-deleteThreshold, offset)
                            }
                        }
                        .onEnded { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            // Vertical gesture while closed — don't partially reveal.
                            guard abs(dx) > abs(dy) || revealed else {
                                if offset != 0 { snapBack() }
                                return
                            }
                            if offset <= -deleteThreshold {
                                triggerDelete()
                            } else if offset < -buttonWidth * 0.45 {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    offset = -buttonWidth
                                }
                                revealed = true
                            } else {
                                snapBack()
                            }
                        }
                )
        }
        .onTapGesture { if revealed { snapBack() } }
    }

    private func snapBack() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { offset = 0 }
        revealed = false
    }

    private func triggerDelete() {
        withAnimation(.easeIn(duration: 0.2)) {
            offset = -(UIScreen.main.bounds.width + buttonWidth)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onDelete() }
    }
}
