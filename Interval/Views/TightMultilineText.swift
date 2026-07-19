import SwiftUI
import UIKit

/// A text view that supports tight (even negative) line height via NSParagraphStyle.
struct TightMultilineText: UIViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor
    let lineHeightMultiple: CGFloat
    let maxWidth: CGFloat
    var maxLines: Int = 0  // 0 = unlimited

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = maxLines
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.lineBreakMode = .byWordWrapping
        label.clipsToBounds = false
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.preferredMaxLayoutWidth = maxWidth
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeightMultiple
        style.alignment = .left
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ])
    }
}
