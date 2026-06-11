import SwiftUI

// MARK: - Detail sheet: list of training units inside a protocol

struct ProtocolDetailView: View {
    let proto: TrainingProtocol
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        // ── Protocol description ───────────────────────────
                        Text(verbatim: proto.description)
                            .font(.system(size: 15))
                            .foregroundStyle(.textSecondary)
                            .lineSpacing(4)
                            .padding(.horizontal, 20)
                            .padding(.top, 4)

                        // ── Unit list ──────────────────────────────────────
                        VStack(spacing: 10) {
                            ForEach(Array(proto.units.enumerated()), id: \.element.id) { idx, unit in
                                UnitRow(
                                    number: idx + 1,
                                    unit: unit,
                                    isCompleted: appState.completedUnitIDs.contains(unit.id),
                                    onStart: {
                                        guard StoreManager.shared.canRunProgramUnit() else {
                                            showPaywall = true
                                            return
                                        }
                                        StoreManager.shared.recordProgramRun()
                                        dismiss()
                                        appState.startSession(unit, returnTab: .programs)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 32)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle(proto.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.bg)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
        }
    }
}

// MARK: - Individual unit row

private struct UnitRow: View {
    let number: Int
    let unit: TimerConfig
    let isCompleted: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Colour strip from this unit's blocks
            ColorStrip(blocks: unit.blocks)
                .frame(height: 3)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 12, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 12))

            HStack(alignment: .top, spacing: 12) {

                // ── Number badge ──────────────────────────────────────
                ZStack {
                    if isCompleted {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.green)
                    } else {
                        Circle()
                            .fill(Color.surface3)
                            .frame(width: 34, height: 34)
                        Text("\(number)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.textSecondary)
                    }
                }
                .padding(.top, 2)

                // ── Name + description ────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(verbatim: unit.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isCompleted ? .textSecondary : .textPrimary)
                        if isCompleted {
                            Text("Complete")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    if !unit.description.isEmpty {
                        Text(verbatim: unit.description)
                            .font(.system(size: 12))
                            .foregroundStyle(.textTertiary)
                            .lineSpacing(2)
                    }
                }

                Spacer()

                // ── Start button ──────────────────────────────────────
                Button(action: onStart) {
                    Text(isCompleted ? "Redo" : "Start")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isCompleted ? Color.textTertiary : Color.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(isCompleted
                          ? Color.green.opacity(0.30)
                          : Color.borderDefault,
                          lineWidth: 0.5))
    }
}
