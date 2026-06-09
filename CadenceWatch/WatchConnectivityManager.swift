import WatchConnectivity
import Combine

final class WatchConnectivityManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = WatchConnectivityManager()

    @Published private(set) var personalTimers: [TimerConfig] = []
    @Published private(set) var completedUnitIDs: Set<UUID> = []
    @Published private(set) var pinnedTimerIDs: Set<UUID> = []

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Report a completed session to the iPhone for history + program tracking.
    func reportCompletion(config: TimerConfig, elapsedSeconds: Int, wasCompleted: Bool) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              let configData = try? JSONEncoder().encode(config) else { return }
        let payload: [String: Any] = [
            "watchCompletion": [
                "configData": configData,
                "elapsedSeconds": elapsedSeconds,
                "wasCompleted": wasCompleted
            ]
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    /// Call this to request fresh timers from the paired iPhone app.
    func refresh() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }

        WCSession.default.sendMessage(["request": "timers"], replyHandler: { [weak self] reply in
            if let data = reply["timers"] as? Data,
               let configs = try? JSONDecoder().decode([TimerConfig].self, from: data) {
                let personal = configs.filter { !$0.isPreset }
                DispatchQueue.main.async { self?.personalTimers = personal }
            }
            if let ids = reply["completedUnitIDs"] as? [String] {
                let uuids = Set(ids.compactMap { UUID(uuidString: $0) })
                DispatchQueue.main.async { self?.completedUnitIDs = uuids }
            }
            if let ids = reply["pinnedTimerIDs"] as? [String] {
                let uuids = Set(ids.compactMap { UUID(uuidString: $0) })
                DispatchQueue.main.async { self?.pinnedTimerIDs = uuids }
            }
        }, errorHandler: nil)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        guard activationState == .activated else { return }
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }

    // Background delivery from iPhone transferUserInfo
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["timers"] as? Data,
              let configs = try? JSONDecoder().decode([TimerConfig].self, from: data)
        else { return }
        let personal = configs.filter { !$0.isPreset }
        DispatchQueue.main.async { [weak self] in self?.personalTimers = personal }
        if let ids = userInfo["pinnedTimerIDs"] as? [String] {
            let uuids = Set(ids.compactMap { UUID(uuidString: $0) })
            DispatchQueue.main.async { [weak self] in self?.pinnedTimerIDs = uuids }
        }
    }
}
