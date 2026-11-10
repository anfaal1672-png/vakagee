import XCTest
@testable import GameCore

final class JPNumberTests: XCTestCase {
    func testSmallNumbers() {
        XCTAssertEqual(JPNumber.format(0), "0")
        XCTAssertEqual(JPNumber.format(7), "7")
        XCTAssertEqual(JPNumber.format(9999), "9999")
        XCTAssertEqual(JPNumber.format(-42), "-42")
    }

    func testUnits() {
        XCTAssertEqual(JPNumber.format(10000), "1万")
        XCTAssertEqual(JPNumber.format(12345), "1.23万")
        XCTAssertEqual(JPNumber.format(123456), "12.3万")
        XCTAssertEqual(JPNumber.format(1234567), "123万")
        XCTAssertEqual(JPNumber.format(1e8), "1億")
        XCTAssertEqual(JPNumber.format(2.5e12), "2.5兆")
        XCTAssertEqual(JPNumber.format(-3e16), "-3京")
        XCTAssertEqual(JPNumber.format(1e68), "1無量大数")
    }

    func testEveryUnitBoundaryIsReadable() {
        for i in 1..<JPNumber.units.count {
            let v = pow(10.0, Double(i * 4))
            let s = JPNumber.format(v)
            XCTAssertTrue(s.hasSuffix(JPNumber.units[i]), "\(v) -> \(s)")
            XCTAssertEqual(JPNumber.unitIndex(v * 1.5), i)
        }
    }

    func testInfinityAndNaN() {
        XCTAssertEqual(JPNumber.format(.nan), "NaN")
        XCTAssertEqual(JPNumber.format(.infinity), "∞")
        XCTAssertEqual(JPNumber.format(1e75), "∞")
        XCTAssertEqual(JPNumber.format(-1e75), "-∞")
    }
}

final class GameRulesTests: XCTestCase {
    func testBasicOps() {
        XCTAssertEqual(GameRules.apply(.add(5), to: 10), 15)
        XCTAssertEqual(GameRules.apply(.sub(3), to: 10), 7)
        XCTAssertEqual(GameRules.apply(.mul(4), to: 10), 40)
        XCTAssertEqual(GameRules.apply(.div(3), to: 10), 3)
        XCTAssertEqual(GameRules.apply(.square, to: 12), 144)
        XCTAssertEqual(GameRules.apply(.sqrt, to: 17), 4)
        XCTAssertEqual(GameRules.apply(.negate, to: 9), -9)
    }

    func testCapNeverOverflows() {
        var c = 1e70
        for _ in 0..<10 { c = GameRules.apply(.square, to: c) }
        XCTAssertEqual(c, GameRules.countCap)
        XCTAssertEqual(JPNumber.format(c), "∞")
    }

    // --- ここから下は「わざと仕込んだバグ」が直されていないことを確認するテスト ---

    func testBugNegativeWorldIsAllowed() {
        let c = GameRules.apply(.sub(30), to: 10)
        XCTAssertEqual(c, -20)
        XCTAssertFalse(GameRules.isDead(c), "マイナスは全滅ではない(裏世界)")
    }

    func testBugOnlyExactZeroIsDeath() {
        XCTAssertTrue(GameRules.isDead(GameRules.apply(.sub(10), to: 10)))
        XCTAssertTrue(GameRules.isDead(GameRules.apply(.div(2), to: 1)))
        XCTAssertTrue(GameRules.isDead(GameRules.apply(.div(4), to: -3)))
        XCTAssertFalse(GameRules.isDead(.nan))
    }

    func testBugEnemiesMakeYouStrongerInNegativeWorld() {
        let c = GameRules.hitEnemy(count: -50, enemy: 100)
        XCTAssertEqual(c, -150)
        XCTAssertTrue(GameRules.beatsBoss(count: c, bossHP: 120))
    }

    func testBugBossComparesMagnitude() {
        XCTAssertTrue(GameRules.beatsBoss(count: 100, bossHP: 100))
        XCTAssertFalse(GameRules.beatsBoss(count: 99, bossHP: 100))
        XCTAssertTrue(GameRules.beatsBoss(count: -1000, bossHP: 100))
        XCTAssertFalse(GameRules.beatsBoss(count: -5, bossHP: 100))
    }

    func testBugSqrtOfNegativeBecomesNaN() {
        let c = GameRules.apply(.sqrt, to: -16)
        XCTAssertTrue(c.isNaN)
        // 一度 NaN になったら何をしても NaN
        XCTAssertTrue(GameRules.apply(.add(100), to: c).isNaN)
        XCTAssertTrue(GameRules.apply(.mul(0.5), to: c).isNaN)
        XCTAssertTrue(GameRules.hitEnemy(count: c, enemy: 999).isNaN)
        XCTAssertFalse(GameRules.isDead(c))
    }

    func testBugNaNAlwaysBeatsBossButEarnsNothing() {
        XCTAssertTrue(GameRules.beatsBoss(count: .nan, bossHP: 1e60))
        XCTAssertEqual(GameRules.reward(level: 5, count: .nan, bossHP: 100, maxCombo: 9), 0)
    }

    func testBugSquareEscapesNegativeWorld() {
        XCTAssertEqual(GameRules.apply(.square, to: -7), 49)
    }

    func testBugWrapDupeDoubles() {
        XCTAssertEqual(GameRules.wrapDupe(21), 42)
        XCTAssertEqual(GameRules.wrapDupe(-21), -42)
        XCTAssertTrue(GameRules.wrapDupe(.nan).isNaN)
    }

    func testBugCoinTapBonus() {
        XCTAssertEqual(GameRules.coinTapBonus(reward: 100, taps: 0), 0)
        XCTAssertEqual(GameRules.coinTapBonus(reward: 100, taps: 4), 20)
        XCTAssertEqual(GameRules.coinTapBonus(reward: 3, taps: 2), 2)
        // 連打しすぎても上限がある
        XCTAssertEqual(GameRules.coinTapBonus(reward: 100, taps: 9999), 150)
    }

    // --- 報酬・コンボ ---

    func testRewardGrowsWithOverkillAndCombo() {
        let base = GameRules.reward(level: 3, count: 100, bossHP: 100, maxCombo: 0)
        let over = GameRules.reward(level: 3, count: 100000, bossHP: 100, maxCombo: 0)
        let combo = GameRules.reward(level: 3, count: 100, bossHP: 100, maxCombo: 5)
        XCTAssertEqual(base, 35)
        XCTAssertGreaterThan(over, base)
        XCTAssertGreaterThan(combo, base)
        // どれだけインフレしてもクラッシュせず有限
        let huge = GameRules.reward(level: 999, count: GameRules.countCap, bossHP: 1, maxCombo: 999)
        XCTAssertGreaterThan(huge, 0)
        XCTAssertLessThan(huge, 10_000_000)
    }

    func testCombo() {
        XCTAssertEqual(GameRules.nextCombo(current: 2, before: 10, after: 30), 3)
        XCTAssertEqual(GameRules.nextCombo(current: 2, before: 10, after: 5), 0)
        // 裏世界では「より負に」がコンボ継続
        XCTAssertEqual(GameRules.nextCombo(current: 1, before: -10, after: -90), 2)
        XCTAssertEqual(GameRules.nextCombo(current: 4, before: 10, after: .nan), 5)
        XCTAssertEqual(GameRules.nextCombo(current: 4, before: .nan, after: .nan), 5)
    }

    func testMysteryResolvesToConcreteOp() {
        var rng = SeededRNG(seed: 1)
        var seen = Set<String>()
        for _ in 0..<2000 {
            let op = GameRules.resolveMystery(&rng)
            XCTAssertNotEqual(op, .mystery)
            seen.insert(op.label)
        }
        XCTAssertEqual(seen.count, 5, "5 種類すべて出る")
    }
}

final class LevelGeneratorTests: XCTestCase {
    func testDeterministic() {
        XCTAssertEqual(LevelGenerator.make(level: 7), LevelGenerator.make(level: 7))
        XCTAssertNotEqual(LevelGenerator.make(level: 7).rows, LevelGenerator.make(level: 8).rows)
    }

    func testEveryLevelIsWinnableByObviousChoices() {
        for level in 1...300 {
            let spec = LevelGenerator.make(level: level)
            XCTAssertEqual(spec.rows.count, LevelGenerator.rowCount(level: level))
            var c = spec.startCount
            for row in spec.rows {
                c = LevelGenerator.greedyStep(row: row, count: c)
                XCTAssertTrue(c.isFinite && c >= 1, "level \(level) greedy died: \(c)")
            }
            XCTAssertEqual(c, spec.greedyResult)
            XCTAssertGreaterThanOrEqual(spec.bossHP, 1)
            XCTAssertTrue(GameRules.beatsBoss(count: c, bossHP: spec.bossHP), "level \(level) is unwinnable")
        }
    }

    func testAlwaysChoosingWorstUsuallyLosesOrBreaksTheGame() {
        // 何も考えずに左だけ通ると、少なくともどこかのレベルでは負ける(= ゲームになっている)
        var losses = 0
        for level in 1...60 {
            let spec = LevelGenerator.make(level: level)
            var c = spec.startCount
            for row in spec.rows {
                if case .gates(let l, _) = row { c = GameRules.apply(l, to: c) }
                if case .enemy(let side, let v) = row, side == .left { c = GameRules.hitEnemy(count: c, enemy: v) }
            }
            if GameRules.isDead(c) || !GameRules.beatsBoss(count: c, bossHP: spec.bossHP) { losses += 1 }
        }
        XCTAssertGreaterThan(losses, 15)
    }

    func testFirstRowIsFriendly() {
        for level in 1...50 {
            guard case .gates(let l, let r) = LevelGenerator.make(level: level).rows[0] else {
                return XCTFail("first row must be gates")
            }
            XCTAssertEqual(l.kind, .good)
            XCTAssertEqual(r.kind, .good)
        }
    }

    func testProgressionGetsHarderAndSillier() {
        XCTAssertEqual(LevelGenerator.startCount(level: 1), 1)
        XCTAssertGreaterThan(LevelGenerator.startCount(level: 10), 100_000)
        XCTAssertGreaterThan(LevelGenerator.make(level: 30).bossHP, LevelGenerator.make(level: 3).bossHP)
        XCTAssertGreaterThan(LevelGenerator.make(level: 12).speed, LevelGenerator.make(level: 1).speed)
        // 序盤に理不尽なゲートは出ない
        for level in 1...2 {
            for row in LevelGenerator.make(level: level).rows {
                if case .gates(let l, let r) = row {
                    XCTAssertFalse([l, r].contains(.nan))
                    XCTAssertFalse([l, r].contains(.mystery))
                    XCTAssertFalse([l, r].contains(.sqrt))
                }
            }
        }
        // 後半には出る
        var special = 0
        for level in 6...40 {
            for row in LevelGenerator.make(level: level).rows {
                guard case .gates(let l, let r) = row else { continue }
                let specials: [GateOp] = [.nan, .mystery, .sqrt, .square]
                if specials.contains(l) || specials.contains(r) { special += 1 }
            }
        }
        XCTAssertGreaterThan(special, 20)
    }

    func testEnemyRowsNeverComeBackToBack() {
        for level in 1...200 {
            var previousWasEnemy = false
            for row in LevelGenerator.make(level: level).rows {
                var isEnemy = false
                if case .enemy = row { isEnemy = true }
                XCTAssertFalse(isEnemy && previousWasEnemy, "level \(level)")
                previousWasEnemy = isEnemy
            }
        }
    }

    func testBossNamesCycleForever() {
        XCTAssertEqual(LevelGenerator.make(level: 1).bossEmoji, "🐔")
        XCTAssertEqual(LevelGenerator.make(level: 11).bossEmoji, "🐔")
        XCTAssertTrue(LevelGenerator.make(level: 11).bossName.hasSuffix("Mk.2"))
        XCTAssertFalse(LevelGenerator.make(level: 100000).bossName.isEmpty)
    }
}

final class SaveDataTests: XCTestCase {
    func testRoundTrip() {
        var s = SaveData()
        s.coins = 1234
        s.level = 9
        s.bestCount = 5e20
        XCTAssertEqual(SaveData.decoded(from: s.encoded()), s)
    }

    func testCorruptDataFallsBackToDefaults() {
        XCTAssertEqual(SaveData.decoded(from: nil), SaveData())
        XCTAssertEqual(SaveData.decoded(from: Data("こわれたデータ".utf8)), SaveData())
    }

    func testBuyAndSelect() {
        var s = SaveData()
        XCTAssertEqual(s.buyOrSelect(skinID: "frog"), .notEnough)
        s.addCoins(500)
        XCTAssertEqual(s.buyOrSelect(skinID: "frog"), .bought)
        XCTAssertEqual(s.coins, 100)
        XCTAssertEqual(s.selectedSkin, "frog")
        XCTAssertEqual(s.buyOrSelect(skinID: "gyoza"), .selected)
        XCTAssertEqual(s.buyOrSelect(skinID: "frog"), .selected)
        XCTAssertEqual(s.coins, 100, "二重に払わない")
        XCTAssertEqual(s.buyOrSelect(skinID: "nothing"), .unknown)
    }

    func testCatalogHasEnoughSkins() {
        XCTAssertGreaterThanOrEqual(SkinCatalog.all.count, 5)
        XCTAssertEqual(Set(SkinCatalog.all.map { $0.id }).count, SkinCatalog.all.count)
        XCTAssertEqual(SkinCatalog.all[0].price, 0)
        XCTAssertEqual(SkinCatalog.skin(id: "???").id, "gyoza")
    }

    func testRecordClear() {
        var s = SaveData()
        XCTAssertTrue(s.recordClear(level: 1, count: -500))
        XCTAssertEqual(s.level, 2)
        XCTAssertEqual(s.bestCount, 500)
        XCTAssertFalse(s.recordClear(level: 2, count: .nan))
        XCTAssertEqual(s.level, 3)
        XCTAssertEqual(s.bestCount, 500)
        // 昔のレベルを遊び直しても進行は戻らない
        s.recordClear(level: 1, count: 1)
        XCTAssertEqual(s.level, 3)
    }

    func testCoinsNeverOverflow() {
        var s = SaveData()
        s.coins = Int.max - 1
        s.addCoins(100)
        XCTAssertEqual(s.coins, Int.max)
    }
}
