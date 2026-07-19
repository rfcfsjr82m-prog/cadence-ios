import SwiftUI

// Add images to Assets.xcassets/Backgrounds/ (up to 20).
// Each image name here must match its asset name exactly.
enum BackgroundImageLibrary {

    static let all: [String] = [
        // Add image names here as you drop them into Assets.xcassets/Backgrounds/
        // e.g. "forest", "ocean", "mountain"
    ]

    static func image(named name: String) -> Image? {
        guard !name.isEmpty else { return nil }
        return Image("Backgrounds/\(name)")
    }
}
