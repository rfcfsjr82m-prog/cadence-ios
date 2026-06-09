import SwiftUI
import WatchKit

@MainActor
@Observable
final class WatchTimerEngine {
    private(set) var elapsed: Int = 0
    private(set) var isPaused: Bool = false
    private(set) var isFinished: Bool = false

    let config: TimerConfig
    private let soundEngine = WatchSoundEngine()

    // Wall-clock tracking — elapsed is always derived from real time,
    // so throttled ticks never cause the timer to fall behind.
    // Exposed so the view can compute fractional progress at display refresh rate.
    private(set) var startDate: Date = Date()
    private(set) var accumulatedPause: TimeInterval = 0
    private var pausedAt: Date? = nil

    private var timer: Timer?
    private var runtimeSession: WKExtendedRuntimeSession?

    init(config: TimerConfig) {
        self.config = config
    }

    // MARK: - Derived state

    var totalSecs: Int  { max(1, config.totalDurationSeconds) }
    var roundSecs:  Int { max(1, config.roundDurationSeconds) }
    var totalRounds: Int { config.totalRounds }

    var currentRound: Int { elapsed / roundSecs }
    var secInRound:   Int { elapsed % roundSecs }

    var currentBlockIndex: Int {
        var acc = 0
        for (i, block) in config.blocks.enumerated() {
            acc += block.durationSeconds
            if secInRound < acc { return i }
        }
        return max(0, config.blocks.count - 1)
    }

    var currentBlock: BlockConfig {
        guard !config.blocks.isEmpty else { return BlockConfig() }
        return config.blocks[currentBlockIndex]
    }

    var secInBlock: Int {
        var acc = 0
        for block in config.blocks {
            let next = acc + block.durationSeconds
            if secInRound < next { return secInRound - acc }
            acc = next
        }
        return 0
    }

    var blockLeft:     Int    { currentBlock.durationSeconds - secInBlock }
    var blockProgress: Double { Double(secInBlock) / Double(max(1, currentBlock.durationSeconds)) }

    /// Remaining seconds in the current block, computed from a live Date.
    func blockLeft(at date: Date) -> Int {
        guard !isFinished else { return 0 }
        let fracElapsed = isPaused
            ? Double(elapsed)
            : date.timeIntervalSince(startDate) - accumulatedPause
        let fracInRound = fracElapsed.truncatingRemainder(dividingBy: Double(max(1, roundSecs)))
        var acc: Double = 0
        for block in config.blocks {
            let next = acc + Double(block.durationSeconds)
            if fracInRound < next {
                return max(0, Int(ceil(next - fracInRound)))
            }
            acc = next
        }
        return 0
    }

    /// Smooth fractional block progress computed from a live Date — call from TimelineView(.animation).
    func smoothBlockProgress(at date: Date) -> Double {
        guard !isFinished else { return 1 }
        let fracElapsed = isPaused
            ? Double(elapsed)
            : date.timeIntervalSince(startDate) - accumulatedPause
        let fracInRound = fracElapsed.truncatingRemainder(dividingBy: Double(max(1, roundSecs)))
        var acc: Double = 0
        for block in config.blocks {
            let next = acc + Double(block.durationSeconds)
            if fracInRound < next {
                return (fracInRound - acc) / Double(block.durationSeconds)
            }
            acc = next
        }
        return 1
    }

    // MARK: - Control

    func start() {
        startDate = Date()
        accumulatedPause = 0
        beginExtendedSession()
        scheduleTimer()
    }

    func togglePause() {
        if isPaused {
            // Resume: add the paused duration to accumulated pause
            if let p = pausedAt {
                accumulatedPause += Date().timeIntervalSince(p)
            }
            pausedAt = nil
            isPaused = false
            scheduleTimer()
        } else {
            pausedAt = Date()
            isPaused = true
            invalidateTimer()
        }
    }

    func skipToNextBlock() {
        let sInRound = elapsed % max(1, roundSecs)
        var acc = 0
        for block in config.blocks {
            acc += block.durationSeconds
            if sInRound < acc {
                let targetElapsed = (elapsed / roundSecs) * roundSecs + acc
                jumpTo(min(targetElapsed, totalSecs - 1))
                return
            }
        }
        skipToNextRound()
    }

    func skipToNextRound() {
        let nextRoundStart = (currentRound + 1) * roundSecs
        if nextRoundStart >= totalSecs {
            elapsed = totalSecs
            isFinished = true
            stop()
            WKInterfaceDevice.current().play(.success)
        } else {
            jumpTo(nextRoundStart)
        }
    }

    func stop() {
        invalidateTimer()
        runtimeSession?.invalidate()
        runtimeSession = nil
    }

    // MARK: - Private

    private func jumpTo(_ targetElapsed: Int) {
        let now = Date()
        accumulatedPause = now.timeIntervalSince(startDate) - Double(targetElapsed)
        elapsed = targetElapsed
        let newBlock = blockIndexAt(targetElapsed)
        if newBlock < config.blocks.count {
            soundEngine.play(config.blocks[newBlock].soundCue)
            playHaptic(for: config.blocks[newBlock].hapticCue)
        }
    }

    private func scheduleTimer() {
        // Fire frequently so block transitions are detected promptly.
        // Display updates are driven by TimelineView, not this timer.
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !isPaused, !isFinished else { return }

        let realElapsed = Date().timeIntervalSince(startDate) - accumulatedPause
        let newElapsed = Int(realElapsed)

        if newElapsed >= totalSecs {
            let prev = elapsed
            elapsed = totalSecs
            isFinished = true
            stop()
            WKInterfaceDevice.current().play(.success)
            _ = prev
            return
        }

        let prevBlock = blockIndexAt(elapsed)
        elapsed = newElapsed
        let newBlock = blockIndexAt(elapsed)

        if newBlock != prevBlock, newBlock < config.blocks.count {
            let block = config.blocks[newBlock]
            soundEngine.play(block.soundCue)
            playHaptic(for: block.hapticCue)
        }
    }

    private func blockIndexAt(_ e: Int) -> Int {
        let sInRound = e % max(1, roundSecs)
        var acc = 0
        for (i, block) in config.blocks.enumerated() {
            acc += block.durationSeconds
            if sInRound < acc { return i }
        }
        return max(0, config.blocks.count - 1)
    }

    private func playHaptic(for cue: HapticCue) {
        switch cue {
        // .click and .directionUp/.directionDown are haptic-only — no audible system sound.
        // .notification and .start produce audible pings on the watch, so we avoid them.
        case .softPulse: WKInterfaceDevice.current().play(.click)
        case .doubleTap: WKInterfaceDevice.current().play(.click)
        case .longBuzz:  WKInterfaceDevice.current().play(.click)
        case .off:       break
        }
    }

    private func beginExtendedSession() {
        let session = WKExtendedRuntimeSession()
        session.start()
        runtimeSession = session
    }
}
