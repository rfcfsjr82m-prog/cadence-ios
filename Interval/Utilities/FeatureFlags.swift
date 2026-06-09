// MARK: - Feature flags
//
// Flip any flag here to instantly enable or disable an in-development feature.
// No other files need to be touched — every usage is guarded by the flag.

enum FeatureFlags {

    /// Ambient metronome: a repeating cue that fires at a fixed cadence,
    /// independently of rounds and phases, for as long as the session runs.
    static let metronome = false

}
