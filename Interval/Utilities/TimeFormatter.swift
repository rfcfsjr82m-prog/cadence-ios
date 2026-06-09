import Foundation

struct TimeFormatter {

    // "M:SS" used in main timer display
    static func timerDisplay(_ totalSeconds: Int) -> String {
        let s = abs(totalSeconds)
        let m = s / 60
        let sec = s % 60
        return "\(m):\(String(format: "%02d", sec))"
    }

    // "Xs" or "Xm Ys" compact badge on block cards
    static func durationBadge(_ totalSeconds: Int) -> String {
        let s = totalSeconds
        guard s >= 60 else { return "\(s)s" }
        let m = s / 60
        let rem = s % 60
        if rem == 0 { return "\(m)m" }
        return "\(m)m \(rem)s"
    }

    // "X rounds · Y min" in stats row
    static func statsRow(rounds: Int, totalSeconds: Int) -> String {
        let mins = Int(ceil(Double(totalSeconds) / 60.0))
        return "\(rounds) rounds · \(mins) min"
    }

    // "0:00" elapsed / remaining
    static func elapsed(_ seconds: Int) -> String {
        timerDisplay(seconds)
    }
}
