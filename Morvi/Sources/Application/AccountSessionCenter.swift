import Foundation

final class AccountSessionCenter {
    static let shared = AccountSessionCenter()

    private let repository: AccountSessionRepository
    private let localAccountKey = "acct-local-amelia"

    private init(repository: AccountSessionRepository = SQLiteAccountSessionRepository()) {
        self.repository = repository
    }

    var isSignedIn: Bool {
        (try? repository.hasActiveSession()) ?? false
    }

    var activeAccountKey: String? {
        try? repository.activeAccountKey()
    }

    func activateLocalAccount() {
        let record = AccountSessionRecord(
            accountKey: localAccountKey,
            accessKind: 0,
            isActive: true,
            signedInAt: LocalDateText.now(),
            expiresAt: nil
        )
        try? repository.activate(record)
    }

    func clearActiveSession() {
        try? repository.clearActiveSession()
    }

    func requiresSignedInGate(for page: ScenePage) -> Bool {
        switch page {
        case .wallet,
             .settings,
             .restrictedList,
             .directDialogue,
             .voiceDialogue,
             .assistantDialogue,
             .feelingEditor,
             .uploadEmpty,
             .uploadFilled,
             .profileEditor,
             .restrictPanel,
             .restrictConfirm,
             .reportPanel,
             .repliesPanel,
             .spendConfirm,
             .creditShortage:
            return true
        default:
            return false
        }
    }
}
