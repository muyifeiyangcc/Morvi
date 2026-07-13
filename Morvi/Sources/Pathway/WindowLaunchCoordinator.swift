import SwiftUI
import UIKit

final class WindowLaunchCoordinator {
    private let assembly = ScreenTreeAssembler()

    func makeRootController() -> UIViewController {
        let controller = UIHostingController(rootView: assembly.makeRootView())
        controller.view.backgroundColor = .clear
        return controller
    }
}
