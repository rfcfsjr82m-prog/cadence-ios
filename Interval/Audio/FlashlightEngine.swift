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

    private let onDuration: Double = 0.18

    nonisolated(unsafe) private var device: AVCaptureDevice? = nil
    /// True while we hold the AVCaptureDevice configuration lock.
    nonisolated(unsafe) private var configLocked = false
    nonisolated(unsafe) private var pendingOff: DispatchWorkItem? = nil

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
        pendingOff?.cancel()
        pendingOff = nil
        if let dev = device {
            if configLocked {
                dev.torchMode = .off
                dev.unlockForConfiguration()
            }
        }
        configLocked = false
        device = nil
    }

    // MARK: - Burst

    func burst() {
        guard let dev = device, dev.hasTorch else { return }

        // Cancel any pending turn-off from a previous burst.
        pendingOff?.cancel()
        pendingOff = nil

        if configLocked {
            // Fast path: we already hold the lock — set torch mode directly.
            // This is the only path that works reliably from the lock screen.
            guard (try? dev.setTorchModeOn(level: 1.0)) != nil else { return }
        } else {
            // Fallback (lock not held, e.g. another app had the camera at prepare time).
            do {
                try dev.lockForConfiguration()
                defer { dev.unlockForConfiguration() }
                try dev.setTorchModeOn(level: 1.0)
            } catch {
                return
            }
        }

        // Schedule turn-off on the main queue, which stays alive while the
        // audio background mode is active.
        nonisolated(unsafe) let capturedDev = dev
        let capturedLocked = configLocked
        let workItem = DispatchWorkItem {
            if capturedLocked {
                capturedDev.torchMode = .off
            } else {
                if (try? capturedDev.lockForConfiguration()) != nil {
                    capturedDev.torchMode = .off
                    capturedDev.unlockForConfiguration()
                }
            }
        }
        pendingOff = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + onDuration, execute: workItem)
    }

    // MARK: - Private

    private func bestTorchDevice() -> AVCaptureDevice? {
        if let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: nil, position: .back),
           dev.hasTorch { return dev }
        if let dev = AVCaptureDevice.default(for: .video), dev.hasTorch { return dev }
        return nil
    }
}
