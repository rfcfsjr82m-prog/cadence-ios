import SwiftUI

struct TimerCard: View {
    let config: TimerConfig
    let onStart: () -> Void
    let onEdit: (() -> Void)?
    let onDuplicate: () -> Void
    let onDelete: (() -> Void)?
    var isPinned: Bool = false
    var onPin: (() -> Void)? = nil
    /// Called when the user taps the card body (not a button).
    /// For personal timers, pass the edit action. Presets show the info sheet automatically.
    var onTap: (() -> Void)? = nil

    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Color strip
            ColorStrip(blocks: config.blocks)
                .frame(height: 3)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 14, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 14))

            VStack(alignment: .leading, spacing: 10) {
                // Name + info + menu
                HStack(alignment: .top) {
                    HStack(spacing: 5) {
                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.accent)
                                .rotationEffect(.degrees(45))
                        }
                        Text(config.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.textPrimary)
                    }
                    Spacer()
                    if config.isPreset && !config.description.isEmpty {
                        Button {
                            showInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.textSecondary)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showInfo) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(verbatim: config.name)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text(verbatim: NSLocalizedString(config.description, comment: ""))
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.textSecondary)
                                    .lineSpacing(3)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .presentationDetents([.height(200)])
                            .presentationBackground(Color.surface)
                            .presentationDragIndicator(.visible)
                        }
                    }
                    Menu {
                        if let onPin {
                            Button(isPinned ? "Unpin" : "Pin to Top",
                                   systemImage: isPinned ? "pin.slash" : "pin") { onPin() }
                        }
                        if onPin != nil { Divider() }
                        if let onEdit {
                            Button("Edit", systemImage: "pencil") { onEdit() }
                        }
                        Button("Duplicate & Edit", systemImage: "doc.on.doc") { onDuplicate() }
                        if let onDelete {
                            Divider()
                            Button("Delete", systemImage: "trash", role: .destructive) { onDelete() }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                            .foregroundStyle(.textSecondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Description (block labels)
                Text(descriptionText)
                    .font(.system(size: 12))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)

                // Stats + Start button
                HStack {
                    Text(statsText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.textTertiary)
                    Spacer()
                    Button(action: onStart) {
                        Text("Start")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(Color.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.borderDefault, lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            if let onTap {
                onTap()
            } else if config.isPreset && !config.description.isEmpty {
                showInfo = true
            }
        }
    }

    private var descriptionText: String {
        config.blocks.map(\.label).joined(separator: " · ")
    }

    private var statsText: String {
        let rounds = config.totalRounds
        let mins   = max(1, config.totalDurationSeconds / 60)
        return "\(rounds) rounds · \(mins) min"
    }
}

// MARK: - Color Strip

struct ColorStrip: View {
    let blocks: [BlockConfig]

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if blocks.isEmpty {
                    Color.surface3
                } else {
                    ForEach(blocks) { block in
                        block.color.color
                            .frame(width: width(for: block, totalWidth: geo.size.width))
                    }
                }
            }
        }
    }

    private func width(for block: BlockConfig, totalWidth: CGFloat) -> CGFloat {
        let total = blocks.reduce(0) { $0 + $1.durationSeconds }
        guard total > 0 else { return totalWidth / CGFloat(blocks.count) }
        return totalWidth * CGFloat(block.durationSeconds) / CGFloat(total)
    }
}

// MARK: - Create New Timer Card

struct CreateTimerCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.accentDim)
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create new timer")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.accent)
                    Text("Build a custom sequence from scratch")
                        .font(.system(size: 12))
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(Color.accent.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }
}
