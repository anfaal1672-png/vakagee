import Foundation

/// ゲートの演算。
public enum GateOp: Equatable {
    case add(Double)
    case sub(Double)
    case mul(Double)
    case div(Double)
    case square
    case sqrt
    case negate
    case nan
    case mystery

    public enum Kind { case good, bad, mystery, glitch }

    /// 見た目上の分類(青 = 良い、赤 = 悪い)。
    /// 裏世界では意味が逆転するものがあるが、色は直していない。仕様です。
    public var kind: Kind {
        switch self {
        case .add, .mul, .square: return .good
        case .sub, .div, .sqrt: return .bad
        case .negate, .mystery: return .mystery
        case .nan: return .glitch
        }
    }

    public var label: String {
        switch self {
        case .add(let v): return "+" + JPNumber.format(v)
        case .sub(let v): return "−" + JPNumber.format(v)
        case .mul(let v): return "×" + JPNumber.format(v)
        case .div(let v): return "÷" + JPNumber.format(v)
        case .square: return "2乗"
        case .sqrt: return "√"
        case .negate: return "±反転"
        case .nan: return "N̷a̴N̷"
        case .mystery: return "？？？"
        }
    }
}

public enum GameRules {
    /// 数の上限。これ以上は ∞ 表示になる。
    public static let countCap: Double = 1e75

    /// ゲートを通過した後の数を返す。
    ///
    /// 【仕込みバグ】
    /// - マイナスになっても止めていない → 裏世界へ
    /// - 負の数の √ を弾いていない → NaN(数ではない何か)になる
    public static func apply(_ op: GateOp, to count: Double) -> Double {
        var r: Double
        switch op {
        case .add(let v): r = count + v
        case .sub(let v): r = count - v
        case .mul(let v): r = count * v
        case .div(let v): r = v == 0 ? count : count / v
        case .square: r = count * count
        case .sqrt: r = count.squareRoot()
        case .negate: r = -count
        case .nan: r = .nan
        case .mystery: r = count
        }
        if r.isNaN { return .nan }
        r = r.rounded(.towardZero)
        if r > countCap { r = countCap }
        if r < -countCap { r = -countCap }
        if r == 0 { r = 0 } // -0 を 0 にそろえる
        return r
    }

    /// ？？？ゲートの中身を決める。
    public static func resolveMystery(_ rng: inout SeededRNG) -> GateOp {
        let roll = rng.unit()
        if roll < 0.40 { return .mul(10) }
        if roll < 0.62 { return .div(10) }
        if roll < 0.82 { return .negate }
        if roll < 0.96 { return .square }
        return .nan
    }

    /// 敵の群れにぶつかった後の数。
    /// 【仕込みバグ】0 未満で止めていないので、引かれすぎると裏世界に落ちる。
    /// 裏世界では敵にぶつかるほど強くなる。
    public static func hitEnemy(count: Double, enemy: Double) -> Double {
        apply(.sub(enemy), to: count)
    }

    /// 全滅判定。
    /// 【仕込みバグ】「0 以下」ではなく「ちょうど 0」しか見ていない。
    public static func isDead(_ count: Double) -> Bool {
        count == 0
    }

    /// ボスに勝ったかどうか。
    /// 【仕込みバグ】絶対値で比べているので裏世界の数でも勝てる。
    /// さらに NaN は「HP より小さい」が常に偽になるため、必ず勝つ。
    public static func beatsBoss(count: Double, bossHP: Double) -> Bool {
        if abs(count) < bossHP { return false }
        return true
    }

    /// 【仕込みバグ】画面端を突き抜けると反対側から出てきて、なぜか数が 2 倍になる。
    public static func wrapDupe(_ count: Double) -> Double {
        apply(.mul(2), to: count)
    }

    /// クリア報酬のコイン。NaN はコインに換金できない。
    public static func reward(level: Int, count: Double, bossHP: Double, maxCombo: Int) -> Int {
        if count.isNaN { return 0 }
        let ratio = abs(count) / max(bossHP, 1)
        let overkill = min(10.0, log10(max(1.0, ratio)))
        let base = Double(20 + max(level, 1) * 5)
        let comboBonus = 1.0 + 0.1 * Double(min(max(maxCombo, 0), 50))
        let coins = base * (1.0 + overkill) * comboBonus
        return max(1, Int(coins.rounded()))
    }

    /// 負けたときの残念賞。
    public static func consolation(level: Int) -> Int {
        3 + max(level, 1)
    }

    /// 【仕込みバグ】リザルトでコインが増えている最中にコインを連打すると、その分だけ増える。
    public static func coinTapBonus(reward: Int, taps: Int) -> Int {
        let per = max(1, reward / 20)
        return per * min(max(taps, 0), 30)
    }

    /// コンボ: 数の「大きさ」が増えたら継続、減ったら途切れる。
    public static func nextCombo(current: Int, before: Double, after: Double) -> Int {
        if after.isNaN { return current + 1 }
        if before.isNaN { return current }
        return abs(after) > abs(before) ? current + 1 : 0
    }
}
