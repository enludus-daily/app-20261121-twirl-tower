import AVFoundation

/// 効果音（端末の中で作る。録音したファイルは持たない）。
/// 夕暮れの空の塔：回すと石臼のようなコトッ、道がつながると風鈴、猫は小さな鳴き声＋鈴。
/// 消音スイッチに従い、ほかのアプリの音と混ぜる（.ambient）
@MainActor
final class SoundBox {
    static let shared = SoundBox()

    enum Cue: Hashable {
        case tap, tick, snap, step, connect, find, mark, far, hint, complete, page
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var prepared = false
    private let rate = 44_100.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)

    /// 音量の段階：触る 0.35・回す 0.45・歩く 0.3・つながる 0.6・見つける 0.8・解いた 0.8
    private func volume(_ cue: Cue) -> Float {
        switch cue {
        case .tap, .tick, .page: 0.35
        case .step: 0.3
        case .snap, .hint: 0.45
        case .connect, .mark, .far: 0.6
        case .find, .complete: 0.8
        }
    }

    private func prepare() -> Bool {
        if prepared { return engine.isRunning || ((try? engine.start()) != nil) }
        guard let format else { return false }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<5 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        prepared = true
        return (try? engine.start()) != nil
    }

    func play(_ cue: Cue) {
        guard prepare(), engine.isRunning else { return }
        let buffer: AVAudioPCMBuffer
        if let b = buffers[cue] {
            buffer = b
        } else {
            guard let b = make(cue) else { return }
            buffers[cue] = b
            buffer = b
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.volume = volume(cue)
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    private struct Tone {
        var freq: Double
        var amp: Double
        var decay: Double
        var delay: Double = 0
        var glide: Double? = nil  // 終わりの高さ
        var vibrato: Double = 0  // 揺れの深さ（割合）
    }

    private func make(_ cue: Cue) -> AVAudioPCMBuffer? {
        switch cue {
        case .tap:
            return render(0.07, grit: 0.12, gritDecay: 110, tones: [Tone(freq: 1250, amp: 0.2, decay: 80), Tone(freq: 430, amp: 0.3, decay: 60)])
        case .tick:
            // 回している途中の 90° ごと：小さな石のカチ
            return render(0.05, grit: 0.18, gritDecay: 160, tones: [Tone(freq: 2100, amp: 0.15, decay: 120)])
        case .snap:
            // 吸い付いて止まる：低いコトッ
            return render(0.16, grit: 0.2, gritDecay: 70, tones: [Tone(freq: 180, amp: 0.55, decay: 35, glide: 140), Tone(freq: 720, amp: 0.15, decay: 50)])
        case .step:
            return render(0.08, grit: 0.08, gritDecay: 90, tones: [Tone(freq: 340, amp: 0.25, decay: 50, glide: 300)])
        case .connect:
            // 道がつながった：風鈴が上へ
            let notes = [1568.0, 2093.0, 2637.0]
            return render(0.9, grit: 0, tones: notes.enumerated().map { i, f in Tone(freq: f, amp: 0.18, decay: 5, delay: Double(i) * 0.07) })
        case .find:
            // 猫：短い「にゃ」（上がって下がる）＋鈴
            return render(0.7, grit: 0.02, gritDecay: 30, tones: [
                Tone(freq: 560, amp: 0.35, decay: 6, glide: 780, vibrato: 0.03),
                Tone(freq: 1120, amp: 0.12, decay: 7, glide: 1560, vibrato: 0.03),
                Tone(freq: 2349, amp: 0.16, decay: 6, delay: 0.18),
            ])
        case .mark:
            return render(0.5, grit: 0, tones: [Tone(freq: 1174.7, amp: 0.25, decay: 7), Tone(freq: 1760, amp: 0.08, decay: 9)])
        case .far:
            // 届かない：低いポスッ
            return render(0.25, grit: 0.1, gritDecay: 35, tones: [Tone(freq: 210, amp: 0.4, decay: 18, glide: 160)])
        case .hint:
            return render(0.45, grit: 0, tones: [Tone(freq: 987.8, amp: 0.22, decay: 8), Tone(freq: 1318.5, amp: 0.22, decay: 8, delay: 0.12)])
        case .complete:
            // 塔を解いた：灯りがともる和音
            let notes = [659.3, 830.6, 987.8, 1318.5]
            return render(1.8, grit: 0.02, gritDecay: 4, tones: notes.enumerated().flatMap { i, f in
                [Tone(freq: f, amp: 0.26, decay: 2.2, delay: Double(i) * 0.14), Tone(freq: f * 2, amp: 0.05, decay: 4, delay: Double(i) * 0.14)]
            })
        case .page:
            return render(0.1, grit: 0.25, gritDecay: 50, tones: [])
        }
    }

    private func render(_ seconds: Double, grit: Double, gritDecay: Double = 60, tones: [Tone]) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let frames = AVAudioFrameCount(seconds * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var rng = SeededRNG(seed: 21)
        var phases = Array(repeating: 0.0, count: tones.count)
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            var v = 0.0
            for (k, p) in tones.enumerated() where t >= p.delay {
                let local = t - p.delay
                var f = p.freq
                if let to = p.glide {
                    // 上がって戻る形（にゃ）にするため、前半で上がり後半で少し戻る
                    let x = min(1, local / max(0.01, seconds - p.delay))
                    f = p.freq + (to - p.freq) * sin(.pi * min(1, x * 1.6) / 2)
                }
                if p.vibrato > 0 { f *= 1 + p.vibrato * sin(2 * .pi * 7 * local) }
                phases[k] += 2 * .pi * f / rate
                let attack = min(1, local / 0.004)
                v += sin(phases[k]) * p.amp * exp(-local * p.decay) * attack
            }
            if grit > 0 {
                let n = Double(rng.next() % 20_000) / 10_000 - 1
                v += n * grit * exp(-t * gritDecay)
            }
            let tail = min(1, (seconds - t) / 0.01)
            data[i] = Float(max(-1, min(1, v * tail)))
        }
        return buffer
    }
}
