import AVFoundation

/// The one audio session for read-aloud and sound effects. `.playback`, so a
/// child hears the questions even with the iPad in silent mode (read-aloud
/// and sounds each have their own switch in the grown-up area); mixes with
/// other audio instead of stopping it.
enum AudioSession {
    /// Called before every sound: cheap, and re-activates after an interruption
    /// (a call, Siri) has deactivated the session.
    static func activate() {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback || session.mode != .spokenAudio {
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
        }
        try? session.setActive(true)
    }
}
