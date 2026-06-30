import UIKit

enum RouteFactory {
    static func controller(for page: ScenePage) -> UIViewController {
        switch page {
        case .entry:
            return EntrySceneController()
        case .home:
            return RootTabsController(initialPage: .home)
        case .discover:
            return RootTabsController(initialPage: .discover)
        case .dialogueList:
            return RootTabsController(initialPage: .dialogueList)
        case .persona:
            return RootTabsController(initialPage: .persona)
        case .signIn:
            return AuthSceneController(page: .signIn) { scene in
                [
                    HitArea(frame: CGRect(x: 20, y: 715, width: 335, height: 58)) { scene.enterMainFlow() },
                    HitArea(frame: CGRect(x: 290, y: 570, width: 70, height: 44)) { scene.push(.resetAccess) }
                ]
            }
        case .signUp:
            return AuthSceneController(page: .signUp) { scene in
                [HitArea(frame: CGRect(x: 20, y: 715, width: 335, height: 58)) { scene.push(.personalDetail) }]
            }
        case .resetAccess:
            return AuthSceneController(page: .resetAccess) { scene in
                [HitArea(frame: CGRect(x: 20, y: 715, width: 335, height: 58)) { scene.push(.signIn) }]
            }
        case .agreement:
            return AuthSceneController(page: .agreement)
        case .settings:
            return ReferencePageController(page: .settings) { scene in
                [
                    HitArea(frame: CGRect(x: 36, y: 156, width: 300, height: 54)) { scene.push(.wallet) },
                    HitArea(frame: CGRect(x: 36, y: 220, width: 300, height: 54)) { scene.push(.restrictedList) },
                    HitArea(frame: CGRect(x: 36, y: 284, width: 300, height: 54)) { scene.push(.agreement) },
                    HitArea(frame: CGRect(x: 36, y: 348, width: 300, height: 54)) { scene.push(.agreement) },
                    HitArea(frame: CGRect(x: 36, y: 462, width: 300, height: 54)) { scene.push(.exitConfirm) },
                    HitArea(frame: CGRect(x: 36, y: 526, width: 300, height: 54)) { scene.push(.exitConfirm) }
                ]
            }
        case .uploadEmpty:
            return ReferencePageController(page: .uploadEmpty) { scene in
                [HitArea(frame: CGRect(x: 20, y: 710, width: 335, height: 62)) { scene.push(.uploadFilled) }]
            }
        case .uploadFilled:
            return ReferencePageController(page: .uploadFilled) { scene in
                [HitArea(frame: CGRect(x: 20, y: 710, width: 335, height: 62)) { scene.push(.galleryDetail) }]
            }
        case .directDialogue:
            return ReferencePageController(page: .directDialogue) { scene in
                [
                    HitArea(frame: CGRect(x: 20, y: 680, width: 60, height: 52)) { scene.push(.voiceDialogue) },
                    HitArea(frame: CGRect(x: 294, y: 60, width: 70, height: 70)) { scene.push(.restrictPanel) }
                ]
            }
        case .assistantDialogue:
            return ReferencePageController(page: .assistantDialogue) { scene in
                [HitArea(frame: CGRect(x: 20, y: 690, width: 335, height: 60)) { scene.push(.spendConfirm) }]
            }
        case .wallet:
            return ReferencePageController(page: .wallet) { scene in
                [
                    HitArea(frame: CGRect(x: 30, y: 500, width: 315, height: 58)) { scene.push(.spendConfirm) },
                    HitArea(frame: CGRect(x: 30, y: 570, width: 315, height: 58)) { scene.push(.creditShortage) }
                ]
            }
        case .publicPersona:
            return ReferencePageController(page: .publicPersona) { scene in
                [
                    HitArea(frame: CGRect(x: 190, y: 245, width: 160, height: 250)) { scene.push(.galleryDetail) },
                    HitArea(frame: CGRect(x: 290, y: 60, width: 70, height: 70)) { scene.push(.restrictPanel) }
                ]
            }
        case .galleryDetail:
            return ReferencePageController(page: .galleryDetail) { scene in
                [
                    HitArea(frame: CGRect(x: 104, y: 744, width: 96, height: 44)) { scene.push(.repliesPanel) },
                    HitArea(frame: CGRect(x: 292, y: 60, width: 70, height: 70)) { scene.push(.reportPanel) }
                ]
            }
        case .restrictPanel:
            return ReferencePageController(page: .restrictPanel) { scene in
                [HitArea(frame: CGRect(x: 40, y: 650, width: 295, height: 64)) { scene.push(.restrictConfirm) }]
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
            return ReferencePageController(page: .personalDetail) { scene in
                [HitArea(frame: CGRect(x: 20, y: 716, width: 335, height: 56)) { scene.enterMainFlow() }]
            }
        default:
            return ReferencePageController(page: page)
        }
    }
}
