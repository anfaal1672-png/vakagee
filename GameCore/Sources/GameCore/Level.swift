import Foundation

public enum Side: Equatable { case left, right }

public enum Row: Equatable {
    case gates(left: GateOp, right: GateOp)
    case enemy(side: Side, value: Double)
}

public struct LevelSpec: Equatable {
    public let level: Int
    public let startCount: Double
    public let rows: [Row]
    public let bossHP: Double
    /// 1 秒あたりに進む距離(ポイント)
    public let speed: Double
    /// 行と行の間隔(ポイント)
    public let rowSpacing: Double
    public let bossEmoji: String
    public let bossName: String

    /// 「良さそうな方」を選び続けたときの最終的な数。ボス HP はこれを基準に決まる。
    public let greedyResult: Double
}

public enum LevelGenerator {
    public static let bosses: [(emoji: String, name: String)] = [
        ("🐔", "怒れるニワトリ"),
        ("🦀", "横にしか動けないカニ"),
        ("🐷", "納期を守らないブタ"),
        ("🗿", "なにも考えていない石像"),
        ("🦖", "腕が短いティラノ"),
        ("🐙", "8本とも利き腕のタコ"),
        ("👽", "観光で来た宇宙人"),
        ("🤖", "電池残量3%のロボ"),
        ("🧟", "有給を使い切ったゾンビ"),
        ("🐲", "だいたい最強のドラゴン")
    ]

    public static func startCount(level: Int) -> Double {
        let lv = max(level, 1)
        let v = pow(10.0, Double(lv - 1) / 1.5).rounded(.towardZero)
        return min(max(v, 1), 1e60)
    }

    public static func rowCount(level: Int) -> Int {
        8 + min(max(level, 1), 6)
    }

    public static func make(level rawLevel: Int) -> LevelSpec {
        let level = max(rawLevel, 1)
        var rng = SeededRNG(seed: UInt64(level) &* 7919 &+ 20240229)
        let start = startCount(level: level)
        let count = rowCount(level: level)

        var rows: [Row] = []
        var greedy = start

        for i in 0..<count {
            var chosen: Row = .gates(left: .add(max(1, start)), right: .add(max(1, (start * 2))))
            var chosenGreedy = greedy
            var ok = false
            for _ in 0..<24 {
                let row = randomRow(index: i, level: level, start: start, current: greedy, rng: &rng)
                let g = greedyStep(row: row, count: greedy)
                if g.isFinite && g >= 1 {
                    chosen = row
                    chosenGreedy = g
                    ok = true
                    break
                }
            }
            if !ok {
                chosenGreedy = greedyStep(row: chosen, count: greedy)
            }
            rows.append(chosen)
            greedy = chosenGreedy
        }

        // 難易度: 最初はゆるく、レベル 10 に向けて厳しくなる
        let t = min(1.0, Double(level - 1) / 9.0)
        let factor = 0.25 + 0.45 * t
        let hp = max(1, (greedy * factor).rounded(.towardZero))
        let boss = bosses[(level - 1) % bosses.count]
        let lap = (level - 1) / bosses.count
        let name = lap == 0 ? boss.name : boss.name + " Mk." + String(lap + 1)
        let speed = 400.0 + min(Double(level), 12) * 14.0

        return LevelSpec(
            level: level,
            startCount: start,
            rows: rows,
            bossHP: hp,
            speed: speed,
            rowSpacing: 660,
            bossEmoji: boss.emoji,
            bossName: name,
            greedyResult: greedy
        )
    }

    /// 見えている情報だけで「大きくなる方」を選ぶ。敵は避ける。
    public static func greedyStep(row: Row, count: Double) -> Double {
        switch row {
        case .enemy:
            return count
        case .gates(let l, let r):
            let a = estimate(l, count)
            let b = estimate(r, count)
            return max(a, b)
        }
    }

    private static func estimate(_ op: GateOp, _ count: Double) -> Double {
        switch op {
        case .mystery:
            // 中身が分からないので最悪(÷10)を想定
            return GameRules.apply(.div(10), to: count)
        case .nan, .negate:
            return -Double.greatestFiniteMagnitude
        default:
            let r = GameRules.apply(op, to: count)
            return r.isNaN ? -Double.greatestFiniteMagnitude : r
        }
    }

    private static func roundNice(_ v: Double) -> Double {
        guard v >= 100 else { return max(1, v.rounded()) }
        let digits = floor(log10(v))
        let unit = pow(10.0, digits - 1)
        return (v / unit).rounded() * unit
    }

    private static func goodOp(level: Int, start: Double, current: Double, rng: inout SeededRNG) -> GateOp {
        let roll = rng.unit()
        if level >= 5 && roll < 0.08 && current < 1e30 { return .square }
        if roll < 0.50 {
            let base = max(start, current * 0.3)
            return .add(roundNice(max(1, base * rng.range(0.6, 3.0))))
        }
        if level >= 4 && rng.chance(0.12) { return .mul(10) }
        let maxMul = level >= 6 ? 5 : (level >= 3 ? 4 : 3)
        return .mul(Double(rng.int(2, maxMul)))
    }

    private static func badOp(level: Int, start: Double, current: Double, rng: inout SeededRNG) -> GateOp {
        let roll = rng.unit()
        if level >= 4 && roll < 0.12 { return .sqrt }
        if roll < 0.55 {
            let base = max(start, current * 0.4)
            return .sub(roundNice(max(1, base * rng.range(0.4, 2.2))))
        }
        return .div(Double(rng.int(2, level >= 5 ? 5 : 3)))
    }

    private static func randomRow(index: Int, level: Int, start: Double, current: Double, rng: inout SeededRNG) -> Row {
        // 最初の行は必ずやさしい足し算
        if index == 0 {
            let a = GateOp.add(roundNice(max(1, start * rng.range(1.0, 2.0))))
            let b = GateOp.add(roundNice(max(2, start * rng.range(2.5, 4.0))))
            return rng.chance(0.5) ? .gates(left: a, right: b) : .gates(left: b, right: a)
        }

        if level >= 2 && rng.chance(0.22) {
            let v = roundNice(max(1, max(start, current * 0.5) * rng.range(0.5, 2.5)))
            return .enemy(side: rng.chance(0.5) ? .left : .right, value: v)
        }

        var a: GateOp
        var b: GateOp
        let roll = rng.unit()
        if level >= 6 && roll < 0.05 {
            a = .nan
            b = goodOp(level: level, start: start, current: current, rng: &rng)
        } else if level >= 3 && roll < 0.16 {
            a = .mystery
            b = rng.chance(0.5)
                ? goodOp(level: level, start: start, current: current, rng: &rng)
                : badOp(level: level, start: start, current: current, rng: &rng)
        } else if roll < 0.70 {
            a = goodOp(level: level, start: start, current: current, rng: &rng)
            b = badOp(level: level, start: start, current: current, rng: &rng)
        } else if roll < 0.88 || level < 3 {
            a = goodOp(level: level, start: start, current: current, rng: &rng)
            b = goodOp(level: level, start: start, current: current, rng: &rng)
        } else {
            a = badOp(level: level, start: start, current: current, rng: &rng)
            b = badOp(level: level, start: start, current: current, rng: &rng)
        }
        if a == b { b = .add(roundNice(max(1, start * rng.range(0.5, 1.5)))) }
        return rng.chance(0.5) ? .gates(left: a, right: b) : .gates(left: b, right: a)
    }
}
