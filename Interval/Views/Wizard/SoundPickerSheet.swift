import SwiftUI

struct SoundPickerSheet: View {
    @Binding var selected: SoundCue
    /// The block's current label — used to preview voice cues in this picker.
    var blockLabel: String = "Block"
    /// Pass `false` when voice label cues are not applicable (e.g. metronome).
    var showVoiceCues: Bool = true
    @Environment(\.dismiss) private var dismiss

    private let soundEngine = SoundEngine.shared

    // Audio-file cues only (voice label cues and protocol-specific voices have their own sections)
    private let audioCues: [SoundCue] = SoundCue.allCases.filter { !$0.isVoiceLabel && !$0.isProtocolVoice }
    private let voiceCues: [SoundCue] = [.voiceLabelFemale, .voiceLabelMale]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {

                        // ── Voice label section ──────────────────────────────
                        if showVoiceCues {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.accent)
                                Text("Voice — speaks the block's label name")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.textTertiary)
                            }
                            .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach(voiceCues, id: \.self) { cue in
                                    SoundRow(
                                        label: cue.displayName,
                                        isSelected: selected == cue,
                                        onSelect: {
                                            selected = cue
                                            dismiss()
                                        },
                                        onPreview: {
                                            if let gender = cue.voiceLabelGender {
                                                VoiceEngine.shared.speakLabel(
                                                    blockLabel.isEmpty ? "Block" : blockLabel,
                                                    gender: gender)
                                            }
                                        },
                                        previewIcon: "play.circle"
                                    )
                                    if cue != voiceCues.last {
                                        Divider().background(Color.borderDefault)
                                            .padding(.leading, 52)
                                    }
                                }
                            }
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.borderDefault, lineWidth: 0.5))
                        }
                        } // end if showVoiceCues

                        // ── Audio cues section ───────────────────────────────
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sounds")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.textTertiary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach(audioCues, id: \.self) { cue in
                                    SoundRow(
                                        label: cue.displayName,
                                        isSelected: selected == cue,
                                        onSelect: {
                                            selected = cue
                                            dismiss()
                                        },
                                        onPreview: cue != .silent ? {
                                            soundEngine.play(cue)
                                        } : nil,
                                        previewIcon: "play.circle"
                                    )
                                    if cue != audioCues.last {
                                        Divider().background(Color.borderDefault)
                                            .padding(.leading, 52)
                                    }
                                }
                            }
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.borderDefault, lineWidth: 0.5))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Sound Cue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.bg)
        .onAppear { soundEngine.preloadAll() }
    }
}

// MARK: - Row

private struct SoundRow: View {
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: (() -> Void)?
    var previewIcon: String = "play.circle"

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onSelect) {
                Text(verbatim: label)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accent : Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onPreview {
                Button(action: onPreview) {
                    Image(systemName: previewIcon)
                        .font(.system(size: 20))
                        .foregroundStyle(.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isSelected ? Color.accent.opacity(0.10) : Color.clear)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}
