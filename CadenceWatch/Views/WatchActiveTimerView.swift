import SwiftUI
import WatchKit

struct WatchActiveTimerView: View {
    let config: TimerConfig

    @State private var engine: WatchTimerEngine? = nil
    @State private var openingSecsLeft: Int = 0
    @State private var openingTimer: Timer? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let engine {
                if engine.isFinished {
                    doneView
                } else {
                    runningView(engine)
                }
            } else if openingSecsLeft > 0 {
                countdownView
            } else {
                readyView
            }
        }
        .navigationBarBackButtonHidden(engine != nil && !(engine?.isFinished ?? true))
        .onDisappear {
            openingTimer?.invalidate()
            engine?.stop()
        }
    }

    // MARK: - Ready

    private var readyView: some View {
        VStack(spacing: 8) {
            Text(config.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(String(format: NSLocalizedString("%dm · %d rounds", comment: ""), config.totalDurationMinutes, config.totalRounds))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button("Start") { beginOpening() }
                .buttonStyle(.borderedProminent)
                .tint(.accent)
        }
        .padding()
    }

    // MARK: - Opening countdown

    private var countdownView: some View {
        VStack(spacing: 8) {
            Text(config.openingCountdownLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("\(openingSecsLeft)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.3), value: openingSecsLeft)
            Button("Skip") { skipCountdown() }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
        }
    }

    // MARK: - Running

    private func runningView(_ e: WatchTimerEngine) -> some View {
        TimelineView(.animation) { tl in
            let progress  = e.smoothBlockProgress(at: tl.date)
            let blockLeft = e.blockLeft(at: tl.date)
            let block     = e.currentBlock

            VStack(spacing: 8) {
                // Block label
                Text(block.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                // Ring with countdown
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(block.color.color,
                                style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(TimeFormatter.elapsed(blockLeft))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .frame(width: 88, height: 88)

                // Round indicator
                Text(String(format: NSLocalizedString("Round %d / %d", comment: ""), e.currentRound + 1, e.totalRounds))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                // Buttons
                HStack(spacing: 6) {
                    circleButton(icon: e.isPaused ? "play.fill" : "pause.fill") {
                        e.togglePause()
                        WKInterfaceDevice.current().play(.click)
                    }
                    circleButton(icon: "forward.end.fill") {
                        e.skipToNextBlock()
                        WKInterfaceDevice.current().play(.click)
                    }
                    circleButton(icon: "forward.end.alt.fill") {
                        e.skipToNextRound()
                        WKInterfaceDevice.current().play(.click)
                    }
                    circleButton(icon: "xmark", tint: .red) {
                        e.stop(); dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("Done!")
                .font(.headline)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.green)
        }
        .onAppear {
            if let e = engine {
                WatchConnectivityManager.shared.reportCompletion(
                    config: e.config,
                    elapsedSeconds: e.elapsed,
                    wasCompleted: true
                )
            }
        }
    }

    // MARK: - Helpers

    private func skipCountdown() {
        openingTimer?.invalidate()
        openingTimer = nil
        openingSecsLeft = 0
        startEngine()
    }

    private func beginOpening() {
        let secs = config.openingCountdownSecs
        guard secs > 0 else { startEngine(); return }
        openingSecsLeft = secs
        WKInterfaceDevice.current().play(.click)
        openingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                openingSecsLeft -= 1
                if openingSecsLeft <= 0 {
                    openingTimer?.invalidate()
                    openingTimer = nil
                    startEngine()
                }
            }
        }
    }

    private func startEngine() {
        let e = WatchTimerEngine(config: config)
        engine = e
        e.start()
        WKInterfaceDevice.current().play(.click)
    }

    @ViewBuilder
    private func circleButton(icon: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

