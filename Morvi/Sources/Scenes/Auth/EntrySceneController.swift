import UIKit

final class EntrySceneController: ReferencePageController {
    init() {
        super.init(page: .entry) { scene in
            [
                HitArea(frame: CGRect(x: 20, y: 416, width: 335, height: 56)) { scene.push(.signIn) },
                HitArea(frame: CGRect(x: 20, y: 486, width: 335, height: 56)) { scene.push(.signUp) },
                HitArea(frame: CGRect(x: 235, y: 560, width: 70, height: 44)) { scene.push(.signUp) },
                HitArea(frame: CGRect(x: 100, y: 720, width: 100, height: 50)) { scene.push(.agreement) },
                HitArea(frame: CGRect(x: 200, y: 720, width: 120, height: 50)) { scene.push(.agreement) }
            ]
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func makeDecorativeLayer() -> UIView? {
        DecorativeGradientView(palette: .topLeftGlow)
    }
}
