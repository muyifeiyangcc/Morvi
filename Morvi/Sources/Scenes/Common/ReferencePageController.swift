import UIKit

class ReferencePageController: BaseSceneController {
    private let areasBuilder: ((ReferencePageController) -> [HitArea])?

    init(page: ScenePage, areas: ((ReferencePageController) -> [HitArea])? = nil) {
        self.areasBuilder = areas
        super.init(page: page)
    }

    required init?(coder: NSCoder) {
        nil
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

    func enterMainFlow() {
        navigationController?.setViewControllers([RootTabsController()], animated: true)
    }
}
