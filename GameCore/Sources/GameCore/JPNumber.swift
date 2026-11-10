import Foundation

/// 数を日本語の単位(万・億・兆 … 無量大数)で表示する。
/// インフレしすぎた数も、数ではなくなった数(NaN)もそのまま表示する。
public enum JPNumber {
    public static let units: [String] = [
        "", "万", "億", "兆", "京", "垓", "秭", "穣", "溝", "澗", "正", "載", "極",
        "恒河沙", "阿僧祇", "那由他", "不可思議", "無量大数"
    ]

    /// これ以上は数えるのをやめて ∞ と表示する。
    public static let infinityThreshold: Double = 1e72

    /// 値が属する単位の番号(0 = 単位なし、1 = 万 …)。NaN と 0 は 0。
    public static func unitIndex(_ value: Double) -> Int {
        let a = abs(value)
        if a.isNaN || a < 10000 { return 0 }
        if a.isInfinite { return units.count - 1 }
        let idx = Int(floor(log10(a) / 4.0))
        return min(max(idx, 0), units.count - 1)
    }

    public static func format(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        let sign = value < 0 ? "-" : ""
        let a = abs(value)
        if a.isInfinite || a >= infinityThreshold { return sign + "∞" }
        if a < 10000 { return sign + String(Int(a.rounded(.towardZero))) }
        var idx = unitIndex(a)
        var mantissa = a / pow(10.0, Double(idx * 4))
        // 浮動小数の誤差で 0.9999… や 10000 になった場合の補正
        if mantissa < 1 && idx > 1 { idx -= 1; mantissa = a / pow(10.0, Double(idx * 4)) }
        if mantissa >= 9999.5 && idx < units.count - 1 { idx += 1; mantissa = a / pow(10.0, Double(idx * 4)) }
        let text: String
        if mantissa < 10 {
            text = trimZeros(String(format: "%.2f", mantissa))
        } else if mantissa < 100 {
            text = trimZeros(String(format: "%.1f", mantissa))
        } else {
            text = String(format: "%.0f", mantissa)
        }
        return sign + text + units[idx]
    }

    private static func trimZeros(_ s: String) -> String {
        guard s.contains(".") else { return s }
        var out = s
        while out.hasSuffix("0") { out.removeLast() }
        if out.hasSuffix(".") { out.removeLast() }
        return out
    }
}
