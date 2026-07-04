import Foundation

final class AccountSessionCenter {
    static let shared = AccountSessionCenter()
    static let sessionDidChangeNotification = Notification.Name("Morvi.sessionDidChange")

    private let repository: AccountSessionRepository
    private let profileRepository: AccountProfileRepository
    private let guestRepository: GuestAccessRepository

    private init(
        repository: AccountSessionRepository = SQLiteAccountSessionRepository(),
        profileRepository: AccountProfileRepository = SQLiteAccountProfileRepository(),
        guestRepository: GuestAccessRepository = GuestAccessRepository()
    ) {
        self.repository = repository
        self.profileRepository = profileRepository
        self.guestRepository = guestRepository
    }

    var isSignedIn: Bool {
        (try? repository.hasActiveSession()) ?? false
    }

    var activeAccountKey: String? {
        try? repository.activeAccountKey()
    }

    func activeHeaderContent() -> (displayName: String, avatarAsset: String?)? {
        guard let accountKey = activeAccountKey,
              let displayName = try? profileRepository.displayName(stableKey: accountKey) else {
            return nil
        }
        let avatarAsset = try? profileRepository.avatarAsset(stableKey: accountKey)
        return (displayName, avatarAsset)
    }

    func signInAsGuest() throws {
        let accountKey = try guestRepository.resolveAccountKey()
        try activateSession(accountKey: accountKey, accessKind: 1)
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

    private func activateSession(accountKey: String, accessKind: Int = 0) throws {
        let record = AccountSessionRecord(
            accountKey: accountKey,
            accessKind: accessKind,
            isActive: true,
            signedInAt: LocalDateText.now(),
            expiresAt: nil
        )
        try repository.activate(record)
        notifySessionChange()
    }

    func clearActiveSession() {
        try? repository.clearActiveSession()
        notifySessionChange()
    }

    func removeActiveAccount() throws -> Bool {
        guard let accountKey = try repository.activeAccountKey() else {
            return false
        }
        let avatarAsset = try profileRepository.remove(stableKey: accountKey)
        removeLocalAvatarIfNeeded(avatarAsset)
        notifySessionChange()
        return true
    }

    private func notifySessionChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.sessionDidChangeNotification,
                object: nil
            )
        }
    }

    private func removeLocalAvatarIfNeeded(_ avatarAsset: String?) {
        guard let avatarAsset,
              avatarAsset.hasPrefix("local-avatar/") else {
            return
        }
        let fileName = String(avatarAsset.dropFirst("local-avatar/".count))
        guard fileName.isEmpty == false,
              let baseDirectory = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
              ) else {
            return
        }
        let fileURL = baseDirectory
            .appendingPathComponent("Morvi", isDirectory: true)
            .appendingPathComponent("Avatars", isDirectory: true)
            .appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
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
