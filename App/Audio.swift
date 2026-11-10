import AVFoundation

enum Sfx: CaseIterable {
    case tap, start, good, big, bad, coin, glitch, unit, hit, win, lose, negative, nan, boss
}

/// 効果音と BGM をすべてコードで合成して鳴らす。音声ファイルは 1 つも使っていない。
final class AudioEngine {
    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let bgm = AVAudioPlayerNode()
    private let varispeed = AVAudioUnitVarispeed()
    private var voices: [AVAudioPlayerNode] = []
    private var voiceIndex = 0
    private let sampleRate: Double = 44100
    private let format: AVAudioFormat
    private var sfx: [Sfx: AVAudioPCMBuffer] = [:]
    private var bgmBuffer: AVAudioPCMBuffer?
    private var prepared = false

    var enabled = true {
        didSet {
            guard enabled != oldValue else { return }
            if enabled { resume() } else { pause() }
        }
    }

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    }

    // MARK: - 制御

    func start() {
        if !prepared { prepare() }
        guard enabled else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [])
            try session.setActive(true)
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
        } catch {
            return
        }
        if !bgm.isPlaying, let buffer = bgmBuffer {
            bgm.stop()
            bgm.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            bgm.play()
        }
    }

    func resume() {
        start()
    }

    func pause() {
        guard prepared else { return }
        bgm.stop()
        for v in voices { v.stop() }
        engine.pause()
    }

    func play(_ sound: Sfx) {
        guard enabled, prepared, engine.isRunning, let buffer = sfx[sound] else { return }
        let voice = voices[voiceIndex]
        voiceIndex = (voiceIndex + 1) % voices.count
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !voice.isPlaying { voice.play() }
    }

    /// BGM の再生速度(裏世界では遅く、NaN では速く)
    func setBGMRate(_ rate: Float) {
        varispeed.rate = rate
    }

    // MARK: - 準備

    private func prepare() {
        prepared = true
        engine.attach(bgm)
        engine.attach(varispeed)
        engine.connect(bgm, to: varispeed, format: format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: format)
        bgm.volume = 0.5
        for _ in 0..<6 {
            let v = AVAudioPlayerNode()
            engine.attach(v)
            engine.connect(v, to: engine.mainMixerNode, format: format)
            v.volume = 0.9
            voices.append(v)
        }
        engine.mainMixerNode.outputVolume = 0.85
        buildSfx()
        bgmBuffer = buildBGM()

        // イヤホンの抜き差しなどでエンジンが止まったら鳴らし直す
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.bgm.stop()
            self.start()
        }
    }

    // MARK: - 合成

    private enum Wave { case square, sine, tri, saw, noise }

    private struct Seg {
        var f0: Double
        var f1: Double
        var dur: Double
        var wave: Wave
        var vol: Double
        var decay: Double = 3.0
    }

    private func midi(_ note: Int) -> Double {
        440.0 * pow(2.0, Double(note - 69) / 12.0)
    }

    private func render(_ segs: [Seg]) -> AVAudioPCMBuffer? {
        var samples: [Float] = []
        var phase = 0.0
        var seed: UInt32 = 22222
        let edge = 0.004 * sampleRate
        for s in segs {
            let n = max(1, Int(s.dur * sampleRate))
            for i in 0..<n {
                let t = Double(i) / Double(n)
                let f = s.f0 + (s.f1 - s.f0) * t
                phase += f / sampleRate
                if phase >= 1 { phase -= floor(phase) }
                var v = 0.0
                switch s.wave {
                case .square: v = phase < 0.5 ? 1 : -1
                case .sine: v = sin(2.0 * Double.pi * phase)
                case .tri: v = 4.0 * abs(phase - 0.5) - 1.0
                case .saw: v = 2.0 * phase - 1.0
                case .noise:
                    seed = seed &* 1664525 &+ 1013904223
                    v = Double(seed >> 16) / 32768.0 - 1.0
                }
                let attack = min(1.0, Double(i) / edge)
                let release = min(1.0, Double(n - i) / edge)
                let env = attack * release * exp(-s.decay * t)
                samples.append(Float(v * env * s.vol))
            }
        }
        return makeBuffer(samples)
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(samples.count)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<samples.count {
            channel[i] = max(-1, min(1, samples[i]))
        }
        return buffer
    }

    private func notes(_ list: [Int], dur: Double, wave: Wave, vol: Double, decay: Double = 2.5) -> [Seg] {
        list.map { Seg(f0: midi($0), f1: midi($0), dur: dur, wave: wave, vol: vol, decay: decay) }
    }

    private func buildSfx() {
        sfx[.tap] = render([Seg(f0: 900, f1: 1300, dur: 0.05, wave: .square, vol: 0.25)])
        sfx[.start] = render(notes([60, 67, 72, 79], dur: 0.07, wave: .square, vol: 0.28))
        sfx[.good] = render([
            Seg(f0: 520, f1: 780, dur: 0.06, wave: .square, vol: 0.3),
            Seg(f0: 780, f1: 1560, dur: 0.09, wave: .square, vol: 0.3)
        ])
        sfx[.big] = render(notes([72, 76, 79, 84, 88], dur: 0.05, wave: .square, vol: 0.32))
        sfx[.bad] = render([
            Seg(f0: 220, f1: 110, dur: 0.12, wave: .saw, vol: 0.4, decay: 1.0),
            Seg(f0: 110, f1: 60, dur: 0.16, wave: .saw, vol: 0.4, decay: 2.0)
        ])
        sfx[.coin] = render([
            Seg(f0: 1318, f1: 1318, dur: 0.05, wave: .square, vol: 0.25, decay: 1.0),
            Seg(f0: 1760, f1: 1760, dur: 0.14, wave: .square, vol: 0.25, decay: 4.0)
        ])
        sfx[.glitch] = render([
            Seg(f0: 0, f1: 0, dur: 0.04, wave: .noise, vol: 0.35, decay: 0.5),
            Seg(f0: 1900, f1: 90, dur: 0.05, wave: .square, vol: 0.3, decay: 0.5),
            Seg(f0: 0, f1: 0, dur: 0.03, wave: .noise, vol: 0.35, decay: 0.5),
            Seg(f0: 140, f1: 2400, dur: 0.06, wave: .saw, vol: 0.3, decay: 0.5),
            Seg(f0: 0, f1: 0, dur: 0.05, wave: .noise, vol: 0.3, decay: 2.0)
        ])
        sfx[.unit] = render(notes([67, 72, 76, 79, 84, 84], dur: 0.08, wave: .square, vol: 0.32, decay: 1.5))
        sfx[.hit] = render([
            Seg(f0: 0, f1: 0, dur: 0.05, wave: .noise, vol: 0.6, decay: 2.0),
            Seg(f0: 160, f1: 35, dur: 0.3, wave: .sine, vol: 0.9, decay: 3.0)
        ])
        sfx[.win] = render(
            notes([60, 64, 67, 72, 67, 72, 76], dur: 0.09, wave: .square, vol: 0.33, decay: 1.2)
            + [Seg(f0: midi(84), f1: midi(84), dur: 0.6, wave: .square, vol: 0.33, decay: 2.5)]
        )
        sfx[.lose] = render([
            Seg(f0: midi(58), f1: midi(57), dur: 0.28, wave: .saw, vol: 0.38, decay: 0.6),
            Seg(f0: midi(57), f1: midi(56), dur: 0.28, wave: .saw, vol: 0.38, decay: 0.6),
            Seg(f0: midi(56), f1: midi(55), dur: 0.28, wave: .saw, vol: 0.38, decay: 0.6),
            Seg(f0: midi(55), f1: midi(49), dur: 0.8, wave: .saw, vol: 0.38, decay: 1.6)
        ])
        sfx[.negative] = render([
            Seg(f0: 880, f1: 55, dur: 0.5, wave: .saw, vol: 0.4, decay: 0.8),
            Seg(f0: 55, f1: 110, dur: 0.25, wave: .square, vol: 0.35, decay: 2.0)
        ])
        sfx[.nan] = render([
            Seg(f0: 2000, f1: 2000, dur: 0.04, wave: .square, vol: 0.3, decay: 0.2),
            Seg(f0: 150, f1: 150, dur: 0.04, wave: .square, vol: 0.3, decay: 0.2),
            Seg(f0: 1200, f1: 1200, dur: 0.04, wave: .square, vol: 0.3, decay: 0.2),
            Seg(f0: 0, f1: 0, dur: 0.06, wave: .noise, vol: 0.35, decay: 0.2),
            Seg(f0: 300, f1: 3000, dur: 0.12, wave: .square, vol: 0.3, decay: 0.5),
            Seg(f0: 90, f1: 90, dur: 0.2, wave: .square, vol: 0.3, decay: 2.5)
        ])
        sfx[.boss] = render([
            Seg(f0: 70, f1: 70, dur: 0.18, wave: .saw, vol: 0.5, decay: 1.0),
            Seg(f0: 0, f1: 0, dur: 0.04, wave: .sine, vol: 0, decay: 1.0),
            Seg(f0: 70, f1: 70, dur: 0.18, wave: .saw, vol: 0.5, decay: 1.0),
            Seg(f0: 0, f1: 0, dur: 0.04, wave: .sine, vol: 0, decay: 1.0),
            Seg(f0: 93, f1: 93, dur: 0.4, wave: .saw, vol: 0.5, decay: 1.5)
        ])
    }

    /// 能天気な 5 音音階のループ(4 小節)
    private func buildBGM() -> AVAudioPCMBuffer? {
        let step = 60.0 / 152.0 / 4.0
        let stepFrames = Int(step * sampleRate)
        let melody: [Int] = [
            72, -1, 74, 76, 79, -1, 76, -1, 81, -1, 79, 76, 74, -1, 72, -1,
            76, -1, 79, 81, 84, -1, 81, -1, 79, -1, 76, 74, 76, -1, -1, -1,
            72, -1, 74, 76, 79, -1, 76, -1, 81, -1, 84, 81, 79, -1, 76, -1,
            74, 74, 76, 74, 72, -1, 69, -1, 72, -1, -1, 72, 72, -1, -1, -1
        ]
        let roots: [Int] = [48, 45, 41, 43]
        var mix = [Float](repeating: 0, count: stepFrames * melody.count)

        func add(_ start: Int, _ frames: Int, _ gen: (Int, Double) -> Double) {
            guard frames > 0 else { return }
            for i in 0..<frames {
                let idx = start + i
                if idx >= mix.count { break }
                mix[idx] += Float(gen(i, Double(i) / Double(frames)))
            }
        }

        var seed: UInt32 = 777
        for s in 0..<melody.count {
            let start = s * stepFrames

            // メロディ(矩形波)
            let note = melody[s]
            if note >= 0 {
                let f = midi(note)
                let len = Int(Double(stepFrames) * 1.7)
                add(start, len) { i, t in
                    let ph = (f * Double(i) / self.sampleRate).truncatingRemainder(dividingBy: 1)
                    let attack = min(1.0, Double(i) / 120.0)
                    return (ph < 0.35 ? 1.0 : -1.0) * 0.085 * attack * exp(-3.0 * t)
                }
            }

            // ベース(三角波、オクターブで跳ねる)
            if s % 2 == 0 {
                let root = roots[s / 16]
                let f = midi((s / 2) % 2 == 0 ? root : root + 12)
                let len = Int(Double(stepFrames) * 1.8)
                add(start, len) { i, t in
                    let ph = (f * Double(i) / self.sampleRate).truncatingRemainder(dividingBy: 1)
                    let attack = min(1.0, Double(i) / 120.0)
                    return (4.0 * abs(ph - 0.5) - 1.0) * 0.2 * attack * exp(-2.0 * t)
                }
            }

            // キック(4 つ打ち)
            if s % 4 == 0 {
                let len = Int(0.12 * sampleRate)
                var ph = 0.0
                add(start, len) { _, t in
                    let f = 130.0 - 90.0 * t
                    ph += f / self.sampleRate
                    return sin(2.0 * Double.pi * ph) * 0.34 * exp(-4.0 * t)
                }
            }

            // ハイハット(裏拍)
            if s % 4 == 2 {
                let len = Int(0.03 * sampleRate)
                add(start, len) { _, t in
                    seed = seed &* 1664525 &+ 1013904223
                    return (Double(seed >> 16) / 32768.0 - 1.0) * 0.06 * exp(-5.0 * t)
                }
            }
        }
        return makeBuffer(mix)
    }
}
