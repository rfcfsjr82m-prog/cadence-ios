import SwiftUI

// MARK: - Component library
//
// Reusable views and modifiers built on the `DS` tokens. Everything here is
// glass-on-photography: translucent white washes, hairline gradient edges,
// springy press feedback. Prefer these over re-deriving the same paddings and
// opacities inline.

// MARK: - Press feedback

/// Scales the label down on press with a bouncy settle. Apply to any `Button`
/// via `.buttonStyle(SpringPressStyle())`. Smaller `scale` = punchier press;
/// use ~0.98 for big surfaces, ~0.8 for tiny icon buttons.
public struct SpringPressStyle: ButtonStyle {
    public var scale: CGFloat
    public init(scale: CGFloat = 0.94) { self.scale = scale }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(DS.Motion.press, value: configuration.isPressed)
    }
}

// MARK: - Glass surfaces (modifiers)

public extension View {
    /// Soft translucent card: subtle white fill, hairline border, rounded.
    /// The bread-and-butter container for grouped content.
    func dsGlassCard(radius: CGFloat = DS.Radius.card,
                     fill: Color = DS.Palette.fillSubtle) -> some View {
        self
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(DS.Palette.hairlineMedium, lineWidth: DS.Size.hairline)
            )
    }

    /// Glossy gradient hairline along a rounded edge — the signature “lit glass”
    /// rim. Use on pills and prominent surfaces where a flat border looks dead.
    func dsGlossyEdge(radius: CGFloat = DS.Radius.card,
                      soft: Bool = false) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(soft ? DS.Gradient.glassEdgeSoft : DS.Gradient.glassEdge,
                              lineWidth: DS.Size.hairline)
        )
    }

    /// Capsule glossy edge for chips/pills.
    func dsGlossyCapsuleEdge(soft: Bool = false) -> some View {
        overlay(
            Capsule().strokeBorder(soft ? DS.Gradient.glassEdgeSoft : DS.Gradient.glassEdge,
                                   lineWidth: DS.Size.hairline)
        )
    }
}

// MARK: - Labels

/// ALL-CAPS tracked eyebrow — the system's metadata voice (categories, dates,
/// counts). Renders its text uppercased automatically.
public struct DSEyebrow: View {
    private let text: String
    private let tight: Bool
    public init(_ text: String, tight: Bool = false) {
        self.text = text
        self.tight = tight
    }
    public var body: some View {
        Text(text.uppercased())
            .font(tight ? DS.Font.eyebrowSm : DS.Font.eyebrow)
            .tracking(tight ? DS.Tracking.eyebrowTight : DS.Tracking.eyebrow)
            .foregroundColor(DS.Palette.textTertiary)
    }
}

/// Section header that sits above a group of cards/rows.
public struct DSSectionHeader: View {
    private let title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        Text(title.uppercased())
            .font(DS.Font.section)
            .foregroundColor(DS.Palette.textSecondary)
    }
}

// MARK: - Chip / pill

/// Capsule chip with optional leading icon — used for quick actions and
/// horizontally-scrolling shortcut rows. Pass a system image name or an asset.
public struct DSChip: View {
    private let title: String
    private let systemImage: String?
    private let assetImage: String?

    public init(_ title: String, systemImage: String? = nil, assetImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.assetImage = assetImage
    }

    public var body: some View {
        HStack(spacing: DS.Space.xs + 1) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: DS.Size.chipIcon))
                    .opacity(0.8)
            } else if let assetImage {
                Image(assetImage)
                    .resizable().scaledToFit()
                    .frame(width: DS.Size.chipIcon, height: DS.Size.chipIcon)
                    .opacity(0.8)
            }
            Text(title)
                .font(DS.Font.label)
                .foregroundColor(DS.Palette.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Space.xl - 4)
        .padding(.vertical, DS.Space.md)
        .background(DS.Palette.fillSubtle)
        .clipShape(Capsule())
        .dsGlossyCapsuleEdge()
    }
}

// MARK: - Buttons

/// Full-width primary action: a translucent glass pill with a glossy rim.
/// The system's main "go" affordance.
public struct DSGlassCTA: View {
    private let title: String
    private let systemImage: String?
    private let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: { Haptics.impact(.medium); action() }) {
            HStack(spacing: DS.Space.sm + 2) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: DS.Size.iconButtonGlyph))
                }
                Text(title)
                    .font(DS.Font.button)
                    .tracking(DS.Tracking.button)
            }
            .foregroundColor(DS.Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: DS.Size.ctaHeight)
            .background(DS.Palette.fillRegular)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(DS.Palette.hairlineStrong, lineWidth: DS.Size.hairline))
        }
        .buttonStyle(SpringPressStyle(scale: 0.97))
    }
}

/// Quiet circular icon action (close, settings) — a ghost glass disc.
public struct DSIconButton: View {
    private let systemImage: String
    private let size: CGFloat
    private let action: () -> Void

    public init(systemImage: String, size: CGFloat = DS.Size.iconButton, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: { Haptics.impact(.light); action() }) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DS.Palette.textTertiary)
                .frame(width: size, height: size)
                .background(Circle().fill(DS.Palette.fillSubtle))
        }
        .buttonStyle(SpringPressStyle(scale: 0.85))
    }
}

/// Contemplative round CTA with a glyph above a tiny caps label — for the
/// single most important, unhurried action on a screen.
public struct DSCircularCTA: View {
    private let title: String
    private let systemImage: String
    private let action: () -> Void

    public init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: { Haptics.impact(.medium); action() }) {
            VStack(spacing: DS.Space.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: DS.Size.tabIcon))
                Text(title.uppercased())
                    .font(DS.Font.micro)
            }
            .foregroundColor(DS.Palette.textPrimary)
            .frame(width: DS.Size.circularCTA, height: DS.Size.circularCTA)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(DS.Palette.hairlineStrong, lineWidth: DS.Size.hairline))
        }
        .buttonStyle(SpringPressStyle(scale: 0.9))
    }
}

// MARK: - Selectable row

/// A list row in the "picker" idiom: title left, checkmark right, fill brightens
/// when selected. Used for voice/ambience/option lists inside sheets.
public struct DSSelectableRow: View {
    private let title: String
    private let isSelected: Bool
    private let action: () -> Void

    public init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: { Haptics.selection(); action() }) {
            HStack {
                Text(title)
                    .font(DS.Font.row)
                    .foregroundColor(DS.Palette.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DS.Palette.control)
                }
            }
            .padding(.horizontal, DS.Space.lg)
            .frame(height: DS.Size.rowHeight)
            .background(isSelected ? DS.Palette.fillSelected : DS.Palette.fillSubtle)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous))
        }
        .buttonStyle(SpringPressStyle(scale: 0.98))
    }
}

// MARK: - Image card

/// A photographic content card: full-bleed image on top, a translucent
/// title/meta strip beneath, wrapped in a glass border. The library/collection
/// building block.
public struct DSImageCard: View {
    private let imageName: String
    private let title: String
    private let subtitle: String?
    private let imageHeight: CGFloat

    public init(imageName: String, title: String, subtitle: String? = nil, imageHeight: CGFloat = 120) {
        self.imageName = imageName
        self.title = title
        self.subtitle = subtitle
        self.imageHeight = imageHeight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(imageName)
                .resizable().scaledToFill()
                .frame(height: imageHeight)
                .clipped()

            HStack(spacing: DS.Space.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Font.subtitle)
                        .foregroundColor(DS.Palette.textPrimary)
                    if let subtitle {
                        Text(subtitle.uppercased())
                            .font(DS.Font.eyebrow)
                            .tracking(DS.Tracking.button)
                            .foregroundColor(DS.Palette.textTertiary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, DS.Space.lg - 2)
            .padding(.vertical, DS.Space.md)
            .background(DS.Palette.fillSubtle)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Palette.hairlineMedium, lineWidth: DS.Size.hairline)
        )
    }
}

// MARK: - Divider

/// Hairline divider tuned to the soft white-on-dark scale.
public struct DSDivider: View {
    public init() {}
    public var body: some View {
        Divider().overlay(DS.Palette.hairlineSoft)
    }
}

// MARK: - Sheet styling

public extension View {
    /// Applies the system's bottom-sheet treatment: milky material background,
    /// rounded corners, a glossy top hairline, and a dark color scheme. Pair
    /// with `.presentationDetents(...)` on the presented content.
    func dsGlassSheet(cornerRadius: CGFloat = DS.Radius.sheet) -> some View {
        self
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: cornerRadius, topTrailingRadius: cornerRadius)
                    .strokeBorder(DS.Gradient.glassEdge, lineWidth: DS.Size.hairline)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
            .presentationDragIndicator(.hidden)
            .presentationBackground {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.white.opacity(0.07))
            }
            .presentationCornerRadius(cornerRadius)
            .environment(\.colorScheme, .dark)
    }
}
