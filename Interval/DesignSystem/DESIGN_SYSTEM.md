# Cadence Design System

A calm, editorial, **glass-on-photography** design language, distilled from the
prayer app (*Geistliche Anker*). White type floats over a full-bleed photograph
that is automatically dimmed for legibility. Hierarchy comes from **white
opacity tiers**, not color. Two type families do all the work: a **serif** for
contemplative content and a **sans** for interface chrome.

All tokens live under the `DS` namespace in [`DesignTokens.swift`](DesignTokens.swift).
Components live in [`Components.swift`](Components.swift). A live, browsable
reference is in [`DesignSystemGallery.swift`](DesignSystemGallery.swift) — open
the Xcode canvas to see everything rendered.

---

## Principles

1. **Dark by intent.** Every screen is `.preferredColorScheme(.dark)` over
   `ContrastBackground`. There is no light mode.
2. **Photography is the color.** Surfaces and text are white at varying opacity;
   the backdrop supplies all warmth. The lone chromatic accent is a rose used
   for affection/favorites.
3. **Glass, not panels.** Containers are translucent white washes over material
   with a glossy hairline rim — never opaque cards.
4. **Springs, not durations.** Motion is physical: surfaces settle, presses
   bounce, morphs feel elastic.
5. **Touch feels.** Fire `Haptics` on every meaningful interaction.
6. **Legibility is automatic.** `ContrastBackground` measures each image's
   luminance and adds only as much scrim as the contrast target requires.

---

## Foundations

### Color — one white scale + one accent
Use `DS.Palette` tokens, not raw `Color.white.opacity()`.

| Token | Value | Use |
|---|---|---|
| `textPrimary` | white 1.0 | Titles, active values |
| `textSecondary` | white 0.85 | Body copy, descriptions |
| `textTertiary` | white 0.5 | Eyebrows, metadata, captions |
| `textDisabled` | white 0.4 | Placeholders, inactive |
| `hairlineStrong` | white 0.3 | CTA borders, focused field |
| `hairlineMedium` | white 0.18 | Card borders |
| `hairlineSoft` | white 0.08 | Dividers |
| `fillFaint` | white 0.05 | Inset trays |
| `fillSubtle` | white 0.08 | Chips, rows, icon buttons |
| `fillRegular` | white 0.12 | Primary CTA fill |
| `fillEmphasis` | white 0.15 | Active tab segment |
| `fillSelected` | white 0.2 | Selected row |
| `accent` | `rgb(0.93, 0.36, 0.42)` | Favorites / love only |
| `control` | white | Sliders, checkmarks, progress |

### Typography — `DS.Font`
**Serif (editorial):** `greeting` (22), `display` (28), `body` (17, +`lineSpacing(6)`),
`reading` (20), `quote` (15, often italic), `titleSerif` (17).
**Sans (interface):** `eyebrow` (11, +`tracking 1.5`), `eyebrowSm` (10, +`tracking 2`),
`section` (14), `label` (14), `titleLight` (22), `subtitle` (15 semibold),
`navTitle` (17 semibold), `button` (15, +`tracking 0.5`), `row` (15), `tab` (10),
`micro` (10).

Caps labels need air — always pair with `DS.Tracking`. Reading blocks pair with
`DS.LineSpacing.reading`.

### Spacing — `DS.Space` (4-pt scale)
`xxs 4 · xs 6 · sm 8 · md 12 · lg 16 · xl 24 · xxl 40`.
`screen` (24) is the canonical left/right gutter. `md` is the default gap
between cards/rows; `lg` is inner card padding; `xxl` is section rhythm.

### Radius — `DS.Radius`
`sheet 28 · card 18 · row 14 · control 12 · segment 10`.
Pills use `Capsule()`; icon buttons use `Circle()`.

### Sizing — `DS.Size`
`hitTarget 44 · iconButton 32 · tabIcon 24 · chipIcon 14 · ctaHeight 56 ·
rowHeight 50 · circularCTA 70 · hairline 1`.

### Motion — `DS.Motion`
| Token | Spring | Use |
|---|---|---|
| `hero` | response 0.45, damping 0.92 | Sheet open/close, primary transitions |
| `morph` | response 0.5, damping 0.78 | Icon→bar / search morph |
| `press` | bouncy 0.3 | Press feedback, favorite toggle |
| `quick` | 0.2 | Tab/segment selection |
| `settle` | 0.3 | Slider reveal, tab content |

### Gradients — `DS.Gradient`
`glassEdge` / `glassEdgeSoft` (glossy rim, bright at top-leading), `readingFade`
(top+bottom mask for scroll regions), `bottomFade` (one-sided).

---

## Components

| Component | Role |
|---|---|
| `ContrastBackground(imageName:)` | Auto-dimmed full-bleed photo backdrop |
| `SpringPressStyle(scale:)` | Bouncy press for any `Button` |
| `DSEyebrow(_:tight:)` | ALL-CAPS tracked metadata label |
| `DSSectionHeader(_:)` | Group header |
| `DSChip(_:systemImage:)` | Capsule shortcut with glossy rim |
| `DSGlassCTA(_:systemImage:)` | Full-width primary glass pill |
| `DSIconButton(systemImage:)` | Quiet ghost-disc icon action |
| `DSCircularCTA(_:systemImage:)` | Contemplative round primary action |
| `DSSelectableRow(_:isSelected:)` | Picker row with checkmark |
| `DSImageCard(imageName:title:subtitle:)` | Photo card with meta strip |
| `DSDivider()` | Soft hairline |

### Modifiers
- `.dsGlassCard(radius:fill:)` — translucent card with hairline border.
- `.dsGlossyEdge(radius:soft:)` / `.dsGlossyCapsuleEdge()` — lit-glass rim.
- `.dsGlassSheet(cornerRadius:)` — bottom-sheet treatment (milky material,
  rounded, glossy top hairline, dark scheme). Pair with `.presentationDetents`.

---

## Patterns

**Screen scaffold**
```swift
ZStack(alignment: .bottom) {
    content
}
.background { ContrastBackground(imageName: currentBackground) }
.preferredColorScheme(.dark)
```

**Eyebrow + title block**
```swift
VStack(alignment: .leading, spacing: DS.Space.sm) {
    DSEyebrow("Daily · 2 Min")
    Text(title).font(DS.Font.display).foregroundColor(DS.Palette.textPrimary)
}
.padding(.horizontal, DS.Space.screen)
```

**Glass bottom sheet**
```swift
.sheet(item: $item) { item in
    DetailView(item)
        .presentationDetents([.height(420)])
        .dsGlassSheet()
}
```

**Scrollable reading region that melts into the backdrop**
```swift
ScrollView { Text(longText).font(DS.Font.body).lineSpacing(DS.LineSpacing.reading) }
    .mask(DS.Gradient.readingFade)
```

---

## Adding to the Xcode target

These files are not yet members of the `Interval` target. In Xcode, drag the
`DesignSystem` group into the project navigator (or right-click ▸ *Add Files to
"Interval"…*) and ensure the **Interval** target checkbox is ticked for each
`.swift` file. The `.md` file does not need to be compiled.
