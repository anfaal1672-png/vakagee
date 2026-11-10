import UIKit
import SpriteKit

final class GameViewController: UIViewController {
    private var gameScene: GameScene?

    override func loadView() {
        let v = SKView()
        v.isMultipleTouchEnabled = false
        view = v
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard gameScene == nil, let skView = view as? SKView else { return }
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        // 横幅を常に 390 として扱い、縦は端末の比率に合わせる
        let logicalWidth: CGFloat = 390
        let scale = logicalWidth / bounds.width
        let scene = GameScene(size: CGSize(width: logicalWidth, height: bounds.height * scale))
        let insets = view.safeAreaInsets
        scene.safeTop = max(insets.top, 20) * scale
        scene.safeBottom = max(insets.bottom, 12) * scale
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)
        gameScene = scene
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    // 下フリック(巻き戻りバグの操作)でホームに戻りにくくする
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .bottom }
}
