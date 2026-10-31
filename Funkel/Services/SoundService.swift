import AVFoundation

/// Friendly sound effects, synthesised on device: no audio files, no
/// licensing, works offline. Uses the `.ambient` session so the silent
/// switch is respected and other audio isn't interrupted.
final class SoundService {

    enum Effect: CaseIterable {
        /// Bright rising three-note chime.
        case correct
        /// Soft, low two-note "hmm". Deliberately not a buzzer.
        case gentle
        /// Little arpeggio fanfare for the end of a round.
        case finish
        /// Short bright blip: a popped balloon, a caught star, a found pair.
        case pop
    }

    struct Note {
        let frequency: Double
        let start: Double      // seconds
        let duration: Double   // seconds
        let volume: Double     // 0…1
    }

    static let sampleRate = 44_100.0

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        for effect in Effect.allCases {
            buffers[effect] = Self.render(Self.notes(for: effect), format: format)
        }
    }

    func play(_ effect: Effect) {
        guard let buffer = buffers[effect], startIfNeeded() else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    /// Starts the engine lazily, so nothing touches audio until the first sound.
    private func startIfNeeded() -> Bool {
        if engine.isRunning { return true }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    // MARK: Synthesis

    static func notes(for effect: Effect) -> [Note] {
        switch effect {
        case .correct:
            return [
                Note(frequency: 1046.5, start: 0.00, duration: 0.22, volume: 0.22),  // C6
                Note(frequency: 1318.5, start: 0.08, duration: 0.22, volume: 0.22),  // E6
                Note(frequency: 1568.0, start: 0.16, duration: 0.35, volume: 0.24),  // G6
            ]
        case .gentle:
            return [
                Note(frequency: 392.0, start: 0.00, duration: 0.22, volume: 0.14),   // G4
                Note(frequency: 329.6, start: 0.14, duration: 0.32, volume: 0.12),   // E4
            ]
        case .finish:
            return [
                Note(frequency: 523.3, start: 0.00, duration: 0.20, volume: 0.20),   // C5
                Note(frequency: 659.3, start: 0.10, duration: 0.20, volume: 0.20),   // E5
                Note(frequency: 784.0, start: 0.20, duration: 0.20, volume: 0.20),   // G5
                Note(frequency: 1046.5, start: 0.30, duration: 0.60, volume: 0.24),  // C6
            ]
        case .pop:
            return [
                Note(frequency: 880.0, start: 0.00, duration: 0.09, volume: 0.12),   // A5
                Note(frequency: 1320.0, start: 0.03, duration: 0.08, volume: 0.08),  // E6
            ]
        }
    }

    /// Mixes sine notes (plus a soft octave overtone) with a quick attack and
    /// exponential decay. Output is clamped to ±1, so it can never clip.
    static func render(_ notes: [Note], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let length = (notes.map { $0.start + $0.duration }.max() ?? 0) + 0.05
        let frameCount = AVAudioFrameCount(length * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var value = 0.0
            for note in notes where t >= note.start && t < note.start + note.duration {
                let local = t - note.start
                let attack = min(1, local / 0.008)
                let decay = exp(-4.5 * local / note.duration)
                let phase = 2 * Double.pi * note.frequency * local
                value += note.volume * attack * decay * (sin(phase) + 0.25 * sin(2 * phase))
            }
            samples[frame] = Float(max(-1, min(1, value)))
        }
        return buffer
    }
}
