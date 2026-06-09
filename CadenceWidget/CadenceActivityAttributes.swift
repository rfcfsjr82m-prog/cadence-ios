import ActivityKit

// Mirror of the same struct in the main app target.
// Both must stay in sync (same field names, same types).

struct CadenceActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var blockLabel: String
        var blockLeft: Int
        var roundLabel: String
        var totalLeft: Int
        var blockColorHex: String
        var isPaused: Bool
    }
    var timerName: String
}
