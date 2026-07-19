import SwiftUI
import AVFoundation
import StoreKit
@preconcurrency import ActivityKit

@MainActor
struct ActiveTimerView: View {
    let config: TimerConfig

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    // MARK: - Timer state

    @State private var elapsed: Int = 0
    @State private var isPaused: Bool = false
    @State private var endReason: SessionEndReason? = nil
    // Primary day-0 paywall placement: shown once, right after the user's
    // first completed session, on the way back to the library.
    @State private var showPostSessionPaywall = false
    @AppStorage("hasSeenPostSessionPaywall") private var hasSeenPostSessionPaywall = false
    @State private var sessionStartDate: Date = Date()
    @State private var sessionEndDate: Date = Date()   // recorded at the moment the session finishes

    // Real-time ring interpolation — updated every frame via TimelineView
    @State private var lastTickDate: Date = Date()

    // Visual flash overlay
    @State private var flashOpacity: Double = 0

    // Countdown
    @State private var showCountdown: Bool = false

    // Live Activity
    @State private var liveActivity: Activity<CadenceActivityAttributes>? = nil

    // MARK: - Computed

    private var totalSecs: Int { max(1, config.totalDurationSeconds) }
    private var roundSecs:  Int { max(1, config.roundDurationSeconds) }
    private var totalRounds: Int { config.totalRounds }

    private var currentRound: Int { elapsed / roundSecs }
    private var secInRound: Int   { elapsed % roundSecs }

    private var currentBlockIndex: Int {
        var acc = 0
        for (i, block) in config.blocks.enumerated() {
            acc += block.durationSeconds
            if secInRound < acc { return i }
        }
        return max(0, config.blocks.count - 1)
    }

    private var currentBlock: BlockConfig {
        guard !config.blocks.isEmpty else { return BlockConfig() }
        return config.blocks[currentBlockIndex]
    }

    private var secInBlock: Int {
        var acc = 0
        for block in config.blocks {
            let next = acc + block.durationSeconds
            if secInRound < next { return secInRound - acc }
            acc = next
        }
        return 0
    }

    private var blockLeft: Int { currentBlock.durationSeconds - secInBlock }
    private var elapsedDisplay: String { TimeFormatter.elapsed(elapsed) }
    private var remainingDisplay: String { TimeFormatter.elapsed(max(0, totalSecs - elapsed)) }

    private var blockColor: Color { currentBlock.color.color }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.timerBg.ignoresSafeArea()

            // Background image (if one is selected for this timer)
            if let bg = BackgroundImageLibrary.image(named: config.backgroundImageName) {
                bg
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .clipped()
                    .allowsHitTesting(false)
            }

            // Flash overlay
            currentBlock.color.color
                .ignoresSafeArea()
                .opacity(flashOpacity)
                .allowsHitTesting(false)

            // Four corner indicators
            cornerIndicators

            // Center rings + timer
            VStack(spacing: 0) {
                ZStack {
                    // TimelineView drives the rings at display refresh rate so
                    // they move continuously instead of jumping every second.
                    TimelineView(.animation) { tl in
                        let frozen = isPaused || showCountdown || endReason != nil
                        let t = frozen ? 0.0
                                       : max(0, min(1, tl.date.timeIntervalSince(lastTickDate)))
                        RingsView(
                            blockColor: blockColor,
                            blockFraction: liveBlockFraction(t),
                            roundFraction: liveRoundFraction(t),
                            sessionFraction: liveSessionFraction(t)
                        )
                    }

                    Text(TimeFormatter.timerDisplay(blockLeft))
                        .font(.system(size: 44, design: .monospaced).weight(.light))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .padding(.horizontal, 56)   // breathing room from the inner ring
                        .accessibilityLabel("Block time remaining: \(blockLeft) seconds")
                }
            }

            // Bottom controls
            VStack {
                Spacer()
                controlBar
            }

            // Countdown overlay
            if showCountdown && config.openingCountdownSecs > 0 {
                CountdownOverlay(
                    seconds: config.openingCountdownSecs,
                    label: config.openingCountdownLabel,
                    soundEnabled: config.openingCountdownSoundEnabled,
                    onFinish: {
                        showCountdown = false
                        lastTickDate = Date()   // anchor interpolation from session start
                        // Fire first block cues immediately — don't wait for the first tick
                        fireCues(for: currentBlock)
                    },
                    onStart: {
                        // Play the countdown-start cue (e.g. "Warming up") immediately
                        playAnnouncementCue(config.openingCountdownCue, isStart: true)
                    },
                    onDismiss: {
                        SoundEngine.shared.stopKeepAlive()
                        FlashlightEngine.shared.teardown()
                        endLiveActivity()
                        appState.endSession()
                    },
                    onVoice: {
                        playAnnouncementCue(config.openingAnnouncementCue, isStart: true)
                    }
                )
            }

            // Session done overlay
            if let reason = endReason {
                SessionDoneOverlay(
                    reason: reason,
                    config: config,
                    startDate: sessionStartDate,
                    endDate: sessionEndDate,
                    onResume: {
                        if case .stopped = reason { resumeSession() }
                    },
                    onStartAgain: { restartSession() },
                    onBackToLibrary: {
                        let completed: Bool
                        if case .complete = reason { completed = true } else { completed = false }
                        modelContext.insert(SessionHistoryEntry(
                            config: config,
                            wasCompleted: completed,
                            elapsedSeconds: elapsed
                        ))
                        appState.endSession()
                    }
                )
                .zIndex(10)
            }

        }
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $showPostSessionPaywall) {
            // Dismissing lands on the session-done overlay (share, health, …).
            PaywallSheet(context: .sessionComplete)
        }
        .onAppear { setup() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { fireDate in
            guard !isPaused && endReason == nil && !showCountdown else { return }
            lastTickDate = fireDate   // use nominal fire time for accurate interpolation
            tick()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // iOS can deactivate the audio session at the moment the app backgrounds.
            // Re-activating it here ensures cues keep firing from the lock screen.
            if newPhase == .background {
                AudioSettings.shared.applyAudioSession()
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Corner indicators

    private var cornerIndicators: some View {
        VStack {
            HStack(alignment: .top, spacing: 16) {
                // Top-left: Round
                CornerCell(caption: "ROUND",
                           value: "\(currentRound + 1)/\(totalRounds)",
                           alignment: .leading)
                Spacer(minLength: 12)
                // Top-right: current phase (block) name, tinted with the block color
                CornerCell(caption: "PHASE",
                           value: currentBlock.label,
                           alignment: .trailing,
                           valueColor: blockColor)
            }
            .padding(.horizontal, 22)
            .padding(.top, 56)

            Spacer()

            HStack(alignment: .bottom, spacing: 16) {
                // Bottom-left: elapsed
                CornerCell(caption: "ELAPSED",
                           value: elapsedDisplay,
                           alignment: .leading)
                Spacer(minLength: 12)
                // Bottom-right: remaining
                CornerCell(caption: "REMAINING",
                           value: remainingDisplay,
                           alignment: .trailing)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 38) {
            // Stop
            Button {
                sessionEndDate = Date()
                endLiveActivity()
                SoundEngine.shared.stopKeepAlive()
                FlashlightEngine.shared.teardown()
                endReason = .stopped(elapsed: elapsed, total: totalSecs)
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.white.opacity(0.18))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop session")

            // Pause / Resume
            Button {
                if isPaused { lastTickDate = Date() }  // re-anchor interpolation on resume
                isPaused.toggle()
                updateLiveActivity()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPaused ? "Resume" : "Pause")

            // Skip phase (skip current block, move to next block)
            Button { skipBlock() } label: {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.white.opacity(0.18))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip phase")

            // Skip round (skip to start of next full round)
            Button { skipRound() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.white.opacity(0.18))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip round")
        }
        .padding(.bottom, 48)
    }

    // MARK: - Setup

    private func setup() {
        sessionStartDate = Date()
        lastTickDate = Date()
        // Preload every sound-file cue this session may play
        var cuesToPreload = Set(config.blocks.map(\.soundCue))
        config.blocks.forEach { if $0.midwayCue != .silent { cuesToPreload.insert($0.midwayCue) } }
        for cue in [config.openingCountdownCue, config.openingAnnouncementCue, config.closingAnnouncementCue] {
            if case .sound(let soundCue) = cue { cuesToPreload.insert(soundCue) }
        }
        if FeatureFlags.metronome && config.metronomeEnabled {
            cuesToPreload.insert(config.metronomeSoundCue)
        }
        SoundEngine.shared.preload(cues: cuesToPreload)
        // Activate playback session so audio + flashlight continue when backgrounded
        AudioSettings.shared.applyAudioSession()
        // Silent keepalive loop — holds the AVAudioSession open between cues so
        // iOS doesn't suspend background audio in the gaps between block sounds.
        SoundEngine.shared.startKeepAlive()
        // Cache the torch device NOW while foregrounded — lock screen burst() needs it
        FlashlightEngine.shared.prepare()
        // Start the lock-screen Live Activity
        startLiveActivity()

        if config.openingCountdownSecs > 0 {
            showCountdown = true
        } else {
            playAnnouncementCue(config.openingAnnouncementCue, isStart: true)
            // No opening cue — cues fire at the START of each block (see tick)
        }
    }

    // MARK: - Tick

    private func tick() {
        // Snapshot BEFORE increment so we can detect block transitions
        let preIndex = currentBlockIndex

        elapsed += 1

        // Session complete
        if elapsed >= totalSecs {
            endSession()
            return
        }

        let postIndex  = currentBlockIndex
        let postBlock  = currentBlock
        let isNewBlock = postIndex != preIndex
        let isNewRound = secInRound == 0

        // Fire ALL cues at the START of each block:
        //   • elapsed == 1  → only if no opening countdown (otherwise fired in onFinish)
        //   • isNewBlock    → a new block just became active
        let hasCountdown = config.openingCountdownSecs > 0
        if (elapsed == 1 && !hasCountdown) || isNewBlock {
            fireCues(for: postBlock)
        }

        // Mid-block halfway cue — fires once at the exact midpoint of the block
        let half = postBlock.durationSeconds / 2
        if postBlock.midwayCue != .silent && secInBlock == half && !isNewBlock {
            SoundEngine.shared.play(postBlock.midwayCue)
        }

        if voiceOverEnabled && (isNewBlock || isNewRound) {
            AccessibilityNotification.Announcement("\(postBlock.label), \(blockLeft) seconds").post()
        }

        // Phase prep signal: beep once per second during the last N secs of each block.
        // Skip the last block of every round when round prep is also active (avoids double-beeping),
        // and skip the very last block of the session.
        if config.phasePrepEnabled && config.phasePrepSecs > 0 {
            let secsLeftInBlock = currentBlock.durationSeconds - secInBlock
            let isLastBlock = currentBlockIndex == config.blocks.count - 1
            let isLastRound = currentRound >= totalRounds - 1
            let isLastBlockOfSession = isLastBlock && isLastRound
            let suppressedByRoundPrep = isLastBlock && config.roundPrepEnabled
            if !isLastBlockOfSession && !suppressedByRoundPrep && secsLeftInBlock > 0 && secsLeftInBlock <= config.phasePrepSecs {
                BeepPlayer.shared.play()
            }
        }

        // Round prep signal: beep once per second during the last N secs of each round
        // (not the last round, since there's no next round to prep for).
        if config.roundPrepEnabled && config.roundPrepSecs > 0 {
            let secsLeftInRound = roundSecs - secInRound
            let isLastRound = currentRound >= totalRounds - 1
            if !isLastRound && secsLeftInRound > 0 && secsLeftInRound <= config.roundPrepSecs {
                BeepPlayer.shared.play()
            }
        }

        // Metronome: fire at a fixed cadence, independent of rounds and phases.
        if FeatureFlags.metronome && config.metronomeEnabled {
            let interval = max(1, config.metronomeIntervalSeconds)
            if elapsed % interval == 0 {
                SoundEngine.shared.play(config.metronomeSoundCue)
                HapticEngine.shared.fire(config.metronomeHapticCue)
            }
        }

        // Update lock-screen Live Activity every second for real-time display.
        updateLiveActivity()
    }

    // MARK: - Cues

    private func fireCues(for block: BlockConfig) {
        if let gender = block.soundCue.voiceLabelGender {
            VoiceEngine.shared.speakLabel(block.label, gender: gender)
        } else {
            SoundEngine.shared.play(block.soundCue)
        }
        HapticEngine.shared.fire(block.hapticCue)
        switch block.visualFlash {
        case .blockColor:
            fireFlash(color: block.color.color)
        case .flashlight, .flashlightDouble, .flashlightLong:
            FlashlightEngine.shared.fire(block.visualFlash)
        case .none:
            break
        }
    }

    private func fireFlash(color: Color) {
        guard !reduceMotion else { return }
        withAnimation(.easeIn(duration: 0.08)) { flashOpacity = 0.18 }
        withAnimation(.easeOut(duration: 0.3).delay(0.08)) { flashOpacity = 0 }
    }

    // MARK: - Live ring fractions (driven by TimelineView, no animation needed)
    //
    // `t` = seconds elapsed since the last 1 Hz tick (0.0 … 1.0).
    // Each function linearly interpolates the ring from its value at the tick
    // to where it will be 1 second later, giving perfectly smooth motion.

    private func liveBlockFraction(_ t: Double) -> CGFloat {
        let dur = currentBlock.durationSeconds
        guard dur > 0 else { return 0 }
        return max(0, CGFloat(blockLeft) / CGFloat(dur) - CGFloat(t) / CGFloat(dur))
    }

    private func liveRoundFraction(_ t: Double) -> CGFloat {
        guard roundSecs > 0 else { return 0 }
        return max(0, CGFloat(roundSecs - secInRound) / CGFloat(roundSecs)
                      - CGFloat(t) / CGFloat(roundSecs))
    }

    private func liveSessionFraction(_ t: Double) -> CGFloat {
        guard totalSecs > 0 else { return 0 }
        return max(0, CGFloat(totalSecs - elapsed) / CGFloat(totalSecs)
                      - CGFloat(t) / CGFloat(totalSecs))
    }

    // MARK: - Skip phase / round

    /// Skips to the start of the next block within the current round.
    /// If the current block is the last one in the round, advances to the next round.
    private func skipBlock() {
        let roundBase = currentRound * roundSecs
        var acc = 0
        for block in config.blocks {
            acc += block.durationSeconds
            if secInRound < acc {
                let nextStart = roundBase + acc
                if nextStart >= totalSecs {
                    endSession()
                } else {
                    elapsed = nextStart
                    lastTickDate = Date()
                    fireCues(for: currentBlock)
                }
                return
            }
        }
    }

    /// Skips to the start of the next full round (back to the first block).
    private func skipRound() {
        let nextRoundStart = (currentRound + 1) * roundSecs
        if nextRoundStart >= totalSecs {
            endSession()
        } else {
            elapsed = nextRoundStart
            lastTickDate = Date()
            fireCues(for: currentBlock)
        }
    }

    // MARK: - Session end

    private func endSession() {
        sessionEndDate = Date()   // capture actual wall-clock finish time
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            playAnnouncementCue(config.closingAnnouncementCue, isStart: false)
        }
        endLiveActivity()
        SoundEngine.shared.stopKeepAlive()
        FlashlightEngine.shared.teardown()
        // Mark this unit complete so the protocol view shows a green checkmark.
        // Only fires on natural completion (not when the stop button is used).
        appState.markUnitCompleted(config.id)
        endReason = .complete
        // Primary day-0 paywall placement: the first completed session leads
        // straight into the paywall (once ever, never for Pro users). Delayed
        // slightly so the closing cue lands before the transition.
        if !hasSeenPostSessionPaywall && !StoreManager.shared.isPro {
            hasSeenPostSessionPaywall = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showPostSessionPaywall = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if ReviewManager.shared.recordCompletedSession() {
                // Native StoreKit rating dialog — the system decides whether to
                // actually display it (max 3 times per year, never after rating).
                requestReview()
            }
        }
    }

    private func restartSession() {
        sessionStartDate = Date()
        elapsed = 0
        lastTickDate = Date()
        isPaused = false
        endReason = nil
        flashOpacity = 0
        SoundEngine.shared.startKeepAlive()
        FlashlightEngine.shared.prepare()   // re-acquire torch lock (released on stop/end)

        if config.openingCountdownSecs > 0 {
            showCountdown = true
        } else {
            playAnnouncementCue(config.openingAnnouncementCue, isStart: true)
            // No opening cue — cues fire at end of each block (see tick)
        }
    }

    /// Resumes a stopped session from exactly where it left off.
    private func resumeSession() {
        lastTickDate = Date()
        isPaused = false
        endReason = nil
        flashOpacity = 0
        SoundEngine.shared.startKeepAlive()
        FlashlightEngine.shared.prepare()   // re-acquire torch lock (released on stop)
        startLiveActivity()
    }

    // MARK: - Live Activity (lock screen progress)

    private func liveActivityState() -> CadenceActivityAttributes.ContentState {
        CadenceActivityAttributes.ContentState(
            blockLabel:    currentBlock.label,
            blockLeft:     blockLeft,
            roundLabel:    "\(currentRound + 1) / \(totalRounds)",
            totalLeft:     max(0, totalSecs - elapsed),
            blockColorHex: currentBlock.color.hexString,
            isPaused:      isPaused
        )
    }

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attrs   = CadenceActivityAttributes(timerName: config.name)
        let state   = liveActivityState()
        let content = ActivityContent(state: state, staleDate: nil)
        liveActivity = try? Activity.request(attributes: attrs, content: content)
    }

    private func updateLiveActivity() {
        guard let activity = liveActivity else { return }
        // staleDate = 1.5 s from now tells the system a fresh update is coming soon,
        // so it doesn't dim/grey the lock-screen widget between ticks.
        let content = ActivityContent(state: liveActivityState(),
                                      staleDate: isPaused ? nil : .now + 1.5)
        Task { await activity.update(content) }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        let content = ActivityContent(state: liveActivityState(), staleDate: nil)
        Task { await activity.end(content, dismissalPolicy: .after(.now + 4)) }
        liveActivity = nil
    }

    private func playAnnouncementCue(_ cue: AnnouncementCue, isStart: Bool) {
        switch cue {
        case .none: break
        case .voice(let gender):
            VoiceEngine.shared.play(isStart ? .start(gender) : .finish(gender))
        case .sound(let soundCue):
            SoundEngine.shared.play(soundCue)
        }
    }
}

// MARK: - Corner indicator cell

/// Caption + large value, readable from across the room.
private struct CornerCell: View {
    let caption: LocalizedStringKey
    let value: String
    let alignment: HorizontalAlignment
    var valueColor: Color = Color(hex: "E8E8F0")

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(caption)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.white.opacity(0.40))
            Text(value)
                .font(.system(size: 26, weight: .medium, design: .monospaced))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
        }
        .frame(maxWidth: 170, alignment: alignment == .leading ? .leading : .trailing)
        .animation(.easeInOut(duration: 0.25), value: value)
    }
}
