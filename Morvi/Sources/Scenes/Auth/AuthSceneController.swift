import UIKit

final class AuthSceneController: ReferencePageController {
    override func makeCanvasView(for page: ScenePage) -> ReferenceCanvasView {
        ReferenceCanvasView(page: page, showsAgreementActionArea: page == .agreement)
    }

    override func makeDecorativeLayer() -> UIView? {
        DecorativeGradientView(palette: .topLeftGlow, showsBrandTextLogo: true)
    }
}
