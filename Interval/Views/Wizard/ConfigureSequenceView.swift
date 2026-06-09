import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension Int: @retroactive Identifiable { public var id: Int { self } }

struct ConfigureSequenceView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [PersistedSession]

    @State private var editingBlockIndex: Int? = nil
    @State private var isNewBlock: Bool = false
    @State private var isSelecting: Bool = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showDiscardAlert: Bool = false
    @State private var draggingID: UUID? = nil
    @State private var metronomeUseMinutes: Bool = false
    @State private var showMetronomeSoundPicker = false

    // Snapshot taken at screen-open so we can detect real changes
    @State private var originalSession: TimerConfig? = nil

    private var session: Binding<TimerConfig> {
        Binding(
            get: { appState.wizardSession },
            set: { appState.wizardSession = $0 }
        )
    }

    private var blocksBinding: Binding<[BlockConfig]> {
        Binding(
            get: { appState.wizardSession.blocks },
            set: { appState.wizardSession.blocks = $0 }
        )
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
                .dismissKeyboardOnTap()   // tap on bare background dismisses keyboard
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Step indicator
                    StepIndicator(currentStep: 0, totalSteps: 3)
                        .padding(.horizontal, 20)

                    // Title
                    Text("Build your sequence")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.textPrimary)
                        .padding(.horizontal, 20)

                    // Name field
                    nameField

                    // Sequence editor
                    sequenceEditor

                    // Repeat section
                    repeatSection

                    // Prep signals (combined card)
                    if lastBlockDurationSecs >= 3 {
                        prepSignalsSection
                    }

                    // Metronome (feature-flagged)
                    if FeatureFlags.metronome {
                        metronomeSection
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .onAppear {
            if originalSession == nil { originalSession = appState.wizardSession }
        }
        .confirmationDialog("You have unsaved changes",
                            isPresented: $showDiscardAlert,
                            titleVisibility: .visible) {
            Button("Save changes") { saveAndGoBack() }
            Button("Discard changes", role: .destructive) { appState.navigate(to: .library) }
            Button("Keep editing", role: .cancel) { }
        } message: {
            Text("Would you like to save before leaving?")
        }
        .sheet(item: $editingBlockIndex) { idx in
            if idx < session.wrappedValue.blocks.count {
                BlockEditorSheet(
                    block: blockBinding(at: idx),
                    onCancel: isNewBlock ? { removeBlock(at: idx) } : nil
                )
            }
        }
        .sheet(isPresented: $showMetronomeSoundPicker) {
            SoundPickerSheet(selected: session.metronomeSoundCue,
                             blockLabel: "Metronome",
                             showVoiceCues: false)
        }
    }

    // MARK: - Name field

    private var nameField: some View {
        TextField("Timer name", text: session.name)
            .font(.system(size: 16))
            .foregroundStyle(.textPrimary)
            .tint(.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Color.borderElevated, lineWidth: 0.5))
            .padding(.horizontal, 20)
    }

    // MARK: - Sequence editor

    private var sequenceEditor: some View {
        VStack(spacing: 0) {
            // Header row
            if !session.wrappedValue.blocks.isEmpty {
                HStack {
                    if isSelecting && !selectedIDs.isEmpty {
                        Button {
                            deleteSelected()
                        } label: {
                            Text("Delete (\(selectedIDs.count))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer()
                    }
                    Spacer()
                    Button {
                        isSelecting.toggle()
                        selectedIDs = []
                    } label: {
                        Text(isSelecting ? "Done" : "Select")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            ForEach(Array(session.wrappedValue.blocks.enumerated()), id: \.element.id) { idx, block in
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        if isSelecting {
                            Button {
                                if selectedIDs.contains(block.id) {
                                    selectedIDs.remove(block.id)
                                } else {
                                    selectedIDs.insert(block.id)
                                }
                            } label: {
                                Image(systemName: selectedIDs.contains(block.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(selectedIDs.contains(block.id)
                                                     ? Color.accent : Color.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .leading).combined(with: .opacity))

                            BlockRow(
                                block: block,
                                onEdit: { isNewBlock = false; editingBlockIndex = idx },
                                onDuplicate: { duplicateBlock(at: idx) },
                                onDelete: { removeBlock(at: idx) },
                                isSelecting: true
                            )
                        } else {
                            SwipeToDelete { removeBlock(at: idx) } content: {
                                BlockRow(
                                    block: block,
                                    onEdit: { isNewBlock = false; editingBlockIndex = idx },
                                    onDuplicate: { duplicateBlock(at: idx) },
                                    onDelete: { removeBlock(at: idx) },
                                    isSelecting: false
                                )
                            }
                        }
                    }
                    .onDrag {
                        draggingID = block.id
                        return NSItemProvider(object: block.id.uuidString as NSString)
                    }
                    if idx < session.wrappedValue.blocks.count - 1 {
                        Rectangle()
                            .fill(Color.borderDefault)
                            .frame(width: 1, height: 12)
                            .padding(.leading, isSelecting ? 42 : 32)
                    }
                }
                .onDrop(of: [UTType.plainText], delegate: BlockDropDelegate(
                    item: block,
                    blocks: blocksBinding,
                    draggingID: $draggingID
                ))
            }
            .animation(.easeInOut(duration: 0.2), value: isSelecting)

            // Add block button
            if !isSelecting {
                Button {
                    addBlock()
                    isNewBlock = true
                    editingBlockIndex = session.wrappedValue.blocks.count - 1
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .medium))
                        Text("Add interval block")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color.accent.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, session.wrappedValue.blocks.isEmpty ? 0 : 12)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Repeat section

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repeat")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            // Tab selector
            RepeatModePicker(repeatMode: session.repeatMode)
                .padding(.horizontal, 20)

            // Controls
            HStack {
                Spacer()
                switch session.wrappedValue.repeatMode {
                case .rounds(let n):
                    RepeatStepper(
                        label: "rounds",
                        value: Binding(
                            get: { n },
                            set: { session.repeatMode.wrappedValue = .rounds(max(1, $0)) }),
                        range: 1...99
                    )
                case .duration(let mins):
                    RepeatStepper(
                        label: "minutes",
                        value: Binding(
                            get: { mins },
                            set: { session.repeatMode.wrappedValue = .duration(minutes: max(1, $0)) }),
                        range: 1...999
                    )
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            // Live calculation
            Text(liveCalcText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.textTertiary)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Prep signals section (combined)

    /// Duration of the last block in seconds (0 if no blocks).
    private var lastBlockDurationSecs: Int {
        session.wrappedValue.blocks.last?.durationSeconds ?? 0
    }

    /// Minimum block duration across all blocks (0 if no blocks).
    private var minBlockDurationSecs: Int {
        session.wrappedValue.blocks.map(\.durationSeconds).min() ?? 0
    }

    private var hasMultipleBlocks: Bool {
        session.wrappedValue.blocks.count > 1
    }

    private var prepSignalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prep Signals")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {

                // MARK: Round prep toggle
                prepRow(
                    title: "Round prep signal",
                    subtitle: "Beeps at the end of each round to signal the next",
                    isOn: Binding(
                        get: { session.wrappedValue.roundPrepEnabled },
                        set: { session.roundPrepEnabled.wrappedValue = $0 }
                    )
                )

                if session.wrappedValue.roundPrepEnabled {
                    durationRow(
                        selected: Binding(
                            get: { session.wrappedValue.roundPrepSecs },
                            set: { session.roundPrepSecs.wrappedValue = $0 }
                        ),
                        options: availableRoundPrepDurations
                    )
                }

                // MARK: Phase prep toggle — only when there are multiple blocks
                if hasMultipleBlocks && minBlockDurationSecs >= 3 {
                    Divider().background(Color.borderDefault).padding(.horizontal, 14)

                    prepRow(
                        title: "Phase prep signal",
                        subtitle: "Beeps at the end of each block to signal the next phase",
                        isOn: Binding(
                            get: { session.wrappedValue.phasePrepEnabled },
                            set: { session.phasePrepEnabled.wrappedValue = $0 }
                        )
                    )

                    if session.wrappedValue.phasePrepEnabled {
                        durationRow(
                            selected: Binding(
                                get: { session.wrappedValue.phasePrepSecs },
                                set: { session.phasePrepSecs.wrappedValue = $0 }
                            ),
                            options: availablePhasePrepDurations
                        )
                    }
                }
            }
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.borderDefault, lineWidth: 0.5))
            .padding(.horizontal, 20)
        }
    }

    private func prepRow(title: LocalizedStringKey, subtitle: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.accent)
        }
        .padding(14)
    }

    private func durationRow(selected: Binding<Int>, options: [Int]) -> some View {
        HStack {
            Text("Duration")
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { secs in
                    Button(action: { selected.wrappedValue = secs }) {
                        Text("\(secs)s")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(selected.wrappedValue == secs ? .white : Color.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selected.wrappedValue == secs ? Color.accent : Color.surface3)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
    }

    private var availableRoundPrepDurations: [Int] {
        let last = lastBlockDurationSecs
        if last >= 5 { return [3, 5] }
        if last >= 3 { return [3] }
        return []
    }

    private var availablePhasePrepDurations: [Int] {
        let min = minBlockDurationSecs
        if min >= 5 { return [3, 5] }
        if min >= 3 { return [3] }
        return []
    }

    // MARK: - Metronome section

    private var metronomeSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header + description
            VStack(alignment: .leading, spacing: 4) {
                Text("Advanced: Metronome")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text("Set a repeating background signal — like a breath cue, awareness bell, or pacing chime — that runs independently throughout your session.")
                    .font(.system(size: 12))
                    .foregroundStyle(.textTertiary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                // Enable toggle
                HStack {
                    Text("Enable")
                        .font(.system(size: 14))
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Toggle("", isOn: session.metronomeEnabled)
                        .labelsHidden()
                        .tint(Color.accent)
                }
                .padding(14)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(Color.borderDefault, lineWidth: 0.5))

                if session.wrappedValue.metronomeEnabled {
                    VStack(spacing: 10) {

                        // Interval unit picker
                        HStack(spacing: 0) {
                            unitButton("Seconds", active: !metronomeUseMinutes) {
                                if metronomeUseMinutes {
                                    // keep current value as-is (already stored in seconds)
                                    metronomeUseMinutes = false
                                }
                            }
                            unitButton("Minutes", active: metronomeUseMinutes) {
                                if !metronomeUseMinutes {
                                    // snap to nearest whole minute (min 1)
                                    let mins = max(1, Int(round(Double(session.wrappedValue.metronomeIntervalSeconds) / 60.0)))
                                    session.wrappedValue.metronomeIntervalSeconds = mins * 60
                                    metronomeUseMinutes = true
                                }
                            }
                        }
                        .background(Color.surface2)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.borderDefault, lineWidth: 0.5))

                        // Interval stepper
                        if metronomeUseMinutes {
                            RepeatStepper(
                                label: "Every",
                                value: Binding(
                                    get: { max(1, session.wrappedValue.metronomeIntervalSeconds / 60) },
                                    set: { session.wrappedValue.metronomeIntervalSeconds = max(1, $0) * 60 }
                                ),
                                range: 1...60,
                                unit: "min"
                            )
                        } else {
                            RepeatStepper(
                                label: "Every",
                                value: Binding(
                                    get: { session.wrappedValue.metronomeIntervalSeconds },
                                    set: { session.wrappedValue.metronomeIntervalSeconds = min(300, max(1, $0)) }
                                ),
                                range: 1...300,
                                unit: "sec"
                            )
                        }

                        // Sound cue — same grid style as block editor
                        EditorSection(title: "Sound Cue") {
                            VStack(spacing: 10) {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach([SoundCue.bellGentle, .bell, .bleep, .silent], id: \.self) { cue in
                                        OptionTile(label: cue.displayName,
                                                   isSelected: session.wrappedValue.metronomeSoundCue == cue) {
                                            session.wrappedValue.metronomeSoundCue = cue
                                            if cue != .silent {
                                                SoundEngine.shared.preload(cues: [cue])
                                                SoundEngine.shared.play(cue)
                                            }
                                        }
                                    }
                                }
                                Button { showMetronomeSoundPicker = true } label: {
                                    HStack {
                                        Text("More sounds")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.accent)
                                        let quick: [SoundCue] = [.bellGentle, .bell, .bleep, .silent]
                                        if !quick.contains(session.wrappedValue.metronomeSoundCue) {
                                            Text("· \(session.wrappedValue.metronomeSoundCue.displayName)")
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

                        // Haptic cue — same grid style as block editor
                        EditorSection(title: "Haptic") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(HapticCue.allCases) { cue in
                                    OptionTile(label: cue.displayName,
                                               isSelected: session.wrappedValue.metronomeHapticCue == cue) {
                                        session.wrappedValue.metronomeHapticCue = cue
                                        HapticEngine.shared.fire(cue)
                                    }
                                }
                            }
                        }

                    }
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 20)
            .animation(.easeInOut(duration: 0.2), value: session.wrappedValue.metronomeEnabled)
        }
    }

    @ViewBuilder
    private func unitButton(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? .white : .textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(active ? Color.accent : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: active)
    }

    private var liveCalcText: String {
        let s = session.wrappedValue
        let roundSecs = s.roundDurationSeconds
        let rounds    = s.totalRounds
        let totalSecs = rounds * roundSecs
        let mins      = totalSecs / 60
        let secs      = totalSecs % 60
        let blocksStr = s.blocks.map { TimeFormatter.durationBadge($0.durationSeconds) }.joined(separator: " + ")
        if blocksStr.isEmpty { return "Add blocks to see estimate" }
        return "\(rounds) × \(roundSecs)s = \(mins)m \(secs)s"
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                let hasChanges = originalSession.map { $0 != session.wrappedValue } ?? false
                if hasChanges {
                    showDiscardAlert = true
                } else {
                    appState.navigate(to: .library)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                    Text("Library")
                        .font(.system(size: 15))
                }
                .foregroundStyle(.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                appState.navigate(to: .wizardStep2)
            } label: {
                Text("Next: Start & End")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                    .background(Color.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(session.wrappedValue.blocks.isEmpty)
            .opacity(session.wrappedValue.blocks.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.bg)
    }

    // MARK: - Helpers

    // MARK: - Persistence

    private func saveAndGoBack() {
        var config = appState.wizardSession
        config.createdAt = Date()
        if let editingID = appState.editingSessionID,
           let existing = sessions.first(where: { $0.id == editingID }) {
            existing.update(with: config)
        } else {
            modelContext.insert(PersistedSession(config: config))
            appState.editingSessionID = config.id
        }
        appState.navigate(to: .library)
    }

    private func addBlock() {
        let idx   = session.wrappedValue.blocks.count
        let prev  = session.wrappedValue.blocks.last
        let color = prev.map { BlockColor.next(after: $0.color) } ?? .teal
        let block = BlockConfig(
            label: "Phase \(idx + 1)",
            durationSeconds: prev?.durationSeconds ?? 60,
            color: color,
            soundCue: prev?.soundCue ?? .bellGentle,
            hapticCue: prev?.hapticCue ?? .softPulse,
            visualFlash: prev?.visualFlash ?? .blockColor
        )
        session.wrappedValue.blocks.append(block)
    }

    private func removeBlock(at index: Int) {
        session.wrappedValue.blocks.remove(at: index)
    }

    private func duplicateBlock(at index: Int) {
        var copy = session.wrappedValue.blocks[index]
        copy.id = UUID()
        session.wrappedValue.blocks.append(copy)
    }

    private func deleteSelected() {
        session.wrappedValue.blocks.removeAll { selectedIDs.contains($0.id) }
        selectedIDs = []
        isSelecting = false
    }

    private func blockBinding(at index: Int) -> Binding<BlockConfig> {
        Binding(
            get: {
                guard index < appState.wizardSession.blocks.count else { return .init() }
                return appState.wizardSession.blocks[index]
            },
            set: {
                guard index < appState.wizardSession.blocks.count else { return }
                appState.wizardSession.blocks[index] = $0
            }
        )
    }
}

// MARK: - Block row

private struct BlockRow: View {
    let block: BlockConfig
    let onEdit: () -> Void
    var onDuplicate: (() -> Void)? = nil
    let onDelete: () -> Void
    var isSelecting: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(block.color.color)
                .frame(width: 10, height: 10)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(block.label)
                    .font(.system(size: 14))
                    .foregroundStyle(.textPrimary)
                Text("\(block.soundCue.displayName) · \(block.hapticCue.displayName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.textTertiary)
            }

            Spacer()

            Text(TimeFormatter.durationBadge(block.durationSeconds))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.surface3)
                .clipShape(Capsule())

            if !isSelecting {
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .foregroundStyle(.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let onDuplicate {
                    Button(action: onDuplicate) {
                        Image(systemName: "plus.square.on.square")
                            .font(.system(size: 13))
                            .foregroundStyle(.textTertiary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9)
            .strokeBorder(Color.borderDefault, lineWidth: 0.5))
    }
}

// MARK: - Drag-and-drop delegate

private struct BlockDropDelegate: DropDelegate {
    let item: BlockConfig
    @Binding var blocks: [BlockConfig]
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != item.id else { return }
        guard let from = blocks.firstIndex(where: { $0.id == draggingID }),
              let to   = blocks.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            blocks.move(fromOffsets: IndexSet(integer: from),
                        toOffset: to > from ? to + 1 : to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Repeat mode picker

private struct RepeatModePicker: View {
    @Binding var repeatMode: RepeatMode

    var isRounds: Bool {
        if case .rounds = repeatMode { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 0) {
            modeButton("By rounds", active: isRounds) {
                if !isRounds { repeatMode = .rounds(8) }
            }
            modeButton("By duration", active: !isRounds) {
                if isRounds { repeatMode = .duration(minutes: 10) }
            }
        }
        .background(Color.surface2)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.borderDefault, lineWidth: 0.5))
    }

    @ViewBuilder
    private func modeButton(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? .white : .textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(active ? Color.accent : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: active)
    }
}

// MARK: - Repeat stepper row

private struct RepeatStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: String = ""   // optional suffix shown inside the field (e.g. "sec", "min")

    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    // Bottom label: prefer explicit unit, fall back to the main label
    private var bottomLabel: String { unit.isEmpty ? label : unit }

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
                .tint(.accent)
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
            Text(LocalizedStringKey(bottomLabel))
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

// MARK: - Step indicator

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(segmentColor(for: i))
                    .frame(height: 3)
            }
        }
    }

    private func segmentColor(for index: Int) -> Color {
        if index < currentStep  { return Color.accent.opacity(0.4) }
        if index == currentStep { return Color.accent }
        return Color.surface3
    }
}
