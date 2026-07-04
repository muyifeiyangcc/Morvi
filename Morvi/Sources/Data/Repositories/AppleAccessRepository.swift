import Foundation

final class AppleAccessRepository {
    private let store: LocalStore
    private let profileRepository: AccountProfileRepository
    private let accountAnchorKey = "apple_account_anchor"

    init(
        store: LocalStore = .shared,
        profileRepository: AccountProfileRepository = SQLiteAccountProfileRepository()
    ) {
        self.store = store
        self.profileRepository = profileRepository
    }

    func resolveAccountKey() throws -> String {
        var resolvedKey = ""
        try store.transaction {
            if let accountKey = try storedAccountKey(),
               try profileExists(stableKey: accountKey) {
                resolvedKey = accountKey
                return
            }

            let accountKey = "acct-apple-\(UUID().uuidString.lowercased())"
            let now = LocalDateText.now()
            let profile = AccountProfileRecord(
                stableKey: accountKey,
                email: nil,
                displayName: "Apple",
                genderCode: nil,
                birthDate: nil,
                locationText: nil,
                avatarAsset: "default_avatar",
                coverAsset: "default_avatar",
                registrationState: 1,
                createdAt: now,
                updatedAt: now
            )
            try profileRepository.save(profile)
            try store.write(
                """
                INSERT INTO local_identity_state (
                    stable_key, text_value, integer_value, updated_at
                ) VALUES (?, ?, 0, ?)
                ON CONFLICT(stable_key) DO UPDATE SET
                    text_value = excluded.text_value,
                    updated_at = excluded.updated_at;
                """,
                bindings: [
                    .text(accountAnchorKey),
                    .text(accountKey),
                    .text(now)
                ]
            )
            resolvedKey = accountKey
        }
        return resolvedKey
    }

    private func storedAccountKey() throws -> String? {
        try store.readText(
            "SELECT text_value FROM local_identity_state WHERE stable_key = ? LIMIT 1;",
            bindings: [.text(accountAnchorKey)]
        )
    }

    private func profileExists(stableKey: String) throws -> Bool {
        try store.readText(
            "SELECT stable_key FROM account_profile WHERE stable_key = ? LIMIT 1;",
            bindings: [.text(stableKey)]
        ) != nil
    }
}
