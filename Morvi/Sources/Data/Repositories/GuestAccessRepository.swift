import Foundation

final class GuestAccessRepository {
    private let store: LocalStore
    private let profileRepository: AccountProfileRepository
    private let accountAnchorKey = "guest_account_anchor"
    private let nicknameAnchorPrefix = "guest_nickname_"
    private let nicknameAlphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

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
                try ensureValidNickname(stableKey: accountKey)
                resolvedKey = accountKey
                return
            }

            let nickname = try makeUniqueNickname()
            let accountKey = "acct-guest-\(UUID().uuidString.lowercased())"
            let now = LocalDateText.now()
            let profile = AccountProfileRecord(
                stableKey: accountKey,
                email: nil,
                displayName: nickname.text,
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
            try recordNickname(nickname, at: now)
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

    private func ensureValidNickname(stableKey: String) throws {
        let currentName = try profileRepository.displayName(stableKey: stableKey)
        guard let currentName, isValidNickname(currentName) == false else {
            return
        }
        let nickname = try makeUniqueNickname()
        let now = LocalDateText.now()
        try store.write(
            """
            UPDATE account_profile
            SET display_name = ?, updated_at = ?
            WHERE stable_key = ?;
            """,
            bindings: [
                .text(nickname.text),
                .text(now),
                .text(stableKey)
            ]
        )
        try recordNickname(nickname, at: now)
    }

    private func makeUniqueNickname() throws -> (text: String, anchorKey: String) {
        for _ in 0..<100 {
            let suffix = String(
                (0..<6).map { _ in nicknameAlphabet.randomElement() ?? "A" }
            )
            let text = "Guest-\(suffix)"
            let anchorKey = "\(nicknameAnchorPrefix)\(suffix.lowercased())"
            let wasUsed = try store.readText(
                "SELECT stable_key FROM local_identity_state WHERE stable_key = ? LIMIT 1;",
                bindings: [.text(anchorKey)]
            ) != nil
            let isAssigned = try store.readText(
                "SELECT stable_key FROM account_profile WHERE display_name = ? LIMIT 1;",
                bindings: [.text(text)]
            ) != nil
            if wasUsed == false, isAssigned == false {
                return (text, anchorKey)
            }
        }
        throw LocalStoreError.executionFailed("Unable to create a unique guest nickname.")
    }

    private func recordNickname(
        _ nickname: (text: String, anchorKey: String),
        at timestamp: String
    ) throws {
        try store.write(
            """
            INSERT INTO local_identity_state (
                stable_key, text_value, integer_value, updated_at
            ) VALUES (?, ?, 0, ?);
            """,
            bindings: [
                .text(nickname.anchorKey),
                .text(nickname.text),
                .text(timestamp)
            ]
        )
    }

    private func isValidNickname(_ text: String) -> Bool {
        guard text.hasPrefix("Guest-") else {
            return false
        }
        let suffix = text.dropFirst("Guest-".count)
        return suffix.count == 6 && suffix.allSatisfy { character in
            nicknameAlphabet.contains(character)
        }
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
