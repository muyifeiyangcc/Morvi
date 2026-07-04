import UIKit

final class AuthSceneController: ReferencePageController {
    override func makeCanvasView(for page: ScenePage) -> ReferenceCanvasView {
        ReferenceCanvasView(page: page, showsAgreementActionArea: page == .agreement)
    }

    override func controllerForPushedPage(_ page: ScenePage) -> UIViewController {
        if page == .agreement {
            RouteContextStore.setAgreementTitle(nil)
            return AuthSceneController(page: .agreement)
        }
        return super.controllerForPushedPage(page)
    }

    override func makeDecorativeLayer() -> UIView? {
        DecorativeGradientView(palette: .topLeftGlow, showsBrandTextLogo: true)
    }
}
