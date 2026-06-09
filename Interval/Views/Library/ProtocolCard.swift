import SwiftUI

// MARK: - Card shown in the Programs tab for each TrainingProtocol

struct ProtocolCard: View {
    let proto: TrainingProtocol
    let completedCount: Int
    let onTap: () -> Void

    private var totalCount: Int { proto.units.count }
    private var progress: Double {
        totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }
    private var isComplete: Bool { completedCount == totalCount }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Colour strip (derived from first unit's blocks) ─────────
                if let firstUnit = proto.units.first {
                    ColorStrip(blocks: firstUnit.blocks)
                        .frame(height: 3)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 14, bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0, topTrailingRadius: 14))
                }

                VStack(alignment: .leading, spacing: 12) {

                    // ── Header row ─────────────────────────────────────────
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(verbatim: proto.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.textPrimary)
                            Text(verbatim: proto.category.displayName.uppercased() + " · \(totalCount) " + NSLocalizedString("UNITS", comment: ""))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.textTertiary)
                                .tracking(0.4)
                        }
                        Spacer()
                        if isComplete {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.green)
                        }
                    }

                    // ── Description ────────────────────────────────────────
                    Text(verbatim: proto.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.textSecondary)
                        .lineSpacing(2)
                        .lineLimit(2)

                    // ── Progress bar + label ───────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.surface3)
                                    .frame(height: 5)
                                Capsule()
                                    .fill(isComplete ? Color.green : Color.accent)
                                    .frame(width: max(0, geo.size.width * progress), height: 5)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8),
                                               value: progress)
                            }
                        }
                        .frame(height: 5)

                        HStack {
                            Text(verbatim: completedCount == 0
                                 ? NSLocalizedString("Not started", comment: "")
                                 : isComplete
                                   ? NSLocalizedString("All units complete", comment: "")
                                   : String(format: NSLocalizedString("%lld of %lld units complete", comment: ""), completedCount, totalCount))
                                .font(.system(size: 12))
                                .foregroundStyle(isComplete ? .green : .textTertiary)
                            Spacer()
                            Text("View →")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.accent)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.borderDefault, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
