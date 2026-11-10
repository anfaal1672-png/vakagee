import UIKit

enum Haptics {
    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private static let noticeGen = UINotificationFeedbackGenerator()

    static func light() { lightGen.impactOccurred() }
    static func medium() { mediumGen.impactOccurred() }
    static func heavy() { heavyGen.impactOccurred() }
    static func success() { noticeGen.notificationOccurred(.success) }
    static func error() { noticeGen.notificationOccurred(.error) }
}
