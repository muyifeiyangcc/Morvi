import UIKit

enum RouteContextStore {
    private static var targetAccountKey: String?
    private static var targetWorkKey: String?
    private static var targetDialogueThreadKey: String?
    private static var targetDialogueTitle: String?
    private static var agreementTitle: String?

    static func setTargetAccountKey(_ key: String?) {
        targetAccountKey = key
    }

    static func setTargetWorkKey(_ key: String?) {
        targetWorkKey = key
    }

    static func setTargetDialogueThread(key: String?, title: String?) {
        targetDialogueThreadKey = key
        targetDialogueTitle = title
    }

    static func setAgreementTitle(_ title: String?) {
        agreementTitle = title
    }

    static func currentTargetAccountKey() -> String? {
        targetAccountKey
    }

    static func currentTargetWorkKey() -> String? {
        targetWorkKey
    }

    static func currentTargetDialogueThreadKey() -> String? {
        targetDialogueThreadKey
    }

    static func currentTargetDialogueTitle() -> String? {
        targetDialogueTitle
    }

    static func currentAgreementTitle() -> String? {
        agreementTitle
    }
}

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
                    HitArea(frame: CGRect(x: 290, y: 570, width: 70, height: 44)) { scene.push(.resetAccess) }
                ]
            }
        case .signUp:
            return AuthSceneController(page: .signUp)
        case .resetAccess:
            return AuthSceneController(page: .resetAccess)
        case .agreement:
            return ReferencePageController(page: .agreement)
        case .settings:
            return ReferencePageController(page: .settings)
        case .uploadEmpty:
            return ReferencePageController(page: .uploadEmpty)
        case .uploadFilled:
            return ReferencePageController(page: .uploadFilled)
        case .directDialogue:
            return ReferencePageController(page: .directDialogue)
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
                [
                    HitArea(frame: CGRect(x: 135, y: 137, width: 112, height: 112)) { scene.chooseRegistrationAvatar() }
                ]
            }
        default:
            return ReferencePageController(page: page)
        }
    }
}
