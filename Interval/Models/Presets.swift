import Foundation

// MARK: - Built-in presets seeded on first launch

enum Presets {
    nonisolated(unsafe) static var all: [TimerConfig] = [
        boxBreathing,
        breathing478,
        coherentBreathing,
        preSleepBreathing,
        silentAnchor,
        meditation10,
        meditation15,
        meditation20,
        meditation30,
        tabata,
        hiit,
        sprintIntervals,
        mobilityDrill,
        strengthMovementPattern,
        pomodoro,
        deepWork,
        ultradianFocus,
        coldExposureSupport
    ]

    // MARK: Box Breathing — 4×4s, 15 rounds
    static let boxBreathing = TimerConfig(
        id: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
        name: "Box Breathing",
        category: .mind,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000001-0001-0000-0000-000000000001")!,
                        label: "Inhale", durationSeconds: 4,
                        color: .coral, soundCue: .sonarHigh,
                        hapticCue: .longBuzz, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000001-0002-0000-0000-000000000001")!,
                        label: "Hold", durationSeconds: 4,
                        color: .amber, soundCue: .sonarPing,
                        hapticCue: .softPulse, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000001-0003-0000-0000-000000000001")!,
                        label: "Exhale", durationSeconds: 4,
                        color: .coral, soundCue: .sonarLow,
                        hapticCue: .longBuzz, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000001-0004-0000-0000-000000000001")!,
                        label: "Hold", durationSeconds: 4,
                        color: .amber, soundCue: .sonarPing,
                        hapticCue: .softPulse, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(15),
        openingCountdownSecs: 10,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .female,
        isPreset: true,
        description: NSLocalizedString("preset.box_breathing.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 0)
    )

    // MARK: 4-7-8 Breathing — 3 blocks, 8 rounds
    static let breathing478 = TimerConfig(
        id: UUID(uuidString: "00000002-0000-0000-0000-000000000002")!,
        name: "4-7-8 Breathing",
        category: .mind,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000002-0001-0000-0000-000000000002")!,
                        label: "Inhale", durationSeconds: 4,
                        color: .sky, soundCue: .sonarHigh,
                        hapticCue: .softPulse, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000002-0002-0000-0000-000000000002")!,
                        label: "Hold", durationSeconds: 7,
                        color: .lavender, soundCue: .sonarPing,
                        hapticCue: .off, visualFlash: .none),
            BlockConfig(id: UUID(uuidString: "00000002-0003-0000-0000-000000000002")!,
                        label: "Exhale", durationSeconds: 8,
                        color: .teal, soundCue: .sonarLow,
                        hapticCue: .softPulse, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(8),
        openingCountdownSecs: 10,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .female,
        isPreset: true,
        description: NSLocalizedString("preset.478.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 1)
    )

    // MARK: Silent Anchor — 4s inhale / 4s exhale × 450 rounds (1 hour, haptic only)
    static let silentAnchor = TimerConfig(
        id: UUID(uuidString: "00000018-0000-0000-0000-000000000018")!,
        name: "Silent Anchor Against Anxiety",
        category: .mind,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000018-0001-0000-0000-000000000018")!,
                        label: "Inhale", durationSeconds: 4,
                        color: .lavender, soundCue: .silent,
                        hapticCue: .softPulse, visualFlash: .none),
            BlockConfig(id: UUID(uuidString: "00000018-0002-0000-0000-000000000018")!,
                        label: "Exhale", durationSeconds: 4,
                        color: .sage, soundCue: .silent,
                        hapticCue: .softPulse, visualFlash: .none),
        ],
        repeatMode: .rounds(450),
        openingCountdownSecs: 0,
        openingCountdownSoundEnabled: false,
        openingVoiceEnabled: false,
        closingVoiceEnabled: false,
        voiceGender: .female,
        openingCountdownLabel: "Get Ready",
        openingCountdownCue: .none,
        openingAnnouncementCue: .none,
        closingAnnouncementCue: .none,
        isPreset: true,
        description: NSLocalizedString("preset.silent_anchor.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 17)
    )

    // MARK: Coherent Breathing — 5s inhale / 5s exhale × 20 rounds
    static let coherentBreathing = TimerConfig(
        id: UUID(uuidString: "00000006-0000-0000-0000-000000000006")!,
        name: "Coherent Breathing",
        category: .mind,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000006-0001-0000-0000-000000000006")!,
                        label: "Inhale", durationSeconds: 5,
                        color: .lavender, soundCue: .bellGentle,
                        hapticCue: .off, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000006-0002-0000-0000-000000000006")!,
                        label: "Exhale", durationSeconds: 5,
                        color: .amber, soundCue: .bellGentle,
                        hapticCue: .off, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(20),
        openingCountdownSecs: 10,
        openingCountdownSoundEnabled: false,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .female,
        openingAnnouncementCue: .voice(.female),
        closingAnnouncementCue: .voice(.female),
        isPreset: true,
        description: NSLocalizedString("preset.coherent.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 5)
    )

    // MARK: Pre-Sleep Breathing — 4s inhale / 6s exhale / 2s hold × 20 rounds
    static let preSleepBreathing = TimerConfig(
        id: UUID(uuidString: "00000007-0000-0000-0000-000000000007")!,
        name: "Pre-Sleep Breathing",
        category: .mind,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000007-0001-0000-0000-000000000007")!,
                        label: "Inhale", durationSeconds: 4,
                        color: .sage, soundCue: .sonarHigh,
                        hapticCue: .off, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000007-0002-0000-0000-000000000007")!,
                        label: "Exhale", durationSeconds: 6,
                        color: .lavender, soundCue: .sonarLow,
                        hapticCue: .off, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000007-0003-0000-0000-000000000007")!,
                        label: "Hold", durationSeconds: 2,
                        color: .amber, soundCue: .sonarPing,
                        hapticCue: .off, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(20),
        openingCountdownSecs: 5,
        openingCountdownSoundEnabled: false,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .female,
        openingAnnouncementCue: .voice(.female),
        closingAnnouncementCue: .voice(.female),
        isPreset: true,
        description: NSLocalizedString("preset.presleep.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 6)
    )

    // MARK: 10-Minutes Meditation — 2 min × 5 rounds
    static let meditation10 = TimerConfig(
        id: UUID(uuidString: "00000013-0000-0000-0000-000000000013")!,
        name: "10-Minute Meditation",
        category: .mind,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000013-0001-0000-0000-000000000013")!,
                        label: "Focus", durationSeconds: 2 * 60,
                        color: .sage, soundCue: .bellGentle,
                        hapticCue: .off, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(5),
        openingCountdownSecs: 10,
        openingCountdownSoundEnabled: true,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .male,
        openingAnnouncementCue: .voice(.male),
        closingAnnouncementCue: .voice(.male),
        isPreset: true,
        description: NSLocalizedString("preset.med10.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 12)
    )

    // MARK: 15-Minutes Meditation — 3 min × 5 rounds
    static let meditation15 = TimerConfig(
        id: UUID(uuidString: "00000014-0000-0000-0000-000000000014")!,
        name: "15-Minute Meditation",
        category: .mind,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000014-0001-0000-0000-000000000014")!,
                        label: "Focus", durationSeconds: 3 * 60,
                        color: .sage, soundCue: .bellGentle,
                        hapticCue: .off, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(5),
        openingCountdownSecs: 10,
        openingCountdownSoundEnabled: true,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .female,
        openingAnnouncementCue: .voice(.female),
        closingAnnouncementCue: .voice(.female),
        isPreset: true,
        description: NSLocalizedString("preset.med15.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 13)
    )

    // MARK: 20-Minutes Meditation — 5 min × 4 rounds
    static let meditation20 = TimerConfig(
        id: UUID(uuidString: "00000015-0000-0000-0000-000000000015")!,
        name: "20-Minute Meditation",
        category: .mind,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000015-0001-0000-0000-000000000015")!,
                        label: "Focus", durationSeconds: 5 * 60,
                        color: .sage, soundCue: .bellGentle,
                        hapticCue: .off, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(4),
        openingCountdownSecs: 10,
        openingCountdownSoundEnabled: true,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .female,
        openingAnnouncementCue: .voice(.female),
        closingAnnouncementCue: .voice(.female),
        isPreset: true,
        description: NSLocalizedString("preset.med20.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 14)
    )

    // MARK: 30-Minutes Meditation — 5 min × 6 rounds
    static let meditation30 = TimerConfig(
        id: UUID(uuidString: "00000016-0000-0000-0000-000000000016")!,
        name: "30-Minute Meditation",
        category: .mind,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000016-0001-0000-0000-000000000016")!,
                        label: "Focus", durationSeconds: 5 * 60,
                        color: .sage, soundCue: .bellGentle,
                        hapticCue: .off, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(6),
        openingCountdownSecs: 10,
        openingCountdownSoundEnabled: true,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .female,
        openingAnnouncementCue: .voice(.female),
        closingAnnouncementCue: .voice(.female),
        isPreset: true,
        description: NSLocalizedString("preset.med30.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 15)
    )

    // MARK: Tabata — 20s work / 10s rest × 8 rounds
    static let tabata = TimerConfig(
        id: UUID(uuidString: "00000003-0000-0000-0000-000000000003")!,
        name: "Tabata",
        category: .physical,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000003-0001-0000-0000-000000000003")!,
                        label: "Work", durationSeconds: 20,
                        color: .coral, soundCue: .bleep,
                        hapticCue: .doubleTap, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000003-0002-0000-0000-000000000003")!,
                        label: "Rest", durationSeconds: 10,
                        color: .sage, soundCue: .tick,
                        hapticCue: .softPulse, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(8),
        openingCountdownSecs: 10,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .female,
        phasePrepEnabled: true,
        phasePrepSecs: 3,
        isPreset: true,
        description: NSLocalizedString("preset.tabata.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 2)
    )

    // MARK: HIIT — 40s work / 20s rest × 10 rounds
    static let hiit = TimerConfig(
        id: UUID(uuidString: "00000009-0000-0000-0000-000000000009")!,
        name: "HIIT",
        category: .physical,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000009-0001-0000-0000-000000000009")!,
                        label: "Work", durationSeconds: 40,
                        color: .sage, soundCue: .boxingBell,
                        hapticCue: .longBuzz, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000009-0002-0000-0000-000000000009")!,
                        label: "Rest", durationSeconds: 20,
                        color: .sage, soundCue: .boxingBell,
                        hapticCue: .longBuzz, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(10),
        openingCountdownSecs: 10,
        openingCountdownSoundEnabled: true,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .male,
        openingAnnouncementCue: .voice(.male),
        closingAnnouncementCue: .voice(.male),
        phasePrepEnabled: true,
        phasePrepSecs: 3,
        isPreset: true,
        description: NSLocalizedString("preset.hiit.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 8)
    )

    // MARK: Sprint Intervals — 20s sprint / 100s walk × 8 rounds
    static let sprintIntervals = TimerConfig(
        id: UUID(uuidString: "00000010-0000-0000-0000-000000000010")!,
        name: "Sprint Intervals",
        category: .physical,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000010-0001-0000-0000-000000000010")!,
                        label: "Sprint", durationSeconds: 20,
                        color: .sage, soundCue: .boxingBell,
                        hapticCue: .longBuzz, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000010-0002-0000-0000-000000000010")!,
                        label: "Walk", durationSeconds: 100,
                        color: .sage, soundCue: .boxingBell,
                        hapticCue: .longBuzz, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(8),
        openingCountdownSecs: 10,
        openingCountdownSoundEnabled: true,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .male,
        openingAnnouncementCue: .voice(.male),
        closingAnnouncementCue: .voice(.male),
        phasePrepEnabled: true,
        phasePrepSecs: 5,
        isPreset: true,
        description: NSLocalizedString("preset.sprint.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 9)
    )

    // MARK: Strength Movement Pattern — 3s contract / 3s hold / 5s release × 10 rounds
    static let strengthMovementPattern = TimerConfig(
        id: UUID(uuidString: "00000011-0000-0000-0000-000000000011")!,
        name: "Strength Movement Pattern",
        category: .physical,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000011-0001-0000-0000-000000000011")!,
                        label: "Concentric - Contract", durationSeconds: 3,
                        color: .teal, soundCue: .beacon,
                        hapticCue: .longBuzz, visualFlash: .none),
            BlockConfig(id: UUID(uuidString: "00000011-0002-0000-0000-000000000011")!,
                        label: "Isometric - Hold", durationSeconds: 3,
                        color: .teal, soundCue: .beacon,
                        hapticCue: .longBuzz, visualFlash: .none),
            BlockConfig(id: UUID(uuidString: "00000011-0003-0000-0000-000000000011")!,
                        label: "Eccentric - Release", durationSeconds: 5,
                        color: .teal, soundCue: .beacon,
                        hapticCue: .longBuzz, visualFlash: .none),
        ],
        repeatMode: .rounds(10),
        openingCountdownSecs: 5,
        openingCountdownSoundEnabled: true,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .male,
        openingAnnouncementCue: .voice(.male),
        closingAnnouncementCue: .voice(.male),
        isPreset: true,
        description: NSLocalizedString("preset.strength.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 10)
    )

    // MARK: Pomodoro — 25 min focus / 5 min break × 4 rounds
    static let pomodoro = TimerConfig(
        id: UUID(uuidString: "00000004-0000-0000-0000-000000000004")!,
        name: "Pomodoro",
        category: .productivity,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000004-0001-0000-0000-000000000004")!,
                        label: "Focus", durationSeconds: 25 * 60,
                        color: .lavender, soundCue: .silent,
                        hapticCue: .off, visualFlash: .none),
            BlockConfig(id: UUID(uuidString: "00000004-0002-0000-0000-000000000004")!,
                        label: "Break", durationSeconds: 5 * 60,
                        color: .teal, soundCue: .bellGentle,
                        hapticCue: .softPulse, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(4),
        openingCountdownSecs: 5,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .female,
        isPreset: true,
        description: NSLocalizedString("preset.pomodoro.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 3)
    )

    // MARK: Deep Work — 4 × 30 min phases × 1 round
    static let deepWork = TimerConfig(
        id: UUID(uuidString: "00000008-0000-0000-0000-000000000008")!,
        name: "Deep Work",
        category: .productivity,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000008-0001-0000-0000-000000000008")!,
                        label: "Start Now", durationSeconds: 30 * 60,
                        color: .sage, soundCue: .beacon,
                        hapticCue: .off, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000008-0002-0000-0000-000000000008")!,
                        label: "Continue", durationSeconds: 30 * 60,
                        color: .sage, soundCue: .beacon,
                        hapticCue: .off, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000008-0003-0000-0000-000000000008")!,
                        label: "You got this", durationSeconds: 30 * 60,
                        color: .sage, soundCue: .beacon,
                        hapticCue: .off, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000008-0004-0000-0000-000000000008")!,
                        label: "Almost there", durationSeconds: 30 * 60,
                        color: .sage, soundCue: .beacon,
                        hapticCue: .off, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(1),
        openingCountdownSecs: 10,
        openingCountdownSoundEnabled: true,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .male,
        openingAnnouncementCue: .voice(.male),
        closingAnnouncementCue: .voice(.male),
        isPreset: true,
        description: NSLocalizedString("preset.deepwork.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 7)
    )

    // MARK: Mobility Drill — 4s move / 6s hold / 4s return × 8 rounds
    static let mobilityDrill = TimerConfig(
        id: UUID(uuidString: "00000005-0000-0000-0000-000000000005")!,
        name: "Mobility Drill",
        category: .physical,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000005-0001-0000-0000-000000000005")!,
                        label: "Move", durationSeconds: 4,
                        color: .sage, soundCue: .sonarPing,
                        hapticCue: .softPulse, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000005-0002-0000-0000-000000000005")!,
                        label: "Hold", durationSeconds: 6,
                        color: .lavender, soundCue: .sonarHigh,
                        hapticCue: .softPulse, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000005-0003-0000-0000-000000000005")!,
                        label: "Return", durationSeconds: 4,
                        color: .sage, soundCue: .sonarPing,
                        hapticCue: .softPulse, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(8),
        openingCountdownSecs: 5,
        openingCountdownSoundEnabled: true,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .male,
        openingAnnouncementCue: .voice(.male),
        closingAnnouncementCue: .voice(.male),
        isPreset: true,
        description: NSLocalizedString("preset.mobility.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 4)
    )

    // MARK: Cold Exposure Support — 5s inhale / 5s exhale × 12 rounds
    static let coldExposureSupport = TimerConfig(
        id: UUID(uuidString: "00000017-0000-0000-0000-000000000017")!,
        name: "Cold Exposure Support",
        category: .mind,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000017-0001-0000-0000-000000000017")!,
                        label: "Inhale", durationSeconds: 5,
                        color: .amber, soundCue: .bellGentle,
                        hapticCue: .off, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000017-0002-0000-0000-000000000017")!,
                        label: "Exhale", durationSeconds: 5,
                        color: .sky, soundCue: .bellGentle,
                        hapticCue: .off, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(12),
        openingCountdownSecs: 15,
        openingCountdownSoundEnabled: true,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .male,
        openingAnnouncementCue: .voice(.male),
        closingAnnouncementCue: .voice(.male),
        isPreset: true,
        description: NSLocalizedString("preset.cold.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 16)
    )

    // MARK: Ultradian Focus — 75 min focus / 20 min recover × 2 rounds
    static let ultradianFocus = TimerConfig(
        id: UUID(uuidString: "00000012-0000-0000-0000-000000000012")!,
        name: "Ultradian Focus",
        category: .productivity,
        blocks: [
            BlockConfig(id: UUID(uuidString: "00000012-0001-0000-0000-000000000012")!,
                        label: "Focus", durationSeconds: 75 * 60,
                        color: .sage, soundCue: .beacon,
                        hapticCue: .off, visualFlash: .blockColor),
            BlockConfig(id: UUID(uuidString: "00000012-0002-0000-0000-000000000012")!,
                        label: "Recover", durationSeconds: 20 * 60,
                        color: .sage, soundCue: .beacon,
                        hapticCue: .off, visualFlash: .blockColor),
        ],
        repeatMode: .rounds(2),
        openingCountdownSecs: 10,
        openingCountdownSoundEnabled: true,
        openingVoiceEnabled: true,
        closingVoiceEnabled: true,
        voiceGender: .male,
        openingAnnouncementCue: .voice(.male),
        closingAnnouncementCue: .voice(.male),
        isPreset: true,
        description: NSLocalizedString("preset.ultradian.desc", comment: ""),
        createdAt: Date(timeIntervalSince1970: 11)
    )
}

// MARK: - Seed helper

func seedPresetsIfNeeded(existing: [TimerConfig],
                         insert: (TimerConfig) -> Void,
                         update: (TimerConfig) -> Void) {
    let existingIDs = Set(existing.map(\.id))
    for preset in Presets.all {
        if existingIDs.contains(preset.id) {
            update(preset)
        } else {
            insert(preset)
        }
    }
}
