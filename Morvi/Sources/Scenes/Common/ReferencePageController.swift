import UIKit

class ReferencePageController: BaseSceneController {
    private let page: ScenePage
    private let areasBuilder: ((ReferencePageController) -> [HitArea])?

    init(page: ScenePage, areas: ((ReferencePageController) -> [HitArea])? = nil) {
        self.page = page
        self.areasBuilder = areas
        super.init(page: page)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func makeDecorativeLayer() -> UIView? {
        switch page {
        case .discover:
            return DecorativeGradientView(palette: .topLeftGlow)
        default:
            return nil
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.viewWithTag(9001) == nil else { return }
        let marker = UIView(frame: .zero)
        marker.tag = 9001
        marker.isHidden = true
        view.addSubview(marker)
        installHitAreas(areasBuilder?(self) ?? [])
    }

    func push(_ page: ScenePage) {
        navigationController?.pushViewController(RouteFactory.controller(for: page), animated: true)
    }

    func showOverlay(_ page: ScenePage) {
        let overlayView = ReferenceCanvasView(page: page)
        overlayView.tag = 9102
        view.viewWithTag(9102)?.removeFromSuperview()
        view.addSubview(overlayView)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        overlayView.didRequestOverlayPage = { [weak self] targetPage in
            self?.showOverlay(targetPage)
        }
    }

    func enterMainFlow() {
        if navigationController?.presentingViewController != nil {
            navigationController?.dismiss(animated: true)
            return
        }
        navigationController?.setViewControllers([RootTabsController()], animated: true)
    }
}
