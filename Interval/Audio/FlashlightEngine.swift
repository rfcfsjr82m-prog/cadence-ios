@preconcurrency import AVFoundation

// MARK: - FlashlightEngine
//
// Fires a short torch burst — ideal for night use or closed-eye meditation.
//
// Lock-screen reliability strategy:
//   iOS prevents re-acquiring lockForConfiguration() from a backgrounded app.
//   To work around this, prepare() acquires the configuration lock once while
//   the app is foregrounded and holds it for the whole session. burst() then
//   sets torch mode directly without needing to lock again — this path works
//   reliably from the lock screen.
//
//   teardown() must be called when the session ends to release the lock and
//   device. prepare() must be called again before the next session.

final class FlashlightEngine: @unchecked Sendable {
    static let shared = FlashlightEngine()
    private init() {}

    private let onDuration: Double   = 0.18   // single burst
    private let doubleGap: Double    = 0.15   // pause between double bursts
    private let longDuration: Double = 1.0    // long burst

    nonisolated(unsafe) private var device: AVCaptureDevice? = nil
    /// True while we hold the AVCaptureDevice configuration lock.
    nonisolated(unsafe) private var configLocked = false
    nonisolated(unsafe) private var pendingWork: [DispatchWorkItem] = []

    /// (delay from now, torch-on duration) steps for each flash style.
    private func pattern(for style: VisualFlash) -> [(delay: Double, duration: Double)] {
        switch style {
        case .flashlight:       return [(0, onDuration)]
        case .flashlightDouble: return [(0, onDuration), (onDuration + doubleGap, onDuration)]
        case .flashlightLong:   return [(0, longDuration)]
        case .blockColor, .none: return []
        }
    }

    // MARK: - Prepare

    /// Call while foregrounded (ActiveTimerView.setup / restartSession / resumeSession).
    /// Acquires the torch device and holds the configuration lock so burst() works
    /// from the lock screen without needing to re-acquire the lock each time.
    func prepare() {
        guard device == nil else { return }   // already prepared for this session
        guard let dev = bestTorchDevice(), dev.hasTorch else { return }
        device = dev
        if (try? dev.lockForConfiguration()) != nil {
            dev.torchMode = .off              // start with torch off
            configLocked = true
        }
    }

    // MARK: - Teardown

    /// Call when the session ends (stop, natural complete, countdown dismiss).
    /// Turns off the torch, releases the configuration lock, and forgets the device.
    func teardown() {
        pendingWork.forEach { $0.cancel() }
        pendingWork = []
        if let dev = device {
            if configLocked {
                dev.torchMode = .off
                dev.unlockForConfiguration()
            }
        }
        configLocked = false
        device = nil
    }

    // MARK: - Preview (one-shot, no prepare needed)

    /// Fire a flash pattern without requiring a prior prepare() call.
    /// Used for in-app previews (e.g. BlockEditorSheet).
    func preview(_ style: VisualFlash = .flashlight) {
        if device != nil { fire(style); return }   // session running — use its lock
        guard let dev = bestTorchDevice(), dev.hasTorch else { return }
        schedule(pattern(for: style), on: dev, holdingLock: false)
    }

    // MARK: - Fire

    /// Fires the torch pattern for the given flash style during a session.
    func fire(_ style: VisualFlash) {
        guard let dev = device, dev.hasTorch else { return }
        // configLocked fast path sets torch mode directly using the held lock —
        // the only path that works reliably from the lock screen. Otherwise each
        // on/off operation briefly takes its own lock (foreground fallback).
        schedule(pattern(for: style), on: dev, holdingLock: configLocked)
    }

    /// Runs a torch on/off pattern on the main queue, which stays alive while
    /// the audio background mode is active. Cancels any pattern still in flight.
    private func schedule(_ steps: [(delay: Double, duration: Double)],
                          on dev: AVCaptureDevice,
                          holdingLock: Bool) {
        pendingWork.forEach { $0.cancel() }
        pendingWork = []

        nonisolated(unsafe) let capturedDev = dev

        func setTorch(_ enabled: Bool) {
            if holdingLock {
                if enabled { _ = try? capturedDev.setTorchModeOn(level: 1.0) }
                else       { capturedDev.torchMode = .off }
            } else {
                guard (try? capturedDev.lockForConfiguration()) != nil else { return }
                defer { capturedDev.unlockForConfiguration() }
                if enabled { _ = try? capturedDev.setTorchModeOn(level: 1.0) }
                else       { capturedDev.torchMode = .off }
            }
        }

        for step in steps {
            let onItem  = DispatchWorkItem { setTorch(true) }
            let offItem = DispatchWorkItem { setTorch(false) }
            if step.delay <= 0 {
                onItem.perform()
            } else {
                pendingWork.append(onItem)
                DispatchQueue.main.asyncAfter(deadline: .now() + step.delay, execute: onItem)
            }
            pendingWork.append(offItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay + step.duration,
                                          execute: offItem)
        }
    }

    // MARK: - Private

    private func bestTorchDevice() -> AVCaptureDevice? {
        if let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: nil, position: .back),
           dev.hasTorch { return dev }
        if let dev = AVCaptureDevice.default(for: .video), dev.hasTorch { return dev }
        return nil
    }
}
