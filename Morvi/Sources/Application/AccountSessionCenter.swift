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

    func registerLocalAccount(
        email: String,
        secretText: String,
        displayName: String,
        genderText: String,
        avatarAsset: String,
        birthDate: String?,
        locationText: String?
    ) throws {
        let now = LocalDateText.now()
        let key = "acct-local-\(UUID().uuidString.lowercased())"
        let profile = AccountProfileRecord(
            stableKey: key,
            email: email,
            displayName: displayName,
            genderCode: genderCode(from: genderText),
            birthDate: birthDate,
            locationText: locationText,
            avatarAsset: avatarAsset,
            coverAsset: "default_avatar",
            registrationState: 1,
            createdAt: now,
            updatedAt: now
        )
        try profileRepository.register(profile, secretText: secretText)
    }

    func signInLocalAccount(email: String, secretText: String) throws -> Bool {
        guard let storedSecretText = try profileRepository.secretText(email: email) else {
            return false
        }
        guard storedSecretText == secretText else {
            return false
        }
        guard let accountKey = try profileRepository.accountKey(email: email) else {
            return false
        }
        try activateSession(accountKey: accountKey)
        return true
    }

    private func genderCode(from text: String) -> Int? {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedText.isEmpty {
            return nil
        }
        if normalizedText == "male" {
            return 0
        }
        if normalizedText == "female" {
            return 1
        }
        return 2
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
