import SwiftUI

struct BlockEditorSheet: View {
    @Binding var block: BlockConfig
    var onCancel: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var showSoundPicker = false

    // Quick-pick sounds shown in the grid (audio cues only)
    private let quickSounds: [SoundCue] = [.bellGentle, .bell, .bleep, .silent]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        labelSection
                        durationSection
                        colorSection
                        soundSection
                        hapticSection
                        flashSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Edit Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onCancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                onCancel()
                            }
                        }
                        .foregroundStyle(.textSecondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.accent)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.bg)
        .sheet(isPresented: $showSoundPicker) {
            SoundPickerSheet(selected: $block.soundCue, blockLabel: block.label)
        }
    }

    // MARK: - Label

    private var labelSection: some View {
        EditorSection(title: "Label") {
            TextField("Block name", text: $block.label)
                .onChange(of: block.label) { _, new in
                    if new.count > 20 { block.label = String(new.prefix(20)) }
                }
                .font(.system(size: 15))
                .foregroundStyle(.textPrimary)
                .tint(.accent)
                .padding(12)
                .background(Color.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(Color.borderDefault, lineWidth: 0.5))
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        EditorSection(title: "Duration") {
            HStack(spacing: 12) {
                DurationStepper(label: "min",
                                value: Binding(
                                    get: { block.durationSeconds / 60 },
                                    set: { block.durationSeconds = $0 * 60 + (block.durationSeconds % 60) }
                                ),
                                range: 0...99)
                DurationStepper(label: "sec",
                                value: Binding(
                                    get: { block.durationSeconds % 60 },
                                    set: { newSec in
                                        if newSec < 0 {
                                            let mins = block.durationSeconds / 60
                                            block.durationSeconds = max(0, (mins - 1) * 60 + 59)
                                        } else if newSec >= 60 {
                                            let mins = block.durationSeconds / 60
                                            block.durationSeconds = (mins + 1) * 60
                                        } else {
                                            block.durationSeconds = (block.durationSeconds / 60) * 60 + newSec
                                        }
                                    }),
                                range: 0...59)
            }
        }
    }

    // MARK: - Color

    private var colorSection: some View {
        EditorSection(title: "Color") {
            HStack(spacing: 10) {
                ForEach(BlockColor.allCases) { color in
                    Button {
                        block.color = color
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: block.color == color ? 2 : 0)
                                    .padding(2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        EditorSection(title: "Sound Cue") {
            VStack(spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(quickSounds, id: \.self) { cue in
                        OptionTile(label: cue.displayName,
                                   isSelected: block.soundCue == cue) {
                            block.soundCue = cue
                            // Preview the chosen cue immediately
                            if let gender = cue.voiceLabelGender {
                                VoiceEngine.shared.speakLabel(block.label, gender: gender)
                            } else if cue != .silent {
                                SoundEngine.shared.preload(cues: [cue])
                                SoundEngine.shared.play(cue)
                            }
                        }
                    }
                }
                // Hint shown when a voice cue is selected
                if block.soundCue.isVoiceLabel {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 11))
                            .foregroundStyle(.accent)
                        Text("Will say \"\(block.label)\" at block start")
                            .font(.system(size: 12))
                            .foregroundStyle(.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button {
                    showSoundPicker = true
                } label: {
                    HStack {
                        Text("More sounds")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.accent)
                        if !quickSounds.contains(block.soundCue) {
                            Text("· \(block.soundCue.displayName)")
                                .font(.system(size: 13))
                                .foregroundStyle(.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.surface2)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.borderDefault, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Haptic

    private var hapticSection: some View {
        EditorSection(title: "Haptic") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(HapticCue.allCases) { cue in
                    OptionTile(label: cue.displayName,
                               isSelected: block.hapticCue == cue) {
                        block.hapticCue = cue
                        HapticEngine.shared.fire(cue)
                    }
                }
            }
        }
    }

    // MARK: - Visual Flash

    private var flashSection: some View {
        EditorSection(title: "Visual Flash") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(VisualFlash.allCases) { flash in
                    OptionTile(label: flash.displayName,
                               isSelected: block.visualFlash == flash) {
                        block.visualFlash = flash
                    }
                }
            }
        }
    }
}

// MARK: - Reusable sub-components

struct EditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }
}

struct OptionTile: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accent : Color.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(isSelected ? Color.clear : Color.borderDefault,
                                  lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}

struct DurationStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button {
                let newVal = value - 1
                value = newVal < range.lowerBound ? range.upperBound : newVal
                if !isFocused { inputText = String(format: "%02d", value) }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.textSecondary)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TextField("", text: $inputText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 18, design: .monospaced).weight(.light))
                .foregroundStyle(.textPrimary)
                .frame(width: 44)
                .focused($isFocused)
                .onAppear { inputText = String(format: "%02d", value) }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        inputText = "\(value)"
                    } else {
                        commitInput()
                    }
                }
                .onChange(of: value) { _, newValue in
                    if !isFocused { inputText = String(format: "%02d", newValue) }
                }

            Button {
                let newVal = value + 1
                value = newVal > range.upperBound ? range.lowerBound : newVal
                if !isFocused { inputText = String(format: "%02d", value) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.textSecondary)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9)
            .strokeBorder(Color.borderDefault, lineWidth: 0.5))
        .overlay(alignment: .bottom) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 10))
                .foregroundStyle(.textTertiary)
                .padding(.bottom, 4)
        }
        .frame(height: 52)
    }

    private func commitInput() {
        if let v = Int(inputText) {
            value = min(range.upperBound, max(range.lowerBound, v))
        }
        inputText = String(format: "%02d", value)
    }
}
