import Foundation
import SwiftUI

// MARK: - Domain model (value types used throughout the app and wizard)

struct TimerConfig: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = "Timer"
    var category: Category = .mind
    var blocks: [BlockConfig] = []
    var repeatMode: RepeatMode = .rounds(8)
    var openingCountdownSecs: Int = 10
    var openingCountdownSoundEnabled: Bool = true
    var openingVoiceEnabled: Bool = true
    var closingVoiceEnabled: Bool = true
    var voiceGender: VoiceGender = .female
    var openingCountdownLabel: String = "Get Ready"       // text shown above the countdown number
    var openingCountdownCue: AnnouncementCue = .none      // plays when countdown starts
    var openingAnnouncementCue: AnnouncementCue = .voice(.female)
    var closingAnnouncementCue: AnnouncementCue = .voice(.female)
    var isPreset: Bool = false
    var description: String = ""
    var createdAt: Date = Date()

    // ── Background image ────────────────────────────────────────────────────
    var backgroundImageName: String = ""

    // ── Round prep signal ───────────────────────────────────────────────────
    var roundPrepEnabled: Bool = false
    var roundPrepSecs: Int = 3

    // ── Phase prep signal ───────────────────────────────────────────────────
    // A brief beep at the end of each block to signal the next phase is coming.
    var phasePrepEnabled: Bool = false
    var phasePrepSecs: Int = 3

    // ── Metronome (FeatureFlags.metronome) ──────────────────────────────────
    var metronomeEnabled: Bool = false
    var metronomeIntervalSeconds: Int = 60
    var metronomeSoundCue: SoundCue = .bellGentle
    var metronomeHapticCue: HapticCue = .softPulse

    // Backward-compatible decoder: new fields fall back to defaults when missing
    enum CodingKeys: String, CodingKey {
        case id, name, category, blocks, repeatMode
        case openingCountdownSecs, openingCountdownSoundEnabled
        case openingVoiceEnabled, closingVoiceEnabled, voiceGender
        case openingCountdownLabel, openingCountdownCue
        case openingAnnouncementCue, closingAnnouncementCue
        case isPreset, description, createdAt
        case metronomeEnabled, metronomeIntervalSeconds, metronomeSoundCue, metronomeHapticCue
        case backgroundImageName
        case roundPrepEnabled, roundPrepSecs
        case phasePrepEnabled, phasePrepSecs
    }

    init(id: UUID = UUID(), name: String = "Timer", category: Category = .mind,
         blocks: [BlockConfig] = [], repeatMode: RepeatMode = .rounds(8),
         openingCountdownSecs: Int = 10, openingCountdownSoundEnabled: Bool = true,
         openingVoiceEnabled: Bool = true, closingVoiceEnabled: Bool = true,
         voiceGender: VoiceGender = .female,
         openingCountdownLabel: String = "Get Ready",
         openingCountdownCue: AnnouncementCue = .none,
         openingAnnouncementCue: AnnouncementCue = .voice(.female),
         closingAnnouncementCue: AnnouncementCue = .voice(.female),
         roundPrepEnabled: Bool = false, roundPrepSecs: Int = 3,
         phasePrepEnabled: Bool = false, phasePrepSecs: Int = 3,
         isPreset: Bool = false, description: String = "", createdAt: Date = Date()) {
        self.id = id; self.name = name; self.category = category
        self.blocks = blocks; self.repeatMode = repeatMode
        self.openingCountdownSecs = openingCountdownSecs
        self.openingCountdownSoundEnabled = openingCountdownSoundEnabled
        self.openingVoiceEnabled = openingVoiceEnabled
        self.closingVoiceEnabled = closingVoiceEnabled
        self.voiceGender = voiceGender
        self.openingCountdownLabel = openingCountdownLabel
        self.openingCountdownCue = openingCountdownCue
        self.openingAnnouncementCue = openingAnnouncementCue
        self.closingAnnouncementCue = closingAnnouncementCue
        self.roundPrepEnabled = roundPrepEnabled; self.roundPrepSecs = roundPrepSecs
        self.phasePrepEnabled = phasePrepEnabled; self.phasePrepSecs = phasePrepSecs
        self.isPreset = isPreset; self.description = description; self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(Category.self, forKey: .category)
        blocks = try c.decode([BlockConfig].self, forKey: .blocks)
        repeatMode = try c.decode(RepeatMode.self, forKey: .repeatMode)
        openingCountdownSecs = try c.decode(Int.self, forKey: .openingCountdownSecs)
        openingCountdownSoundEnabled = try c.decodeIfPresent(Bool.self, forKey: .openingCountdownSoundEnabled) ?? true
        openingVoiceEnabled = try c.decode(Bool.self, forKey: .openingVoiceEnabled)
        closingVoiceEnabled = try c.decode(Bool.self, forKey: .closingVoiceEnabled)
        voiceGender = try c.decode(VoiceGender.self, forKey: .voiceGender)
        openingCountdownLabel  = try c.decodeIfPresent(String.self,          forKey: .openingCountdownLabel)  ?? "Get Ready"
        openingCountdownCue    = try c.decodeIfPresent(AnnouncementCue.self, forKey: .openingCountdownCue)    ?? .none
        openingAnnouncementCue = try c.decodeIfPresent(AnnouncementCue.self, forKey: .openingAnnouncementCue) ?? .voice(.female)
        closingAnnouncementCue = try c.decodeIfPresent(AnnouncementCue.self, forKey: .closingAnnouncementCue) ?? .voice(.female)
        isPreset = try c.decode(Bool.self, forKey: .isPreset)
        description = try c.decode(String.self, forKey: .description)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        metronomeEnabled         = try c.decodeIfPresent(Bool.self,       forKey: .metronomeEnabled)         ?? false
        metronomeIntervalSeconds = try c.decodeIfPresent(Int.self,        forKey: .metronomeIntervalSeconds)  ?? 60
        metronomeSoundCue        = try c.decodeIfPresent(SoundCue.self,   forKey: .metronomeSoundCue)         ?? .bellGentle
        metronomeHapticCue       = try c.decodeIfPresent(HapticCue.self,  forKey: .metronomeHapticCue)        ?? .softPulse
        backgroundImageName      = try c.decodeIfPresent(String.self,     forKey: .backgroundImageName)       ?? ""
        roundPrepEnabled         = try c.decodeIfPresent(Bool.self,       forKey: .roundPrepEnabled)           ?? false
        roundPrepSecs            = try c.decodeIfPresent(Int.self,        forKey: .roundPrepSecs)              ?? 3
        phasePrepEnabled         = try c.decodeIfPresent(Bool.self,       forKey: .phasePrepEnabled)           ?? false
        phasePrepSecs            = try c.decodeIfPresent(Int.self,        forKey: .phasePrepSecs)              ?? 3
    }

    static func empty() -> TimerConfig { TimerConfig() }

    // Derived
    var totalRounds: Int {
        switch repeatMode {
        case .rounds(let n): return n
        case .duration(let mins):
            let roundSecs = blocks.reduce(0) { $0 + $1.durationSeconds }
            guard roundSecs > 0 else { return 1 }
            return max(1, Int(ceil(Double(mins * 60) / Double(roundSecs))))
        }
    }

    var roundDurationSeconds: Int {
        blocks.reduce(0) { $0 + $1.durationSeconds }
    }

    var totalDurationSeconds: Int {
        switch repeatMode {
        case .rounds(let n): return n * roundDurationSeconds
        case .duration(let mins): return mins * 60
        }
    }

    var totalDurationMinutes: Int { totalDurationSeconds / 60 }
}

// MARK: - Block

struct BlockConfig: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var label: String = "Phase 1"
    var durationSeconds: Int = 60
    var color: BlockColor = .teal
    var soundCue: SoundCue = .bellGentle
    var hapticCue: HapticCue = .softPulse
    var visualFlash: VisualFlash = .blockColor
    /// Cue played once at the halfway point of this block. `.silent` = off.
    var midwayCue: SoundCue = .silent

    // Custom decoder so old stored configs (without midwayCue) still load.
    enum CodingKeys: String, CodingKey {
        case id, label, durationSeconds, color, soundCue, hapticCue, visualFlash, midwayCue
    }

    init(id: UUID = UUID(), label: String = "Phase 1", durationSeconds: Int = 60,
         color: BlockColor = .teal, soundCue: SoundCue = .bellGentle,
         hapticCue: HapticCue = .softPulse, visualFlash: VisualFlash = .blockColor,
         midwayCue: SoundCue = .silent) {
        self.id = id; self.label = label; self.durationSeconds = durationSeconds
        self.color = color; self.soundCue = soundCue; self.hapticCue = hapticCue
        self.visualFlash = visualFlash; self.midwayCue = midwayCue
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self,         forKey: .id)
        label           = try c.decode(String.self,       forKey: .label)
        durationSeconds = try c.decode(Int.self,          forKey: .durationSeconds)
        color           = try c.decode(BlockColor.self,   forKey: .color)
        soundCue        = try c.decode(SoundCue.self,     forKey: .soundCue)
        hapticCue       = try c.decode(HapticCue.self,    forKey: .hapticCue)
        visualFlash     = try c.decode(VisualFlash.self,  forKey: .visualFlash)
        midwayCue       = try c.decodeIfPresent(SoundCue.self, forKey: .midwayCue) ?? .silent
    }
}

// MARK: - Enums

enum Category: String, Codable, CaseIterable, Identifiable {
    case mind, physical, productivity
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .mind:         return NSLocalizedString("Mind", comment: "")
        case .physical:     return NSLocalizedString("Body", comment: "")
        case .productivity: return NSLocalizedString("Productivity", comment: "")
        }
    }
}

enum RepeatMode: Codable, Equatable {
    case rounds(Int)
    case duration(minutes: Int)

    enum CodingKeys: String, CodingKey { case type, value }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        let value = try c.decode(Int.self, forKey: .value)
        self = type == "rounds" ? .rounds(value) : .duration(minutes: value)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .rounds(let n):
            try c.encode("rounds", forKey: .type)
            try c.encode(n, forKey: .value)
        case .duration(let m):
            try c.encode("duration", forKey: .type)
            try c.encode(m, forKey: .value)
        }
    }
}

enum VoiceGender: String, Codable {
    case female, male
    var displayName: String { rawValue.capitalized }
}

enum SoundCue: String, Codable, CaseIterable, Identifiable {
    // ── Audio-file cues ─────────────────────────────────────────────
    case beacon      = "Beacon"
    case beeps       = "Beeps"
    case bellGentle  = "Bell Gentle"
    case bellReverb  = "Bell Reverb"
    case bell        = "Bell"
    case bleep       = "Bleep"
    case boxingBell  = "Boxing Bell"
    case gong        = "Gong"
    case sonarHigh   = "Sonar High"
    case sonarLow    = "Sonar Low"
    case sonarPing   = "Sonar Ping"
    case tick        = "Tick"
    case tock        = "Tock"
    case silent
    // ── TTS voice cues — speak the block's label name ───────────────
    case voiceLabelFemale = "voiceLabelFemale"
    case voiceLabelMale   = "voiceLabelMale"
    // ── Protocol-specific pre-recorded voice cues (not shown in picker)
    case voiceMaleRunning   = "Voice_Male_Running"
    case voiceMaleWalking   = "Voice_Male_Walking"
    case voiceMaleWarmingUp = "Voice_Male_Warming-up"
    case voiceMaleHalfway   = "Voice_Male_You're Halfway through"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .silent:             return NSLocalizedString("Silent", comment: "")
        case .voiceLabelFemale:   return NSLocalizedString("Female voice", comment: "")
        case .voiceLabelMale:     return NSLocalizedString("Male voice", comment: "")
        case .voiceMaleRunning:   return NSLocalizedString("Voice: Running", comment: "")
        case .voiceMaleWalking:   return NSLocalizedString("Voice: Walking", comment: "")
        case .voiceMaleWarmingUp: return NSLocalizedString("Voice: Warming up", comment: "")
        case .voiceMaleHalfway:   return NSLocalizedString("Voice: Halfway", comment: "")
        default:                  return rawValue
        }
    }

    /// nil for cues that have no audio file (silent, TTS voice labels).
    var filename: String? {
        switch self {
        case .silent, .voiceLabelFemale, .voiceLabelMale: return nil
        default: return rawValue
        }
    }

    var fileExtension: String {
        switch self {
        case .beeps, .bellGentle, .bellReverb, .bleep,
             .voiceMaleRunning, .voiceMaleWalking, .voiceMaleWarmingUp,
             .voiceMaleHalfway: return "mp3"
        default: return "wav"
        }
    }

    /// Returns the gender for TTS voice-label cues; nil for all other cues.
    var voiceLabelGender: VoiceGender? {
        switch self {
        case .voiceLabelFemale: return .female
        case .voiceLabelMale:   return .male
        default:                return nil
        }
    }

    /// True when this cue uses on-device TTS rather than an audio file.
    var isVoiceLabel: Bool { voiceLabelGender != nil }

    /// True for pre-recorded protocol voice cues that should not appear
    /// in the general block sound picker.
    var isProtocolVoice: Bool {
        switch self {
        case .voiceMaleRunning, .voiceMaleWalking, .voiceMaleWarmingUp, .voiceMaleHalfway: return true
        default: return false
        }
    }
}

enum HapticCue: String, Codable, CaseIterable, Identifiable {
    case softPulse  = "softPulse"
    case doubleTap  = "doubleTap"
    case longBuzz   = "longBuzz"
    case off        = "off"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .softPulse: return NSLocalizedString("Soft pulse", comment: "")
        case .doubleTap: return NSLocalizedString("Double tap", comment: "")
        case .longBuzz:  return NSLocalizedString("Long buzz", comment: "")
        case .off:       return NSLocalizedString("Off", comment: "")
        }
    }
}

enum VisualFlash: String, Codable, CaseIterable, Identifiable {
    case blockColor       = "blockColor"
    case flashlight       = "flashlight"
    case flashlightDouble = "flashlightDouble"
    case flashlightLong   = "flashlightLong"
    case none             = "none"

    var id: String { rawValue }

    /// Tolerant decoding: values from a newer app version fall back to .none
    /// instead of failing the whole TimerConfig decode (e.g. on a stale Watch build).
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = VisualFlash(rawValue: raw) ?? .none
    }

    var displayName: String {
        switch self {
        case .blockColor:       return NSLocalizedString("Block color", comment: "")
        case .flashlight:       return NSLocalizedString("Flashlight", comment: "")
        case .flashlightDouble: return NSLocalizedString("Double flashlight", comment: "")
        case .flashlightLong:   return NSLocalizedString("Long flashlight", comment: "")
        case .none:             return NSLocalizedString("No flash", comment: "")
        }
    }
}

// MARK: - Announcement Cue (opening / closing sound)

enum AnnouncementCue: Codable, Equatable {
    case none
    case voice(VoiceGender)
    case sound(SoundCue)

    enum CodingKeys: String, CodingKey { case type, value }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "voice":
            let raw = try c.decodeIfPresent(String.self, forKey: .value) ?? "female"
            self = .voice(VoiceGender(rawValue: raw) ?? .female)
        case "sound":
            let raw = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
            self = .sound(SoundCue(rawValue: raw) ?? .bellGentle)
        default:
            self = .none
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try c.encode("none", forKey: .type)
        case .voice(let gender):
            try c.encode("voice", forKey: .type)
            try c.encode(gender.rawValue, forKey: .value)
        case .sound(let cue):
            try c.encode("sound", forKey: .type)
            try c.encode(cue.rawValue, forKey: .value)
        }
    }

    var displayName: String {
        switch self {
        case .none:              return NSLocalizedString("Off", comment: "")
        case .voice(.female):   return NSLocalizedString("Female voice", comment: "")
        case .voice(.male):     return NSLocalizedString("Male voice", comment: "")
        case .sound(let cue):   return cue.displayName
        }
    }
}

// MARK: - Voice Announcement

enum VoiceAnnouncement {
    case start(VoiceGender)
    case finish(VoiceGender)

    /// The associated gender — used by VoiceEngine to pick the right TTS voice.
    var gender: VoiceGender {
        switch self {
        case .start(let g), .finish(let g): return g
        }
    }

    /// Text spoken by AVSpeechSynthesizer (used when useSpeechSynthesizer = true).
    var spokenText: String {
        switch self {
        case .start:  return "Your session is starting. Let's go."
        case .finish: return "Session complete. Well done."
        }
    }

    /// Filename for the pre-recorded MP3 fallback (used when useSpeechSynthesizer = false).
    var filename: String {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        switch lang {
        case "de":
            switch self {
            case .start(.female):  return "DE_Voice_Female_Start"
            case .start(.male):    return "DE_Voice_Male_Start"
            case .finish(.female): return "DE_Voice_Female_Finish"
            case .finish(.male):   return "DE_Voice_Male_Finish"
            }
        case "es":
            switch self {
            case .start(.female):  return "ES_Voice_Female_Start"
            case .start(.male):    return "ES_Voice_Male_Start"
            case .finish(.female): return "ES_Voice_Female_Finish"
            case .finish(.male):   return "ES_Voice_Male_Finish"
            }
        case "fr":
            switch self {
            case .start(.female):  return "FR_Voice_Female_Start"
            case .start(.male):    return "FR_Voice_Male_Start"
            case .finish(.female): return "FR_Voice_Female_Finish"
            case .finish(.male):   return "FR_Voice_Male_Finish"
            }
        default:
            let n = Int.random(in: 1...7)
            switch self {
            case .start(.female):  return "Voice_Female_Start_\(n)"
            case .start(.male):    return "Voice_Male_Start_\(n)"
            case .finish(.female): return "Voice_Female_Finish_\(n)"
            case .finish(.male):   return "Voice_Male_Finish_\(n)"
            }
        }
    }
}
