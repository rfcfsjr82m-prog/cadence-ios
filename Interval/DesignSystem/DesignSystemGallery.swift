import SwiftUI

// MARK: - Design System Gallery
//
// A living reference of every token and component. Open the canvas (Xcode ▸
// Editor ▸ Canvas) to browse. Swap `previewBackground` for a real asset to see
// the glass over photography; the default uses a gradient so it renders even
// without bundled images.

struct DesignSystemGallery: View {
    @State private var selectedRow = 1
    @State private var sliderValue = 0.6

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xxl) {

                // Typography ────────────────────────────────────────────────
                group("Typography") {
                    Text("Good evening, Christian").font(DS.Font.greeting)
                        .foregroundColor(DS.Palette.textPrimary)
                    Text("A Quiet Hour").font(DS.Font.display)
                        .foregroundColor(DS.Palette.textPrimary)
                    Text("Be still, and let the minute pass without measure.")
                        .font(DS.Font.body).lineSpacing(DS.LineSpacing.reading)
                        .foregroundColor(DS.Palette.textSecondary)
                    DSEyebrow("Daily · 2 Min")
                    DSSectionHeader("Your sessions")
                }

                // Buttons ───────────────────────────────────────────────────
                group("Buttons") {
                    DSGlassCTA("Begin", systemImage: "play.fill") {}
                    HStack(spacing: DS.Space.lg) {
                        DSIconButton(systemImage: "xmark") {}
                        DSIconButton(systemImage: "gearshape") {}
                        DSCircularCTA("Start", systemImage: "flame") {}
                    }
                }

                // Chips ─────────────────────────────────────────────────────
                group("Chips") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Space.md) {
                            DSChip("Tabata", systemImage: "bolt.fill")
                            DSChip("Favorites", systemImage: "heart.fill")
                            DSChip("History", systemImage: "clock")
                        }
                    }
                }

                // Selectable rows ───────────────────────────────────────────
                group("Selectable rows") {
                    VStack(spacing: DS.Space.sm + 2) {
                        ForEach(0..<3) { i in
                            DSSelectableRow(["Silent", "Soft chime", "Spoken"][i],
                                            isSelected: selectedRow == i) { selectedRow = i }
                        }
                    }
                }

                // Cards ─────────────────────────────────────────────────────
                group("Glass card") {
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        DSEyebrow("Routine")
                        Text("Morning Flow").font(DS.Font.subtitle)
                            .foregroundColor(DS.Palette.textPrimary)
                        Text("Five rounds, gentle ramp.")
                            .font(DS.Font.quote).italic()
                            .foregroundColor(DS.Palette.textSecondary)
                    }
                    .padding(DS.Space.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsGlassCard()
                }

                // Accent ────────────────────────────────────────────────────
                group("Accent & controls") {
                    HStack(spacing: DS.Space.lg) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(DS.Palette.accent)
                            .font(.system(size: 22))
                        Slider(value: $sliderValue).tint(DS.Palette.control)
                    }
                }
            }
            .padding(DS.Space.screen)
            .padding(.vertical, DS.Space.xxl)
        }
        .background(previewBackground)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            DSEyebrow(title, tight: true)
            content()
        }
    }

    // Replace with `ContrastBackground(imageName: "your_asset")` to preview over photography.
    private var previewBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.12, green: 0.13, blue: 0.18),
                     Color(red: 0.06, green: 0.07, blue: 0.10)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    DesignSystemGallery()
}
