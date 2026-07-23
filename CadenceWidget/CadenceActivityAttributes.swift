import Foundation
import ActivityKit

// Mirror of the same struct in the main app target.
// Both must stay in sync (same field names, same types).

struct CadenceActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var blockLabel: String
        var roundLabel: String
        var blockColorHex: String
        var isPaused: Bool
        var blockStartDate: Date
        var blockEndDate: Date
        var sessionStartDate: Date
        var sessionEndDate: Date
        var blockLeftAtPause: Int
        var totalLeftAtPause: Int
    }
    var timerName: String
}
