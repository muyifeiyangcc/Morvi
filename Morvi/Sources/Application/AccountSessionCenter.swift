import Foundation

final class AccountSessionCenter {
    static let shared = AccountSessionCenter()
    static let sessionDidChangeNotification = Notification.Name("Morvi.sessionDidChange")

    private let repository: AccountSessionRepository
    private let profileRepository: AccountProfileRepository
    private let guestRepository: GuestAccessRepository
    private let appleRepository: AppleAccessRepository
    private let walletRepository: WalletRepository

    private init(
        repository: AccountSessionRepository = SQLiteAccountSessionRepository(),
        profileRepository: AccountProfileRepository = SQLiteAccountProfileRepository(),
        guestRepository: GuestAccessRepository = GuestAccessRepository(),
        appleRepository: AppleAccessRepository = AppleAccessRepository(),
        walletRepository: WalletRepository = SQLiteWalletRepository()
    ) {
        self.repository = repository
        self.profileRepository = profileRepository
        self.guestRepository = guestRepository
        self.appleRepository = appleRepository
        self.walletRepository = walletRepository
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

    func activeWalletBalanceValue() -> Int {
        guard let accountKey = activeAccountKey else {
            return 0
        }
        return (try? walletRepository.balanceValue(accountKey: accountKey)) ?? 0
    }

    func updateActiveEditableInfo(displayName: String, avatarAsset: String) throws {
        guard let accountKey = activeAccountKey else {
            return
        }
        try profileRepository.updateEditableInfo(
            stableKey: accountKey,
            displayName: displayName,
            avatarAsset: avatarAsset
        )
        notifySessionChange()
    }

    func safetyProfile(accountKey: String) -> SafetyProfileRecord? {
        try? profileRepository.safetyProfile(stableKey: accountKey)
    }

    func canOpenPublicPersona(accountKey: String) -> Bool {
        guard let activeKey = activeAccountKey else {
            return true
        }
        guard activeKey != accountKey else {
            return true
        }
        return ((try? profileRepository.hasSafetyBarrier(
            originKey: activeKey,
            subjectKey: accountKey
        )) ?? false) == false
    }

    func isActiveAccount(_ accountKey: String?) -> Bool {
        guard let activeKey = activeAccountKey,
              let accountKey else {
            return false
        }
        return activeKey == accountKey
    }

    func connectToAccount(accountKey: String) throws -> Bool {
        guard let activeKey = activeAccountKey,
              activeKey != accountKey else {
            return false
        }
        try profileRepository.connect(originKey: activeKey, subjectKey: accountKey)
        notifySessionChange()
        return true
    }

    func isConnectedToAccount(accountKey: String) -> Bool {
        guard let activeKey = activeAccountKey,
              activeKey != accountKey else {
            return false
        }
        return (try? profileRepository.hasConnection(
            originKey: activeKey,
            subjectKey: accountKey
        )) ?? false
    }

    func restrictedRoster() -> [RelationRosterRecord] {
        guard let activeKey = activeAccountKey else {
            return []
        }
        return (try? profileRepository.restrictedRoster(ownerKey: activeKey)) ?? []
    }

    func outboundConnectionRoster() -> [RelationRosterRecord] {
        guard let activeKey = activeAccountKey else {
            return []
        }
        return (try? profileRepository.outboundConnectionRoster(originKey: activeKey)) ?? []
    }

    func inboundConnectionRoster() -> [RelationRosterRecord] {
        guard let activeKey = activeAccountKey else {
            return []
        }
        return (try? profileRepository.inboundConnectionRoster(targetKey: activeKey)) ?? []
    }

    func removeRestrictionFromRoster(accountKey: String) throws -> Bool {
        guard let activeKey = activeAccountKey,
              activeKey != accountKey else {
            return false
        }
        try profileRepository.removeRestriction(originKey: activeKey, subjectKey: accountKey)
        notifySessionChange()
        return true
    }

    func removeOutboundConnectionFromRoster(accountKey: String) throws -> Bool {
        guard let activeKey = activeAccountKey,
              activeKey != accountKey else {
            return false
        }
        try profileRepository.removeConnection(originKey: activeKey, subjectKey: accountKey)
        notifySessionChange()
        return true
    }

    func toggleConnectionToAccount(accountKey: String) throws -> Bool? {
        guard let activeKey = activeAccountKey,
              activeKey != accountKey else {
            return nil
        }
        let isConnected = try profileRepository.hasConnection(
            originKey: activeKey,
            subjectKey: accountKey
        )
        if isConnected {
            try profileRepository.removeConnection(originKey: activeKey, subjectKey: accountKey)
            notifySessionChange()
            return false
        }
        try profileRepository.connect(originKey: activeKey, subjectKey: accountKey)
        notifySessionChange()
        return true
    }

    func hasMutualConnection(with accountKey: String) -> Bool {
        guard let activeKey = activeAccountKey,
              activeKey != accountKey else {
            return false
        }
        return (try? profileRepository.hasMutualConnection(
            firstKey: activeKey,
            secondKey: accountKey
        )) ?? false
    }

    func submitSafetyNotice(subjectKey: String, reasonCode: Int, detailText: String?) throws -> Bool {
        guard let activeKey = activeAccountKey,
              activeKey != subjectKey else {
            return false
        }
        try profileRepository.addSafetyNotice(
            originKey: activeKey,
            subjectKey: subjectKey,
            reasonCode: reasonCode,
            detailText: detailText
        )
        return true
    }

    func confirmRestriction(subjectKey: String) throws -> Bool {
        guard let activeKey = activeAccountKey,
              activeKey != subjectKey else {
            return false
        }
        try profileRepository.addRestriction(originKey: activeKey, subjectKey: subjectKey)
        return true
    }

    func consumeActiveWalletBalanceValue(amount: Int) throws -> Bool {
        guard let accountKey = activeAccountKey else {
            return false
        }
        return try walletRepository.consumeBalanceValue(accountKey: accountKey, amount: amount)
    }

    func addActiveWalletBalanceValue(amount: Int) throws -> Bool {
        guard let accountKey = activeAccountKey else {
            return false
        }
        try walletRepository.addBalanceValue(accountKey: accountKey, amount: amount)
        notifySessionChange()
        return true
    }

    func signInAsGuest() throws {
        let accountKey = try guestRepository.resolveAccountKey()
        try activateSession(accountKey: accountKey, accessKind: 1)
    }

    func signInWithApple(
        subjectText: String,
        emailText: String?,
        fullNameText: String?
    ) throws {
        let accountKey = try appleRepository.resolveAccountKey(
            subjectText: subjectText,
            emailText: emailText,
            fullNameText: fullNameText
        )
        try activateSession(accountKey: accountKey, accessKind: 2)
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

    func resetLocalSecret(email: String, secretText: String) throws -> Bool {
        try profileRepository.updateSecret(email: email, secretText: secretText)
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
             .outboundConnectionRoster,
             .inboundConnectionRoster,
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
