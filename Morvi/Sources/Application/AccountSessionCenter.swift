import Foundation

final class AccountSessionCenter {
    static let shared = AccountSessionCenter()

    private let repository: AccountSessionRepository
    private let profileRepository: AccountProfileRepository
    private let localAccountKey = "acct-local-amelia"

    private init(
        repository: AccountSessionRepository = SQLiteAccountSessionRepository(),
        profileRepository: AccountProfileRepository = SQLiteAccountProfileRepository()
    ) {
        self.repository = repository
        self.profileRepository = profileRepository
    }

    var isSignedIn: Bool {
        (try? repository.hasActiveSession()) ?? false
    }

    var activeAccountKey: String? {
        try? repository.activeAccountKey()
    }

    func activateLocalAccount() {
        activate(accountKey: localAccountKey)
    }

    func registerLocalAccount(email: String, secretText: String) throws {
        let now = LocalDateText.now()
        let key = "acct-local-\(UUID().uuidString.lowercased())"
        let profile = AccountProfileRecord(
            stableKey: key,
            email: email,
            displayName: "Amelia",
            genderCode: nil,
            birthDate: nil,
            locationText: nil,
            avatarAsset: "default_avatar",
            coverAsset: "default_avatar",
            registrationState: 1,
            createdAt: now,
            updatedAt: now
        )
        try profileRepository.register(profile, secretText: secretText)
    }

    private func activate(accountKey: String) {
        try? activateSession(accountKey: accountKey)
    }

    private func activateSession(accountKey: String) throws {
        let record = AccountSessionRecord(
            accountKey: accountKey,
            accessKind: 0,
            isActive: true,
            signedInAt: LocalDateText.now(),
            expiresAt: nil
        )
        try repository.activate(record)
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
