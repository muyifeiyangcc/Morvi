import UIKit

final class AuthSceneController: ReferencePageController {
    override func makeDecorativeLayer() -> UIView? {
        DecorativeGradientView(palette: .topLeftGlow, showsBrandTextLogo: true)
    }
}
