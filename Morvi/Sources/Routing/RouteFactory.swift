import UIKit

enum RouteFactory {
    static func controller(for page: ScenePage) -> UIViewController {
        switch page {
        case .entry:
            return EntrySceneController()
        case .home:
            return RootTabsController(initialPage: .home)
        case .discover:
            return ReferencePageController(page: .discover)
        case .dialogueList:
            return ReferencePageController(page: .dialogueList)
        case .persona:
            return ReferencePageController(page: .persona)
        case .signIn:
            return AuthSceneController(page: .signIn) { scene in
                [
                    HitArea(frame: CGRect(x: 20, y: 715, width: 335, height: 58)) { scene.enterMainFlow() },
                    HitArea(frame: CGRect(x: 290, y: 570, width: 70, height: 44)) { scene.push(.resetAccess) }
                ]
            }
        case .signUp:
            return AuthSceneController(page: .signUp) { scene in
                [HitArea(frame: CGRect(x: 20, y: 715, width: 335, height: 58)) { scene.submitSignUp() }]
            }
        case .resetAccess:
            return AuthSceneController(page: .resetAccess) { scene in
                [HitArea(frame: CGRect(x: 20, y: 715, width: 335, height: 58)) { scene.push(.signIn) }]
            }
        case .agreement:
            return AuthSceneController(page: .agreement)
        case .settings:
            return ReferencePageController(page: .settings)
        case .uploadEmpty:
            return ReferencePageController(page: .uploadEmpty)
        case .uploadFilled:
            return ReferencePageController(page: .uploadFilled)
        case .directDialogue:
            return ReferencePageController(page: .directDialogue) { scene in
                [
                    HitArea(frame: CGRect(x: 294, y: 60, width: 70, height: 70)) { scene.push(.restrictPanel) }
                ]
            }
        case .assistantDialogue:
            return ReferencePageController(page: .assistantDialogue)
        case .wallet:
            return ReferencePageController(page: .wallet)
        case .publicPersona:
            return ReferencePageController(page: .publicPersona) { scene in
                []
            }
        case .galleryDetail:
            return ReferencePageController(page: .galleryDetail) { scene in
                [
                    HitArea(frame: CGRect(x: 104, y: 744, width: 96, height: 44)) { scene.showOverlay(.repliesPanel) }
                ]
            }
        case .restrictPanel:
            return ReferencePageController(page: .restrictPanel) { scene in
                [HitArea(frame: CGRect(x: 40, y: 650, width: 295, height: 64)) { scene.showOverlay(.restrictConfirm) }]
            }
        case .feelingEditor:
            return ReferencePageController(page: .feelingEditor) { scene in
                [HitArea(frame: CGRect(x: 20, y: 716, width: 335, height: 56)) { scene.push(.weeklyFeeling) }]
            }
        case .profileEditor:
            return ReferencePageController(page: .profileEditor) { scene in
                [HitArea(frame: CGRect(x: 20, y: 716, width: 335, height: 56)) { scene.navigationController?.popViewController(animated: true) }]
            }
        case .personalDetail:
            return AuthSceneController(page: .personalDetail) { scene in
                [HitArea(frame: CGRect(x: 20, y: 716, width: 335, height: 56)) { scene.enterMainFlow() }]
            }
        default:
            return ReferencePageController(page: page)
        }
    }
}
