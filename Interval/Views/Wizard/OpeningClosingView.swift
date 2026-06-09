import SwiftUI
import SwiftData

struct OpeningClosingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [PersistedSession]

    @State private var showOpeningCuePicker = false
    @State private var showClosingCuePicker = false

    private var session: Binding<TimerConfig> {
        Binding(
            get: { appState.wizardSession },
            set: { appState.wizardSession = $0 }
        )
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Step indicator
                    StepIndicator(currentStep: 1, totalSteps: 3)
                        .padding(.horizontal, 20)

                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start & End")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.textPrimary)
                        Text("Set how your session begins and ends")
                            .font(.system(size: 14))
                            .foregroundStyle(.textSecondary)
                    }
                    .padding(.horizontal, 20)

                    // Opening card
                    openingCard

                    // Closing card
                    closingCard

                    // Category picker
                    categoryPicker

                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    // MARK: - Opening card

    private var openingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blockTeal.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "clock")
                        .font(.system(size: 16))
                        .foregroundStyle(.blockTeal)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Countdown before start")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textPrimary)
                    Text(openingSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.textSecondary)
                }
            }

            // Countdown stepper
            CueStepperRow(
                label: "Seconds",
                value: session.openingCountdownSecs,
                step: 5,
                range: 0...60
            )

            // Countdown sound toggle — disabled when countdown is 0s
            let countdownIsZero = session.wrappedValue.openingCountdownSecs == 0
            VoiceToggleRow(
                label: "Countdown sound",
                isOn: session.openingCountdownSoundEnabled
            )
            .disabled(countdownIsZero)
            .opacity(countdownIsZero ? 0.35 : 1)
            .onChange(of: session.wrappedValue.openingCountdownSecs) { _, secs in
                if secs == 0 { session.wrappedValue.openingCountdownSoundEnabled = false }
            }

            // Announcement cue
            AnnouncementCueRow(
                label: "Opening sound",
                cue: session.wrappedValue.openingAnnouncementCue
            ) { showOpeningCuePicker = true }
            .sheet(isPresented: $showOpeningCuePicker) {
                AnnouncementCuePickerSheet(selected: session.openingAnnouncementCue, isClosing: false)
            }
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(Color.borderDefault, lineWidth: 0.5))
        .padding(.horizontal, 20)
    }

    private var openingSubtitle: String {
        let secs = session.wrappedValue.openingCountdownSecs
        if secs == 0 { return NSLocalizedString("no countdown", comment: "") }
        return String(format: NSLocalizedString("%lld sec", comment: ""), secs)
    }

    // MARK: - Closing card

    private var closingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blockLavender.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.blockLavender)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("End of session")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textPrimary)
                    Text(verbatim: session.wrappedValue.closingAnnouncementCue.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(.textSecondary)
                }
            }

            AnnouncementCueRow(
                label: "Closing sound",
                cue: session.wrappedValue.closingAnnouncementCue
            ) { showClosingCuePicker = true }
            .sheet(isPresented: $showClosingCuePicker) {
                AnnouncementCuePickerSheet(selected: session.closingAnnouncementCue, isClosing: true)
            }
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(Color.borderDefault, lineWidth: 0.5))
        .padding(.horizontal, 20)
    }

    // MARK: - Category picker

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            HStack(spacing: 10) {
                ForEach(Category.allCases) { cat in
                    let isSelected = session.wrappedValue.category == cat
                    Button { session.wrappedValue.category = cat } label: {
                        Text(verbatim: cat.displayName)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .white : .textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isSelected ? Color.accentDim : Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(isSelected ? Color.accent : Color.borderDefault,
                                              lineWidth: isSelected ? 1 : 0.5))
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Save
                Button { saveAndExit() } label: {
                    Text("Save")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.accentDim)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.accent.opacity(0.3), lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                // Start now
                Button { saveAndStart() } label: {
                    Text("Save & Start Now")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            // Back button
            Button {
                appState.navigate(to: .wizardStep1)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                    Text("Back")
                        .font(.system(size: 14))
                }
                .foregroundStyle(.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.bg)
    }

    // MARK: - Persistence

    private func saveAndExit() {
        saveSession()
        appState.navigate(to: .library)
    }

    private func saveAndStart() {
        saveSession()
        appState.startSession(appState.wizardSession)
    }

    private func saveSession() {
        var config = appState.wizardSession
        config.createdAt = Date()

        if let editingID = appState.editingSessionID,
           let existing = sessions.first(where: { $0.id == editingID }) {
            existing.update(with: config)
        } else {
            modelContext.insert(PersistedSession(config: config))
        }
    }
}

// MARK: - Sub-components

private struct CueStepperRow: View {
    let label: String
    @Binding var value: Int
    let step: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(LocalizedStringKey(label))
                .font(.system(size: 14))
                .foregroundStyle(.textSecondary)
            Spacer()
            HStack(spacing: 6) {
                Button { value = max(range.lowerBound, value - step) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13))
                        .foregroundStyle(.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Color.surface2)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("\(value)s")
                    .font(.system(size: 15, design: .monospaced).weight(.light))
                    .foregroundStyle(.textPrimary)
                    .frame(minWidth: 44)
                    .multilineTextAlignment(.center)

                Button { value = min(range.upperBound, value + step) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                        .foregroundStyle(.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Color.surface2)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct VoiceToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(LocalizedStringKey(label))
                .font(.system(size: 14))
                .foregroundStyle(.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.accent)
        }
    }
}

// MARK: - Announcement cue row

private struct AnnouncementCueRow: View {
    let label: String
    let cue: AnnouncementCue
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(LocalizedStringKey(label))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(verbatim: cue.displayName)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Announcement cue picker sheet

private struct AnnouncementCuePickerSheet: View {
    @Binding var selected: AnnouncementCue
    var isClosing: Bool = false
    @Environment(\.dismiss) private var dismiss

    private let voiceOptions: [AnnouncementCue] = [.voice(.female), .voice(.male)]
    private let soundOptions: [AnnouncementCue] = SoundCue.allCases
        .filter { $0 != .silent }
        .map { .sound($0) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                List {
                    Section("Voice") {
                        ForEach(voiceOptions, id: \.displayName) { cue in
                            cueRow(cue)
                        }
                    }
                    Section("Sound Cue") {
                        ForEach(soundOptions, id: \.displayName) { cue in
                            cueRow(cue)
                        }
                    }
                    Section {
                        cueRow(.none)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Announcement")
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
    }

    @ViewBuilder
    private func cueRow(_ cue: AnnouncementCue) -> some View {
        HStack(spacing: 12) {
            Button { selected = cue } label: {
                HStack {
                    Text(verbatim: cue.displayName)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if cue != .none {
                Button { playPreview(cue) } label: {
                    Image(systemName: "play.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.accent)
                }
                .buttonStyle(.plain)
            }

            if selected == cue {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accent)
                    .frame(width: 20)
            } else {
                Color.clear.frame(width: 20)
            }
        }
        .listRowBackground(Color.surface)
    }

    private func playPreview(_ cue: AnnouncementCue) {
        switch cue {
        case .none: break
        case .voice(let gender):
            VoiceEngine.shared.play(isClosing ? .finish(gender) : .start(gender))
        case .sound(let soundCue):
            SoundEngine.shared.play(soundCue)
        }
    }
}
