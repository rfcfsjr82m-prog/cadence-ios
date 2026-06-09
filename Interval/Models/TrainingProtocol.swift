import Foundation

// MARK: - Training Protocol

struct TrainingProtocol: Identifiable {
    let id:          UUID
    let name:        String
    let description: String
    let category:    Category
    let units:       [TimerConfig]
}

// MARK: - Built-in protocols catalogue

enum TrainingProtocols {
    static let all: [TrainingProtocol] = [fiveK, readingStamina, meditation]

    // MARK: - 5K Run Training Protocol (23 units)
    //
    // Structure types used across the plan:
    //   • Interval   — [Run + Walk] repeated for a total duration
    //   • Fixed      — [Run + Walk] repeated a fixed number of rounds
    //   • RWR        — Run → Walk → Run (once, 3 blocks)
    //   • Continuous — single Running block, no walk
    //
    // All durations in descriptions include the 5-min warm-up.

    static let fiveK = TrainingProtocol(
        id: UUID(uuidString: "5F000000-0000-0000-0000-000000000000")!,
        name: "5K Run Training",
        description: NSLocalizedString("5k.description", comment: ""),
        category: .physical,
        units: [
            // Units 1–2  ·  2 min run + 2 min walk, 20 min  ·  total 25 min
            intervalUnit(1,  run: 120, walk: 120, durationMins: 20, totalMins: 25),
            intervalUnit(2,  run: 120, walk: 120, durationMins: 20, totalMins: 25),
            // Units 3–4  ·  2.5 min run + 2.5 min walk, 20 min  ·  total 25 min
            intervalUnit(3,  run: 150, walk: 150, durationMins: 20, totalMins: 25),
            intervalUnit(4,  run: 150, walk: 150, durationMins: 20, totalMins: 25),
            // Units 5–6  ·  3 min run + 2 min walk, 20 min  ·  total 25 min
            intervalUnit(5,  run: 180, walk: 120, durationMins: 20, totalMins: 25),
            intervalUnit(6,  run: 180, walk: 120, durationMins: 20, totalMins: 25),
            // Units 7–8  ·  4 min run + 2 min walk, 25 min  ·  total 30 min
            intervalUnit(7,  run: 240, walk: 120, durationMins: 25, totalMins: 30),
            intervalUnit(8,  run: 240, walk: 120, durationMins: 25, totalMins: 30),
            // Units 9–10  ·  5 min run + 2.5 min walk, 25 min  ·  total 30 min
            intervalUnit(9,  run: 300, walk: 150, durationMins: 25, totalMins: 30),
            intervalUnit(10, run: 300, walk: 150, durationMins: 25, totalMins: 30),
            // Unit 11  ·  6 min run + 3 min walk × 3  ·  total 32 min
            fixedUnit(11, run: 360, walk: 180, rounds: 3, totalMins: 32),
            // Units 12–13  ·  8 min run + 2.5 min walk × 3  ·  total 37 min
            fixedUnit(12, run: 480, walk: 150, rounds: 3, totalMins: 37),
            fixedUnit(13, run: 480, walk: 150, rounds: 3, totalMins: 37),
            // Units 14–15  ·  12 + 3 + 12  ·  total 32 min
            rwrUnit(14, run: 720, walk: 180),
            rwrUnit(15, run: 720, walk: 180),
            // Units 16–17  ·  13 + 3 + 13  ·  total 34 min
            rwrUnit(16, run: 780, walk: 180),
            rwrUnit(17, run: 780, walk: 180),
            // Units 18–20  ·  20 min continuous  ·  total 25 min
            continuousUnit(18, runSeconds: 1200),
            continuousUnit(19, runSeconds: 1200),
            continuousUnit(20, runSeconds: 1200),
            // Units 21–23  ·  30 min continuous  ·  total 35 min
            continuousUnit(21, runSeconds: 1800),
            continuousUnit(22, runSeconds: 1800),
            continuousUnit(23, runSeconds: 1800),
        ]
    )

    // MARK: - 5K builders

    private static func intervalUnit(_ n: Int, run: Int, walk: Int,
                                     durationMins: Int, totalMins: Int) -> TimerConfig {
        let runMins  = fmtMins(run)
        let walkMins = fmtMins(walk)
        let desc = String(format: NSLocalizedString("unit.5k.interval %@ %@ %lld %lld", comment: ""),
                          runMins, walkMins, durationMins, totalMins)
        return fiveKBase(n, blocks: runWalkBlocks(n, run: run, walk: walk),
                         repeatMode: .duration(minutes: durationMins), desc: desc)
    }

    private static func fixedUnit(_ n: Int, run: Int, walk: Int,
                                   rounds: Int, totalMins: Int) -> TimerConfig {
        let runMins  = fmtMins(run)
        let walkMins = fmtMins(walk)
        let desc = String(format: NSLocalizedString("unit.5k.fixed %lld %@ %@ %lld", comment: ""),
                          rounds, runMins, walkMins, totalMins)
        return fiveKBase(n, blocks: runWalkBlocks(n, run: run, walk: walk),
                         repeatMode: .rounds(rounds), desc: desc)
    }

    private static func rwrUnit(_ n: Int, run: Int, walk: Int) -> TimerConfig {
        let runMins  = run / 60
        let walkMins = walk / 60
        let totalMins = 5 + runMins * 2 + walkMins
        let desc = String(format: NSLocalizedString("unit.5k.rwr %lld %lld %lld", comment: ""),
                          runMins, walkMins, totalMins)
        let runA = BlockConfig(
            id: UUID(uuidString: String(format: "5FA%05X-0000-0000-0000-000000000000", n))!,
            label: "Running", durationSeconds: run,
            color: .amber, soundCue: .voiceMaleRunning,
            hapticCue: .longBuzz, visualFlash: .none, midwayCue: .voiceMaleHalfway)
        let walkB = BlockConfig(
            id: UUID(uuidString: String(format: "5FB%05X-0000-0000-0000-000000000000", n))!,
            label: "Walking", durationSeconds: walk,
            color: .coral, soundCue: .voiceMaleWalking,
            hapticCue: .softPulse, visualFlash: .none)
        let runC = BlockConfig(
            id: UUID(uuidString: String(format: "5FC%05X-0000-0000-0000-000000000000", n))!,
            label: "Running", durationSeconds: run,
            color: .amber, soundCue: .voiceMaleRunning,
            hapticCue: .longBuzz, visualFlash: .none, midwayCue: .voiceMaleHalfway)
        return fiveKBase(n, blocks: [runA, walkB, runC], repeatMode: .rounds(1), desc: desc)
    }

    private static func continuousUnit(_ n: Int, runSeconds: Int) -> TimerConfig {
        let runMins  = runSeconds / 60
        let totalMins = 5 + runMins
        let desc = String(format: NSLocalizedString("unit.5k.continuous %lld %lld", comment: ""),
                          runMins, totalMins)
        let runBlock = BlockConfig(
            id: UUID(uuidString: String(format: "5FA%05X-0000-0000-0000-000000000000", n))!,
            label: "Running", durationSeconds: runSeconds,
            color: .amber, soundCue: .voiceMaleRunning,
            hapticCue: .longBuzz, visualFlash: .none, midwayCue: .voiceMaleHalfway)
        return fiveKBase(n, blocks: [runBlock], repeatMode: .rounds(1), desc: desc)
    }

    /// Format seconds as "N Min" or "N.5 Min" for display in unit descriptions.
    private static func fmtMins(_ secs: Int) -> String {
        secs % 60 == 0 ? "\(secs / 60)" : "\(secs / 60).\(secs % 60 * 10 / 60)"
    }

    private static func runWalkBlocks(_ n: Int, run: Int, walk: Int) -> [BlockConfig] {
        [
            BlockConfig(
                id: UUID(uuidString: String(format: "5FA%05X-0000-0000-0000-000000000000", n))!,
                label: "Running", durationSeconds: run,
                color: .amber, soundCue: .voiceMaleRunning,
                hapticCue: .longBuzz, visualFlash: .none, midwayCue: .voiceMaleHalfway),
            BlockConfig(
                id: UUID(uuidString: String(format: "5FB%05X-0000-0000-0000-000000000000", n))!,
                label: "Walking", durationSeconds: walk,
                color: .coral, soundCue: .voiceMaleWalking,
                hapticCue: .softPulse, visualFlash: .none),
        ]
    }

    private static func fiveKBase(_ n: Int, blocks: [BlockConfig],
                                   repeatMode: RepeatMode, desc: String) -> TimerConfig {
        TimerConfig(
            id: UUID(uuidString: String(format: "5F%06X-0000-0000-0000-000000000000", n))!,
            name: "5K Run Training – Unit \(n)",
            category: .physical,
            blocks: blocks,
            repeatMode: repeatMode,
            openingCountdownSecs: 300,
            openingCountdownSoundEnabled: true,
            openingVoiceEnabled: true,
            closingVoiceEnabled: true,
            voiceGender: .male,
            openingCountdownLabel: "Warm-Up",
            openingCountdownCue: .sound(.voiceMaleWarmingUp),
            openingAnnouncementCue: .voice(.male),
            closingAnnouncementCue: .voice(.male),
            isPreset: true,
            description: desc
        )
    }

    // MARK: - Reading Stamina Protocol (8 units)

    static let readingStamina = TrainingProtocol(
        id: UUID(uuidString: "52000000-0000-0000-0000-000000000000")!,
        name: "Reading Stamina",
        description: NSLocalizedString("reading.description", comment: ""),
        category: .mind,
        units: [
            readingUnit(1, totalMins: 5,  bellEveryMins: 0),
            readingUnit(2, totalMins: 10, bellEveryMins: 5),
            readingUnit(3, totalMins: 15, bellEveryMins: 5),
            readingUnit(4, totalMins: 20, bellEveryMins: 5),
            readingUnit(5, totalMins: 30, bellEveryMins: 10),
            readingUnit(6, totalMins: 40, bellEveryMins: 10),
            readingUnit(7, totalMins: 50, bellEveryMins: 10),
            readingUnit(8, totalMins: 60, bellEveryMins: 10),
        ]
    )

    // MARK: - Meditation Protocol (28 units)

    static let meditation = TrainingProtocol(
        id: UUID(uuidString: "4D000000-0000-0000-0000-000000000000")!,
        name: "Meditation",
        description: NSLocalizedString("meditation.description", comment: ""),
        category: .mind,
        units: [
            // Units 1–4  ·  5 min, bell every 2.5 min
            meditationUnit(1,  totalSecs: 300,  bellEverySecs: 150),
            meditationUnit(2,  totalSecs: 300,  bellEverySecs: 150),
            meditationUnit(3,  totalSecs: 300,  bellEverySecs: 150),
            meditationUnit(4,  totalSecs: 300,  bellEverySecs: 150),

            // Units 5–8  ·  10 min, bell every 2.5 min
            meditationUnit(5,  totalSecs: 600,  bellEverySecs: 150),
            meditationUnit(6,  totalSecs: 600,  bellEverySecs: 150),
            meditationUnit(7,  totalSecs: 600,  bellEverySecs: 150),
            meditationUnit(8,  totalSecs: 600,  bellEverySecs: 150),

            // Units 9–12  ·  15 min, bell every 5 min
            meditationUnit(9,  totalSecs: 900,  bellEverySecs: 300),
            meditationUnit(10, totalSecs: 900,  bellEverySecs: 300),
            meditationUnit(11, totalSecs: 900,  bellEverySecs: 300),
            meditationUnit(12, totalSecs: 900,  bellEverySecs: 300),

            // Units 13–18  ·  20 min, bell every 5 min
            meditationUnit(13, totalSecs: 1200, bellEverySecs: 300),
            meditationUnit(14, totalSecs: 1200, bellEverySecs: 300),
            meditationUnit(15, totalSecs: 1200, bellEverySecs: 300),
            meditationUnit(16, totalSecs: 1200, bellEverySecs: 300),
            meditationUnit(17, totalSecs: 1200, bellEverySecs: 300),
            meditationUnit(18, totalSecs: 1200, bellEverySecs: 300),

            // Units 19–22  ·  25 min, bell every 5 min
            meditationUnit(19, totalSecs: 1500, bellEverySecs: 300),
            meditationUnit(20, totalSecs: 1500, bellEverySecs: 300),
            meditationUnit(21, totalSecs: 1500, bellEverySecs: 300),
            meditationUnit(22, totalSecs: 1500, bellEverySecs: 300),

            // Unit 23  ·  30 min, bell every 10 min
            meditationUnit(23, totalSecs: 1800, bellEverySecs: 600),
        ]
    )

    /// Single Meditation block repeated N times so the bell fires at each interval boundary.
    private static func meditationUnit(_ n: Int, totalSecs: Int, bellEverySecs: Int) -> TimerConfig {
        let rounds    = totalSecs / bellEverySecs
        let totalMins = totalSecs / 60

        // Format bell interval — handles whole minutes and half-minutes (e.g. 150s → "2.5 Min")
        let bellLabel: String = bellEverySecs % 60 == 0
            ? "\(bellEverySecs / 60) Min"
            : "\(bellEverySecs / 60).\(bellEverySecs % 60 * 10 / 60) Min"

        let desc = String(format: NSLocalizedString("unit.meditation %lld %@", comment: ""), totalMins, bellLabel)

        let block = BlockConfig(
            id: UUID(uuidString: String(format: "4DA%05X-0000-0000-0000-000000000000", n))!,
            label: "Meditation",
            durationSeconds: bellEverySecs,
            color: .teal,
            soundCue: .bellGentle,
            hapticCue: .off,
            visualFlash: .none
        )

        return TimerConfig(
            id: UUID(uuidString: String(format: "4D%06X-0000-0000-0000-000000000000", n))!,
            name: "Meditation – Unit \(n)",
            category: .mind,
            blocks: [block],
            repeatMode: .rounds(rounds),
            openingCountdownSecs: 10,
            openingCountdownSoundEnabled: true,
            openingVoiceEnabled: true,
            closingVoiceEnabled: true,
            voiceGender: .female,
            openingCountdownCue: .none,
            openingAnnouncementCue: .voice(.female),
            closingAnnouncementCue: .voice(.female),
            isPreset: true,
            description: desc
        )
    }

    // MARK: - Reading Stamina builders

    /// Single Reading block repeated N times so the bell fires at each interval boundary.
    /// bellEveryMins == 0 → silent session (Unit 1).
    private static func readingUnit(_ n: Int, totalMins: Int, bellEveryMins: Int) -> TimerConfig {
        let hasBell   = bellEveryMins > 0
        let blockSecs = (hasBell ? bellEveryMins : totalMins) * 60
        let rounds    = hasBell ? totalMins / bellEveryMins : 1

        let desc = hasBell
            ? String(format: NSLocalizedString("unit.reading.bell %lld %lld", comment: ""), totalMins, bellEveryMins)
            : String(format: NSLocalizedString("unit.reading.silent %lld", comment: ""), totalMins)

        let block = BlockConfig(
            id: UUID(uuidString: String(format: "52A%05X-0000-0000-0000-000000000000", n))!,
            label: "Reading",
            durationSeconds: blockSecs,
            color: .teal,
            soundCue: hasBell ? .bellGentle : .silent,
            hapticCue: .off,
            visualFlash: .none
        )

        return TimerConfig(
            id: UUID(uuidString: String(format: "52%06X-0000-0000-0000-000000000000", n))!,
            name: "Reading Stamina – Unit \(n)",
            category: .mind,
            blocks: [block],
            repeatMode: .rounds(rounds),
            openingCountdownSecs: 5,
            openingCountdownSoundEnabled: true,
            openingVoiceEnabled: true,
            closingVoiceEnabled: true,
            voiceGender: .female,
            openingCountdownCue: .none,
            openingAnnouncementCue: .voice(.female),
            closingAnnouncementCue: .voice(.female),
            isPreset: true,
            description: desc
        )
    }
}
