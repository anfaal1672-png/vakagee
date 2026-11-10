import Foundation

public struct Skin: Equatable {
    public let id: String
    public let emoji: String
    public let name: String
    public let price: Int
}

public enum SkinCatalog {
    public static let all: [Skin] = [
        Skin(id: "gyoza", emoji: "🥟", name: "餃子", price: 0),
        Skin(id: "onigiri", emoji: "🍙", name: "おにぎり", price: 150),
        Skin(id: "frog", emoji: "🐸", name: "カエル", price: 400),
        Skin(id: "duck", emoji: "🦆", name: "アヒル", price: 900),
        Skin(id: "moai", emoji: "🗿", name: "モアイ", price: 2000),
        Skin(id: "ojisan", emoji: "👴", name: "おじさん", price: 4500),
        Skin(id: "paper", emoji: "🧻", name: "紙", price: 9000),
        Skin(id: "poop", emoji: "💩", name: "金運", price: 20000)
    ]

    public static func skin(id: String) -> Skin {
        all.first { $0.id == id } ?? all[0]
    }
}

public struct SaveData: Codable, Equatable {
    public var level: Int = 1
    public var coins: Int = 0
    public var bestCount: Double = 0
    public var bestLevel: Int = 1
    public var ownedSkins: [String] = ["gyoza"]
    public var selectedSkin: String = "gyoza"
    public var soundOn: Bool = true

    public init() {}

    public enum BuyResult: Equatable { case bought, selected, notEnough, unknown }

    /// 持っていれば選択、持っていなければ購入して選択する。
    public mutating func buyOrSelect(skinID: String) -> BuyResult {
        guard let skin = SkinCatalog.all.first(where: { $0.id == skinID }) else { return .unknown }
        if ownedSkins.contains(skinID) {
            selectedSkin = skinID
            return .selected
        }
        guard coins >= skin.price else { return .notEnough }
        coins -= skin.price
        ownedSkins.append(skinID)
        selectedSkin = skinID
        return .bought
    }

    public mutating func addCoins(_ amount: Int) {
        let (sum, overflow) = coins.addingReportingOverflow(amount)
        coins = overflow ? Int.max : max(0, sum)
    }

    /// クリア時の記録更新。新記録なら true。
    @discardableResult
    public mutating func recordClear(level cleared: Int, count: Double) -> Bool {
        level = max(level, cleared + 1)
        bestLevel = max(bestLevel, level)
        let magnitude = abs(count)
        if !magnitude.isNaN && magnitude > bestCount {
            bestCount = magnitude
            return true
        }
        return false
    }

    public func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    public static func decoded(from data: Data?) -> SaveData {
        guard let data = data, let s = try? JSONDecoder().decode(SaveData.self, from: data) else {
            return SaveData()
        }
        var fixed = s
        if fixed.level < 1 { fixed.level = 1 }
        if fixed.coins < 0 { fixed.coins = 0 }
        if !fixed.ownedSkins.contains("gyoza") { fixed.ownedSkins.insert("gyoza", at: 0) }
        if !fixed.ownedSkins.contains(fixed.selectedSkin) { fixed.selectedSkin = "gyoza" }
        if !fixed.bestCount.isFinite { fixed.bestCount = 0 }
        return fixed
    }
}
