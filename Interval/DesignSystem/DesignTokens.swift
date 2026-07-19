import SwiftUI

// MARK: - Design System
//
// A calm, editorial, glass-on-photography design language extracted from the
// prayer app (Geistliche Anker). The system is dark-only by intent: white type
// floats over a full-bleed photographic background that is auto-dimmed for
// contrast (see `ContrastBackground`). Everything is namespaced under `DS`.
//
// Two type families carry the whole product:
//   • Serif  — editorial / contemplative content (greetings, body, titles)
//   • Sans   — interface chrome (labels, buttons, tabs, list rows)
//
// Surfaces are translucent white washes over material, never opaque panels.
// Hierarchy is expressed almost entirely through white opacity tiers rather
// than through distinct hues.

public enum DS {}

// MARK: - Color

public extension DS {
    /// All foreground/surface color lives on a single white-on-dark opacity
    /// scale. Use these tokens instead of raw `Color.white.opacity(_:)` so the
    /// hierarchy stays consistent across screens.
    enum Palette {
        // Foreground (text & icons)
        public static let textPrimary    = Color.white                 // 1.00 — titles, active values
        public static let textSecondary  = Color.white.opacity(0.85)   // body copy, descriptions
        public static let textTertiary   = Color.white.opacity(0.5)    // eyebrows, metadata, captions
        public static let textDisabled   = Color.white.opacity(0.4)    // placeholders, inactive

        // Strokes / hairlines
        public static let hairlineStrong = Color.white.opacity(0.3)    // CTA borders, focused field
        public static let hairlineMedium = Color.white.opacity(0.18)   // card borders
        public static let hairlineSoft   = Color.white.opacity(0.08)   // dividers

        // Fills (glass washes)
        public static let fillFaint      = Color.white.opacity(0.05)   // inset panels (slider tray)
        public static let fillSubtle     = Color.white.opacity(0.08)   // chips, list rows, icon buttons
        public static let fillRegular    = Color.white.opacity(0.12)   // primary CTA fill
        public static let fillEmphasis   = Color.white.opacity(0.15)   // active tab segment
        public static let fillSelected   = Color.white.opacity(0.2)    // selected list row

        // Accent — the one chromatic note: a warm rose for affection/favorites.
        public static let accent         = Color(red: 0.93, green: 0.36, blue: 0.42)

        /// Controls (sliders, checkmarks, progress) read as plain white — the
        /// photographic backdrop already supplies the color.
        public static let control        = Color.white

        // Scrim used over backgrounds and behind modal overlays.
        public static let scrim          = Color.black
    }
}

// MARK: - Typography

public extension DS {
    enum Font {
        // ── Editorial (serif) ──────────────────────────────────────────────
        /// Time-of-day greeting, screen-level warmth. 22 / regular / serif.
        public static let greeting   = SwiftUI.Font.system(size: 22, weight: .regular, design: .serif)
        /// Large contemplative sheet title. 28 / regular / serif.
        public static let display    = SwiftUI.Font.system(size: 28, weight: .regular, design: .serif)
        /// Long-form reading copy (psalms, prayers). Pair with `lineSpacing(6)`.
        public static let body       = SwiftUI.Font.system(size: 17, weight: .regular, design: .serif)
        /// Auto-scrolling “karaoke” reading text. 20 / regular / serif.
        public static let reading    = SwiftUI.Font.system(size: 20, weight: .regular, design: .serif)
        /// Supporting description / pull quote. Often `.italic()`. 15 / serif.
        public static let quote      = SwiftUI.Font.system(size: 15, weight: .regular, design: .serif)
        /// Serif title used in list rows. 17 / regular / serif.
        public static let titleSerif = SwiftUI.Font.system(size: 17, weight: .regular, design: .serif)

        // ── Interface (sans) ────────────────────────────────────────────────
        /// ALL-CAPS eyebrow / metadata. Pair with `.tracking(DS.Tracking.eyebrow)`.
        public static let eyebrow    = SwiftUI.Font.system(size: 11, weight: .medium)
        /// Tighter caps eyebrow for dense overlays. Pair with `.tracking(2)`.
        public static let eyebrowSm  = SwiftUI.Font.system(size: 10, weight: .medium)
        /// Section header above a group. 14 / medium.
        public static let section    = SwiftUI.Font.system(size: 14, weight: .medium)
        /// Chip / pill / nav-icon label. 14 / medium.
        public static let label      = SwiftUI.Font.system(size: 14, weight: .medium)
        /// Light caps title for compact headers. 22 / light.
        public static let titleLight = SwiftUI.Font.system(size: 22, weight: .light)
        /// Card / sheet sub-title. 15 / semibold.
        public static let subtitle   = SwiftUI.Font.system(size: 15, weight: .semibold)
        /// Navigation bar title. 16–17 / semibold.
        public static let navTitle   = SwiftUI.Font.system(size: 17, weight: .semibold)
        /// Primary button label. Pair with `.tracking(0.5)`. 15 / medium.
        public static let button     = SwiftUI.Font.system(size: 15, weight: .medium)
        /// List-row primary text. 15 / regular.
        public static let row        = SwiftUI.Font.system(size: 15, weight: .regular)
        /// Tab bar caption. 10 / regular.
        public static let tab        = SwiftUI.Font.system(size: 10, weight: .regular)
        /// Tiny caps micro-label (e.g. under a circular CTA). 10 / medium.
        public static let micro      = SwiftUI.Font.system(size: 10, weight: .medium)
    }

    /// Letter-spacing presets — caps labels need air to read as labels.
    enum Tracking {
        public static let eyebrow: CGFloat = 1.5
        public static let eyebrowTight: CGFloat = 2.0
        public static let button: CGFloat = 0.5
    }

    /// Default line spacing for serif reading blocks.
    enum LineSpacing {
        public static let reading: CGFloat = 6
        public static let quote: CGFloat = 5
    }
}

// MARK: - Spacing

public extension DS {
    /// 4-pt based spacing scale. `screen` is the canonical left/right gutter.
    enum Space {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 6
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12   // default gap between cards / rows
        public static let lg: CGFloat = 16   // inner card padding
        public static let xl: CGFloat = 24   // screen gutter & section padding
        public static let xxl: CGFloat = 40  // section-to-section rhythm
        public static let screen: CGFloat = 24
    }
}

// MARK: - Radius

public extension DS {
    enum Radius {
        public static let sheet: CGFloat = 28   // bottom sheets / modal surfaces
        public static let card: CGFloat = 18    // image / content cards
        public static let row: CGFloat = 14     // list rows, text fields
        public static let control: CGFloat = 12 // small icon-button backgrounds
        public static let segment: CGFloat = 10 // tab segments
        // Pills & circular controls use `Capsule()` / `Circle()` directly.
    }
}

// MARK: - Sizing

public extension DS {
    enum Size {
        public static let hitTarget: CGFloat = 44    // minimum tappable area
        public static let iconButton: CGFloat = 32   // compact icon-button frame
        public static let iconButtonGlyph: CGFloat = 18
        public static let tabIcon: CGFloat = 24
        public static let chipIcon: CGFloat = 14
        public static let ctaHeight: CGFloat = 56    // full-width pill CTA
        public static let rowHeight: CGFloat = 50    // selectable list row
        public static let circularCTA: CGFloat = 70  // contemplative round action
        public static let hairline: CGFloat = 1
    }
}

// MARK: - Motion

public extension DS {
    /// Springs, not durations. The product feels physical: surfaces settle,
    /// presses bounce, morphs are elastic.
    enum Motion {
        /// Sheet open/close & primary transitions — smooth, no overshoot.
        public static let hero   = Animation.spring(response: 0.45, dampingFraction: 0.92)
        /// Icon→bar / search morph — slightly springy, elastic.
        public static let morph  = Animation.spring(response: 0.5, dampingFraction: 0.78)
        /// Button-press feedback & favorite toggles — playful bounce.
        public static let press  = Animation.bouncy(duration: 0.3)
        /// Tab / segment selection & small state flips — quick.
        public static let quick  = Animation.spring(duration: 0.2)
        /// Generic content state changes (slider reveal, tab content).
        public static let settle = Animation.spring(duration: 0.3)
    }
}

// MARK: - Gradients

public extension DS {
    enum Gradient {
        /// Glossy hairline used on glass edges (pills, sheets). Brighter at the
        /// top-leading corner, fading toward bottom-trailing — fakes a light source.
        public static let glassEdge = LinearGradient(
            colors: [Color.white.opacity(0.4), Color.white.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Softer variant for smaller chips.
        public static let glassEdgeSoft = LinearGradient(
            colors: [Color.white.opacity(0.3), Color.white.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Top/bottom fade mask for scrollable reading regions, so text melts
        /// into the background instead of clipping hard. Apply via `.mask()`.
        public static let readingFade = LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .white, location: 0.08),
                .init(color: .white, location: 0.92),
                .init(color: .clear, location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom
        )

        /// One-sided bottom fade (content fades out at the bottom only).
        public static let bottomFade = LinearGradient(
            stops: [
                .init(color: .white, location: 0.0),
                .init(color: .white, location: 0.75),
                .init(color: .clear, location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}
