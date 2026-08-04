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

    // `elapsed` is the displayed second count. It is not free-running: every
    // tick it is recomputed from wall-clock (`anchorDate` + `elapsedAtAnchor`),
    // so the timer stays correct across background suspension instead of
    // freezing whenever the run-loop timer stops firing.
    @State private var elapsed: Int = 0
    @State private var anchorDate: Date = Date()      // wall-clock at `elapsedAtAnchor`
    @State private var elapsedAtAnchor: Int = 0       // elapsed seconds captured at `anchorDate`
    @State private var lastPushedBlockKey: Int = -1   // dedupes Live Activity block pushes
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
                        reanchor(to: 0)         // real session clock starts now
                        startLiveActivity()
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
            switch newPhase {
            case .background:
                // iOS can deactivate the audio session at the moment the app
                // backgrounds. Re-activating it here keeps cues firing from the
                // lock screen for as long as the system lets us run.
                AudioSettings.shared.applyAudioSession()
            case .active:
                // Coming back to the foreground: recompute from wall-clock right
                // away so the UI jumps to the true elapsed time (rather than
                // waiting up to a second for the next tick) and catches any
                // time that passed while we were suspended.
                if !isPaused && endReason == nil && !showCountdown {
                    tick()
                }
            default:
                break
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
                ActiveSessionStore.clear()
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
                if isPaused {
                    // Resume: restart the wall-clock anchor from the current second.
                    isPaused = false
                    elapsedAtAnchor = elapsed
                    anchorDate = Date()
                    lastTickDate = Date()
                } else {
                    // Pause: freeze elapsed at the current second.
                    isPaused = true
                    elapsedAtAnchor = elapsed
                }
                persistSnapshot()
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

        // Restoring a session that outlived the app? Rebuild timing from the
        // persisted wall-clock anchor rather than starting from zero.
        if let snap = appState.pendingRestore, snap.config.id == config.id {
            appState.pendingRestore = nil
            anchorDate = snap.anchorDate
            elapsedAtAnchor = snap.elapsedAtAnchor
            isPaused = snap.isPaused
            elapsed = wallClockElapsed()
            sessionStartDate = snap.anchorDate.addingTimeInterval(-Double(snap.elapsedAtAnchor))
            lastTickDate = Date()
            startLiveActivity()
            // Finished while we were away — go straight to the done screen.
            if elapsed >= totalSecs {
                endSession()
            }
            return
        }

        // Fresh session.
        sessionStartDate = Date()

        if config.openingCountdownSecs > 0 {
            showCountdown = true
            // The wall-clock anchor, Live Activity and persistence all begin when
            // the countdown finishes — that's when the real session clock starts.
        } else {
            reanchor(to: 0)
            startLiveActivity()
            playAnnouncementCue(config.openingAnnouncementCue, isStart: true)
            // No opening cue — cues fire at the START of each block (see tick)
        }
    }

    // MARK: - Wall-clock anchoring

    /// The true elapsed time derived from wall-clock. Immune to the run-loop
    /// timer stalling in the background.
    private func wallClockElapsed() -> Int {
        if isPaused { return elapsedAtAnchor }
        return elapsedAtAnchor + max(0, Int(Date().timeIntervalSince(anchorDate)))
    }

    /// Re-pins the wall-clock anchor to a specific elapsed value (session start,
    /// resume, skip, restart) and persists it so the session can be restored.
    private func reanchor(to newElapsed: Int) {
        elapsed = newElapsed
        elapsedAtAnchor = newElapsed
        anchorDate = Date()
        lastTickDate = Date()
        persistSnapshot()
    }

    /// Writes the running session to disk so it survives suspension/termination.
    private func persistSnapshot() {
        ActiveSessionStore.save(ActiveSessionSnapshot(
            config: config,
            anchorDate: anchorDate,
            elapsedAtAnchor: elapsedAtAnchor,
            isPaused: isPaused
        ))
    }

    // MARK: - Tick

    /// Advances `elapsed` to match wall-clock, then fires the appropriate cues.
    private func tick() {
        let target = wallClockElapsed()
        guard target > elapsed else { return }   // sub-second; rings interpolate via TimelineView

        let delta = target - elapsed
        if delta <= 2 {
            // Normal foreground / background-audio path: step second-by-second so
            // no per-second cue (block start, halfway, prep beeps) is missed.
            for _ in 0..<delta {
                if stepOneSecond() { return }   // session ended
            }
        } else {
            // Large jump — we were suspended and just resumed. Resync to the true
            // time without replaying the flood of cues we slept through.
            resyncAfterBackground(to: target)
            if endReason != nil { return }
        }

        pushLiveActivityIfBlockChanged()
    }

    /// Jumps straight to `target` after a suspension, firing at most one cue to
    /// re-orient the user to the block they woke up in.
    private func resyncAfterBackground(to target: Int) {
        let preIndex = currentBlockIndex
        let preRound = currentRound
        elapsed = min(target, totalSecs)
        lastTickDate = Date()
        if elapsed >= totalSecs {
            endSession()
            return
        }
        if currentBlockIndex != preIndex || currentRound != preRound {
            fireCues(for: currentBlock)
        }
    }

    /// Pushes a Live Activity update only when the block/round changes. The
    /// lock-screen countdown runs natively between pushes, so per-second updates
    /// are unnecessary (and would be throttled by the system anyway).
    private func pushLiveActivityIfBlockChanged() {
        let key = currentRound * max(1, config.blocks.count) + currentBlockIndex
        guard key != lastPushedBlockKey else { return }
        lastPushedBlockKey = key
        updateLiveActivity()
    }

    /// Advances exactly one second and fires that second's cues.
    /// Returns `true` if the session ended.
    private func stepOneSecond() -> Bool {
        // Snapshot BEFORE increment so we can detect block transitions
        let preIndex = currentBlockIndex

        elapsed += 1

        // Session complete
        if elapsed >= totalSecs {
            endSession()
            return true
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

        return false
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
                    reanchor(to: nextStart)
                    fireCues(for: currentBlock)
                    updateLiveActivity()
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
            reanchor(to: nextRoundStart)
            fireCues(for: currentBlock)
            updateLiveActivity()
        }
    }

    // MARK: - Session end

    private func endSession() {
        sessionEndDate = Date()   // capture actual wall-clock finish time
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            playAnnouncementCue(config.closingAnnouncementCue, isStart: false)
        }
        endLiveActivity()
        ActiveSessionStore.clear()
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
        isPaused = false
        endReason = nil
        flashOpacity = 0
        lastPushedBlockKey = -1
        SoundEngine.shared.startKeepAlive()
        FlashlightEngine.shared.prepare()   // re-acquire torch lock (released on stop/end)

        if config.openingCountdownSecs > 0 {
            elapsed = 0
            showCountdown = true
            // anchor + Live Activity begin when the countdown finishes
        } else {
            reanchor(to: 0)
            startLiveActivity()
            playAnnouncementCue(config.openingAnnouncementCue, isStart: true)
            // No opening cue — cues fire at end of each block (see tick)
        }
    }

    /// Resumes a stopped session from exactly where it left off.
    private func resumeSession() {
        isPaused = false
        endReason = nil
        flashOpacity = 0
        lastPushedBlockKey = -1
        reanchor(to: elapsed)   // continue wall-clock from the stopped second
        SoundEngine.shared.startKeepAlive()
        FlashlightEngine.shared.prepare()   // re-acquire torch lock (released on stop)
        startLiveActivity()
    }

    // MARK: - Live Activity (lock screen progress)

    private func liveActivityState() -> CadenceActivityAttributes.ContentState {
        // Absolute dates are derived from the wall-clock anchor, not `Date()`, so
        // they stay identical across every push within a block/session. That makes
        // the native lock-screen countdown perfectly stable (no jitter at
        // boundaries) and — crucially — correct for the whole session from a
        // single push, so it can never freeze even if the app is suspended.
        let blockEndElapsed  = elapsed + max(0, blockLeft)
        let blockEndDate     = anchorDate.addingTimeInterval(Double(blockEndElapsed - elapsedAtAnchor))
        let blockStartDate   = blockEndDate.addingTimeInterval(-Double(max(1, currentBlock.durationSeconds)))
        let sessionStartDate = anchorDate.addingTimeInterval(-Double(elapsedAtAnchor))
        let sessionEndDate   = anchorDate.addingTimeInterval(Double(totalSecs - elapsedAtAnchor))
        return CadenceActivityAttributes.ContentState(
            blockLabel:       currentBlock.label,
            roundLabel:       "\(currentRound + 1) / \(totalRounds)",
            blockColorHex:    currentBlock.color.hexString,
            isPaused:         isPaused,
            blockStartDate:   blockStartDate,
            blockEndDate:     blockEndDate,
            sessionStartDate: sessionStartDate,
            sessionEndDate:   sessionEndDate,
            blockLeftAtPause: max(0, blockLeft),
            totalLeftAtPause: max(0, totalSecs - elapsed)
        )
    }

    /// Absolute wall-clock instant the whole session ends. Used as the Live
    /// Activity `staleDate` so a lingering activity (e.g. one that outlived a
    /// force-quit) stops looking live once its time is up.
    private var sessionEndAbsolute: Date {
        anchorDate.addingTimeInterval(Double(totalSecs - elapsedAtAnchor))
    }

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // If one is already running (e.g. resumed session), don't stack a second.
        guard liveActivity == nil else { updateLiveActivity(); return }
        // End any Activity left over from a previous run before starting a fresh
        // one, so lock-screen timers can never stack up across launches.
        for old in Activity<CadenceActivityAttributes>.activities {
            Task { await old.end(nil, dismissalPolicy: .immediate) }
        }
        let attrs   = CadenceActivityAttributes(timerName: config.name)
        let content = ActivityContent(state: liveActivityState(), staleDate: sessionEndAbsolute)
        liveActivity = try? Activity.request(attributes: attrs, content: content)
        lastPushedBlockKey = currentRound * max(1, config.blocks.count) + currentBlockIndex
    }

    private func updateLiveActivity() {
        guard let activity = liveActivity else { return }
        // `staleDate` is the session end: the native `Text(timerInterval:)`
        // countdown stays live between pushes, and iOS marks the activity stale
        // once the session's time is up so a leftover one doesn't look active.
        let content = ActivityContent(state: liveActivityState(), staleDate: sessionEndAbsolute)
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
