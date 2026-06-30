import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = FlowShellController(rootViewController: initialController())
        window.makeKeyAndVisible()
        self.window = window
    }

    private func initialController() -> UIViewController {
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--scene=") }) {
            let title = String(argument.dropFirst("--scene=".count))
            if let page = ScenePage.allCases.first(where: { $0.rawValue == title }) {
                return RouteFactory.controller(for: page)
            }
        }
        #endif
        return RootTabsController()
    }
}
