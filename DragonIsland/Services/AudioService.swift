import AVFoundation
import Foundation

/// The short feedback sounds used by the island and arena.  They are generated
/// as small PCM buffers at launch, so the app ships no extra audio files.
enum GameSound: String, CaseIterable, Sendable {
    case collect, hatch, battleHit, victory
}

final class AudioService {
    static let shared = AudioService()

    private var players: [GameSound: AVAudioPlayer] = [:]
    private var didConfigureSession = false

    func play(_ sound: GameSound) {
        configureSessionIfNeeded()
        if let player = players[sound] {
            player.currentTime = 0
            player.play()
            return
        }
        guard let data = Self.wavData(for: sound),
              let player = try? AVAudioPlayer(data: data) else { return }
        player.prepareToPlay()
        players[sound] = player
        player.play()
    }

    private func configureSessionIfNeeded() {
        guard !didConfigureSession else { return }
        didConfigureSession = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    // MARK: - Synthesis

    private struct Tone {
        let frequency: Double
        let duration: Double
        let gain: Double
    }

    private static func tones(for sound: GameSound) -> [Tone] {
        switch sound {
        case .collect:
            return [Tone(frequency: 880, duration: 0.07, gain: 0.28)]
        case .hatch:
            return [
                Tone(frequency: 660, duration: 0.08, gain: 0.26),
                Tone(frequency: 880, duration: 0.08, gain: 0.26),
                Tone(frequency: 1100, duration: 0.13, gain: 0.22),
            ]
        case .battleHit:
            return [Tone(frequency: 150, duration: 0.1, gain: 0.34)]
        case .victory:
            return [
                Tone(frequency: 523, duration: 0.1, gain: 0.24),
                Tone(frequency: 659, duration: 0.1, gain: 0.24),
                Tone(frequency: 784, duration: 0.1, gain: 0.24),
                Tone(frequency: 1046, duration: 0.18, gain: 0.22),
            ]
        }
    }

    private static func wavData(for sound: GameSound) -> Data? {
        let sampleRate = 22050
        var samples: [Int16] = []
        for tone in tones(for: sound) {
            let count = max(1, Int(tone.duration * Double(sampleRate)))
            for index in 0..<count {
                let time = Double(index) / Double(sampleRate)
                let attack = min(1, time / 0.006)
                let decay = exp(-time * 5.5 / max(tone.duration, 0.03))
                let wave = sin(2 * .pi * tone.frequency * time)
                let value = max(-1, min(1, wave * attack * decay * tone.gain))
                samples.append(Int16(value * Double(Int16.max)))
            }
        }
        return makeWAV(samples: samples, sampleRate: sampleRate)
    }

    private static func makeWAV(samples: [Int16], sampleRate: Int) -> Data {
        let dataSize = samples.count * 2
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataSize), to: &data)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(1), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * 2), to: &data)
        append(UInt16(2), to: &data)
        append(UInt16(16), to: &data)
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(dataSize), to: &data)
        for sample in samples {
            append(UInt16(bitPattern: sample), to: &data)
        }
        return data
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
