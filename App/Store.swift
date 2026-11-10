import Foundation
import GameCore

enum Store {
    private static let key = "inflagyoza.save.v1"

    static func load() -> SaveData {
        SaveData.decoded(from: UserDefaults.standard.data(forKey: key))
    }

    static func save(_ data: SaveData) {
        UserDefaults.standard.set(data.encoded(), forKey: key)
    }
}
