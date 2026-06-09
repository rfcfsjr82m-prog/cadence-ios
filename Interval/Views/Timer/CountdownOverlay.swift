import SwiftUI
import AVFoundation

struct CountdownOverlay: View {
    let seconds: Int
    var label: String = "Get Ready"     // big heading shown above the number
    var soundEnabled: Bool = true
    let onFinish: () -> Void
    var onStart: (() -> Void)? = nil   // fires immediately when the countdown begins
    var onDismiss: (() -> Void)? = nil  // called when user taps the X to cancel
    var onVoice: (() -> Void)? = nil   // fires 1 s before onFinish so voice has a head-start

    @State private var displayCount: Int = 0
    @State private var opacity: Double = 0
    @State private var beepPlayer: AVAudioPlayer? = nil
    @State private var dismissed = false

    var body: some View {
        ZStack {
            Color(hex: "080809").ignoresSafeArea()

            VStack(spacing: 16) {
                Text(LocalizedStringKey(label))
                    .font(.system(size: 36, weight: .bold, design: .default))
                    .foregroundStyle(Color.timerIndicator)
                    .tracking(2)
                    .multilineTextAlignment(.center)
                    .textCase(.uppercase)

                Text("\(displayCount)")
                    .font(.system(size: 100, design: .monospaced).weight(.thin))
                    .foregroundStyle(Color.timerIndicator)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: displayCount)

                Text("STARTING IN")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.timerIndicator.opacity(0.45))
                    .tracking(2)
            }
            .opacity(opacity)

            VStack {
                // X dismiss — top-left
                HStack {
                    Button {
                        dismissed = true
                        withAnimation(.easeOut(duration: 0.2)) { opacity = 0 }
                        onDismiss?()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(hex: "C2C2CE"))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 12)
                    .padding(.top, 56)
                    Spacer()
                }
                Spacer()
                // Skip button — bottom centre
                Button {
                    dismissed = true
                    withAnimation(.easeOut(duration: 0.2)) { opacity = 0 }
                    onFinish()
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(hex: "C2C2CE"))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 52)
            }
        }
        .onAppear { start() }
    }

    private func start() {
        prepareBeep()
        displayCount = seconds
        withAnimation(.easeIn(duration: 0.3)) { opacity = 1 }
        onStart?()
        tick()
    }

    private func tick() {
        guard displayCount > 0, !dismissed else { return }
        if displayCount <= 5 {
            playBeep()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard !dismissed else { return }
            withAnimation { displayCount -= 1 }
            switch displayCount {
            case 1:
                // Fire voice 1 s early so it has a head-start before the session begins
                onVoice?()
                tick()
            case 0:
                // Fade-out runs in parallel, not as a blocker
                withAnimation(.easeOut(duration: 0.3)) { opacity = 0 }
                onFinish()
            default:
                tick()
            }
        }
    }

    // Soft 660 Hz beep synthesised via AVAudioPlayer PCM buffer
    private func prepareBeep() {
        let sampleRate: Double = 44100
        let duration: Double = 0.22
        let freq: Double = 660
        let frameCount = Int(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let data = buffer.floatChannelData![0]
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let envelope = max(0, 1 - t / duration)
            data[i] = Float(sin(2 * Double.pi * freq * t) * 0.25 * envelope)
        }
        // Write to temp file so AVAudioPlayer can read it
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("countdown_beep.wav")
        if let file = try? AVAudioFile(forWriting: url, settings: format.settings) {
            try? file.write(from: buffer)
        }
        beepPlayer = try? AVAudioPlayer(contentsOf: url)
        beepPlayer?.prepareToPlay()
    }

    private func playBeep() {
        guard soundEnabled else { return }
        beepPlayer?.currentTime = 0
        beepPlayer?.play()
    }
}
