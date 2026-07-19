import SwiftUI

// MARK: - Design System Colors

// MARK: - ShapeStyle shorthand extensions (enables .textPrimary etc. in foregroundStyle)

extension ShapeStyle where Self == Color {
    static var bg:             Color { .init(hex: "0F0F11") }
    static var surface:        Color { .init(hex: "18181C") }
    static var surface2:       Color { .init(hex: "1F1F25") }
    static var surface3:       Color { .init(hex: "27272F") }
    static var textPrimary:    Color { .init(hex: "F0F0F2") }
    static var textSecondary:  Color { .init(hex: "8A8A96") }
    static var textTertiary:   Color { .init(hex: "56565E") }
    static var accent:         Color { .init(hex: "7C6FFF") }
    static var blockTeal:      Color { .init(hex: "3DD9A4") }
    static var blockLavender:  Color { .init(hex: "A78BFA") }
    static var blockCoral:     Color { .init(hex: "FF7B6B") }
    static var blockAmber:     Color { .init(hex: "F5A623") }
    static var blockSky:       Color { .init(hex: "60B8FF") }
    static var blockPink:      Color { .init(hex: "F472B6") }
    static var blockSage:      Color { .init(hex: "86EFAC") }
    static var timerIndicator: Color { .init(hex: "44444D") }
}

extension Color {
    static let bg          = Color(hex: "0F0F11")
    static let surface     = Color(hex: "18181C")
    static let surface2    = Color(hex: "1F1F25")
    static let surface3    = Color(hex: "27272F")

    static let textPrimary   = Color(hex: "F0F0F2")
    static let textSecondary = Color(hex: "8A8A96")
    static let textTertiary  = Color(hex: "56565E")

    static let accent    = Color(hex: "7C6FFF")
    static let accentDim = Color(hex: "7C6FFF").opacity(0.15)

    // Block colors
    static let blockTeal     = Color(hex: "3DD9A4")
    static let blockLavender = Color(hex: "A78BFA")
    static let blockCoral    = Color(hex: "FF7B6B")
    static let blockAmber    = Color(hex: "F5A623")
    static let blockSky      = Color(hex: "60B8FF")
    static let blockPink     = Color(hex: "F472B6")
    static let blockSage     = Color(hex: "86EFAC")

    // Timer screen
    static let timerBg       = Color(hex: "080809")
    static let timerIndicator = Color(hex: "44444D")
    static let ringTrack     = Color.white.opacity(0.035)

    static let borderDefault  = Color.white.opacity(0.08)
    static let borderElevated = Color.white.opacity(0.14)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:  (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Block Color Enum

enum BlockColor: String, Codable, CaseIterable, Identifiable {
    case teal, lavender, coral, amber, sky, pink, sage

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .teal:     return .blockTeal
        case .lavender: return .blockLavender
        case .coral:    return .blockCoral
        case .amber:    return .blockAmber
        case .sky:      return .blockSky
        case .pink:     return .blockPink
        case .sage:     return .blockSage
        }
    }

    /// Hex string for the block colour — used when passing colour to the widget extension.
    var hexString: String {
        switch self {
        case .teal:     return "3DD9A4"
        case .lavender: return "A78BFA"
        case .coral:    return "FF7B6B"
        case .amber:    return "F5A623"
        case .sky:      return "60B8FF"
        case .pink:     return "F472B6"
        case .sage:     return "86EFAC"
        }
    }

    static func next(after current: BlockColor) -> BlockColor {
        let all = BlockColor.allCases
        let idx = all.firstIndex(of: current) ?? 0
        return all[(idx + 1) % all.count]
    }

    nonisolated(unsafe) static var cycling: [BlockColor] = allCases
}
