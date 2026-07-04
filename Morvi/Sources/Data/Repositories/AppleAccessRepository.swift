import Foundation

final class AppleAccessRepository {
    private let store: LocalStore
    private let profileRepository: AccountProfileRepository
    private let accountAnchorPrefix = "apple_account_anchor_"

    init(
        store: LocalStore = .shared,
        profileRepository: AccountProfileRepository = SQLiteAccountProfileRepository()
    ) {
        self.store = store
        self.profileRepository = profileRepository
    }

    func resolveAccountKey(
        subjectText: String,
        emailText: String?,
        fullNameText: String?
    ) throws -> String {
        let normalizedSubject = subjectText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedSubject.isEmpty == false else {
            throw LocalStoreError.executionFailed("Missing Apple account identity.")
        }

        var resolvedKey = ""
        try store.transaction {
            let anchorKey = "\(accountAnchorPrefix)\(normalizedSubject)"
            if let accountKey = try storedAccountKey(anchorKey: anchorKey),
               try profileExists(stableKey: accountKey) {
                resolvedKey = accountKey
                return
            }

            let accountKey = "acct-apple-\(UUID().uuidString.lowercased())"
            let now = LocalDateText.now()
            let displayName = resolvedDisplayName(
                fullNameText: fullNameText,
                emailText: emailText
            )
            let profile = AccountProfileRecord(
                stableKey: accountKey,
                email: normalizedOptional(emailText),
                displayName: displayName,
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
                    .text(anchorKey),
                    .text(accountKey),
                    .text(now)
                ]
            )
            resolvedKey = accountKey
        }
        return resolvedKey
    }

    private func storedAccountKey(anchorKey: String) throws -> String? {
        try store.readText(
            "SELECT text_value FROM local_identity_state WHERE stable_key = ? LIMIT 1;",
            bindings: [.text(anchorKey)]
        )
    }

    private func normalizedOptional(_ text: String?) -> String? {
        let normalizedText = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedText.isEmpty ? nil : normalizedText
    }

    private func resolvedDisplayName(fullNameText: String?, emailText: String?) -> String {
        if let fullName = normalizedOptional(fullNameText) {
            return fullName
        }
        if let emailText = normalizedOptional(emailText),
           let prefix = emailText.split(separator: "@").first,
           prefix.isEmpty == false {
            return String(prefix)
        }
        return "Apple"
    }

    private func profileExists(stableKey: String) throws -> Bool {
        try store.readText(
            "SELECT stable_key FROM account_profile WHERE stable_key = ? LIMIT 1;",
            bindings: [.text(stableKey)]
        ) != nil
    }
}
