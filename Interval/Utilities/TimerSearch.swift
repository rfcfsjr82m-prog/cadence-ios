import Foundation

// MARK: - Semantic search for TimerConfig
//
// Matching priority (any hit = included):
//  1. Timer name
//  2. Description
//  3. Block labels
//  4. Category display name
//  5. Semantic keyword map — extra aliases not present in any text above

extension TimerConfig {

    func matches(query: String) -> Bool {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }

        // 1. Name
        if name.lowercased().contains(q) { return true }

        // 2. Description
        if description.lowercased().contains(q) { return true }

        // 3. Block labels
        if blocks.contains(where: { $0.label.lowercased().contains(q) }) { return true }

        // 4. Category
        if category.displayName.lowercased().contains(q) { return true }

        // 5. Semantic keyword map
        if Self.semanticKeywords(for: id).contains(where: { $0.contains(q) }) { return true }

        return false
    }

    // Preset-specific aliases for concepts not captured in name / description.
    // Key = preset UUID string, value = extra searchable terms (all lowercase).
    private static func semanticKeywords(for id: UUID) -> [String] {
        switch id.uuidString {

        // ── Mind ──────────────────────────────────────────────────────────────
        case "00000001-0000-0000-0000-000000000001": // Box Breathing
            return ["meditation", "mindfulness", "relax", "calm", "anxiety",
                    "stress", "nervous system", "breath", "breathwork"]

        case "00000002-0000-0000-0000-000000000002": // 4-7-8 Breathing
            return ["meditation", "sleep", "relax", "calm", "anxiety",
                    "stress", "breath", "breathwork", "weil"]

        case "00000013-0000-0000-0000-000000000013", // 10-Minute Meditation
             "00000014-0000-0000-0000-000000000014", // 15-Minute Meditation
             "00000015-0000-0000-0000-000000000015", // 20-Minute Meditation
             "00000016-0000-0000-0000-000000000016": // 30-Minute Meditation
            return ["meditation", "mindfulness", "relax", "calm", "breath",
                    "awareness", "sit", "stillness", "bell", "presence"]

        case "00000006-0000-0000-0000-000000000006": // Coherent Breathing
            return ["meditation", "hrv", "heart rate variability", "relax",
                    "calm", "balance", "breath", "breathwork", "resonance"]

        case "00000007-0000-0000-0000-000000000007": // Pre-Sleep Breathing
            return ["meditation", "relax", "calm", "night", "bedtime",
                    "insomnia", "wind down", "breath", "breathwork"]

        // ── Body ──────────────────────────────────────────────────────────────
        case "00000003-0000-0000-0000-000000000003": // Tabata
            return ["workout", "exercise", "cardio", "fitness", "training",
                    "interval", "hiit", "intense", "burn"]

        case "00000009-0000-0000-0000-000000000009": // HIIT
            return ["workout", "exercise", "cardio", "fitness", "training",
                    "interval", "intense", "burn", "classic"]

        case "00000010-0000-0000-0000-000000000010": // Sprint Intervals
            return ["run", "running", "workout", "exercise", "cardio",
                    "fitness", "training", "speed", "jog", "outdoor"]

        case "00000005-0000-0000-0000-000000000005": // Mobility Drill
            return ["stretch", "flexibility", "warmup", "warm up",
                    "cool down", "movement", "joint", "range of motion"]

        case "00000011-0000-0000-0000-000000000011": // Strength Movement Pattern
            return ["workout", "exercise", "lifting", "weights", "gym",
                    "muscle", "tempo", "resistance", "training", "reps"]

        // ── Productivity ──────────────────────────────────────────────────────
        case "00000004-0000-0000-0000-000000000004": // Pomodoro
            return ["focus", "work", "productivity", "study", "concentration",
                    "cirillo", "tomato", "task", "distraction"]

        case "00000008-0000-0000-0000-000000000008": // Deep Work
            return ["focus", "concentration", "flow", "study", "distraction",
                    "cal newport", "long", "session", "undisturbed"]

        case "00000012-0000-0000-0000-000000000012": // Ultradian Focus
            return ["focus", "concentration", "flow", "study", "energy",
                    "cycle", "rhythm", "ultradian", "rest", "recovery"]

        case "00000017-0000-0000-0000-000000000017": // Cold Exposure Support
            return ["cold", "plunge", "ice", "shower", "wim hof", "breathwork",
                    "nervous system", "inhale", "exhale", "slow", "controlled",
                    "cold water", "vagus", "resilience", "stress"]

        default:
            return []
        }
    }
}
