import WatchConnectivity

final class WatchSyncManager: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSyncManager()
    private var latestConfigs: [TimerConfig] = []

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sync(_ configs: [TimerConfig]) {
        latestConfigs = configs
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        sendToWatch(configs)
    }

    private func sendToWatch(_ configs: [TimerConfig]) {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        let pinnedIDs = UserDefaults.standard.stringArray(forKey: "pinnedTimerIDs") ?? []
        WCSession.default.transferUserInfo(["timers": data, "pinnedTimerIDs": pinnedIDs])
    }

    // MARK: - WCSessionDelegate

    // Watch requested timers directly — reply immediately
    static let completionNotification = Notification.Name("WatchSessionCompleted")

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if message["request"] as? String == "timers" {
            var reply: [String: Any] = [:]
            if let data = try? JSONEncoder().encode(latestConfigs) { reply["timers"] = data }
            let ids = UserDefaults.standard.stringArray(forKey: "completedUnitIDs") ?? []
            reply["completedUnitIDs"] = ids
            let pinnedIDs = UserDefaults.standard.stringArray(forKey: "pinnedTimerIDs") ?? []
            reply["pinnedTimerIDs"] = pinnedIDs
            replyHandler(reply)
        } else {
            replyHandler([:])
        }
    }

    // No-reply message (e.g. completion report from Watch)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let inner = message["watchCompletion"] as? [String: Any] {
            handleCompletion(inner)
        }
    }

    // Queued delivery (Watch not reachable at time of completion)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let inner = userInfo["watchCompletion"] as? [String: Any] {
            handleCompletion(inner)
        }
    }

    private func handleCompletion(_ data: [String: Any]) {
        guard let configData   = data["configData"]    as? Data,
              let elapsed      = data["elapsedSeconds"] as? Int,
              let wasCompleted = data["wasCompleted"]   as? Bool,
              let config       = try? JSONDecoder().decode(TimerConfig.self, from: configData)
        else { return }

        // Mark program unit completed in UserDefaults
        if wasCompleted {
            var stored = UserDefaults.standard.stringArray(forKey: "completedUnitIDs") ?? []
            let uid = config.id.uuidString
            if !stored.contains(uid) {
                stored.append(uid)
                UserDefaults.standard.set(stored, forKey: "completedUnitIDs")
            }
        }

        // Notify the app to insert a SessionHistoryEntry via SwiftData
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: WatchSyncManager.completionNotification,
                object: nil,
                userInfo: ["configData": configData, "elapsed": elapsed, "wasCompleted": wasCompleted]
            )
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if activationState == .activated && !latestConfigs.isEmpty {
            sendToWatch(latestConfigs)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
