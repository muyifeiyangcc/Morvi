import Foundation

protocol AccountProfileRepository {
    func save(_ record: AccountProfileRecord) throws
    func register(_ record: AccountProfileRecord, secretText: String) throws
    func accountKey(email: String) throws -> String?
    func secretText(email: String) throws -> String?
    func remove(stableKey: String) throws -> String?
    func count() throws -> Int
}

final class SQLiteAccountProfileRepository: AccountProfileRepository {
    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    func save(_ record: AccountProfileRecord) throws {
        try store.write(
            """
            INSERT INTO account_profile (
                stable_key, email, display_name, gender_code, birth_date, location_text,
                avatar_asset, cover_asset, registration_state, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(stable_key) DO UPDATE SET
                email = excluded.email,
                display_name = excluded.display_name,
                gender_code = excluded.gender_code,
                birth_date = excluded.birth_date,
                location_text = excluded.location_text,
                avatar_asset = excluded.avatar_asset,
                cover_asset = excluded.cover_asset,
                registration_state = excluded.registration_state,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(record.stableKey),
                record.email.map(LocalStoreValue.text) ?? .null,
                .text(record.displayName),
                record.genderCode.map(LocalStoreValue.int) ?? .null,
                record.birthDate.map(LocalStoreValue.text) ?? .null,
                record.locationText.map(LocalStoreValue.text) ?? .null,
                record.avatarAsset.map(LocalStoreValue.text) ?? .null,
                record.coverAsset.map(LocalStoreValue.text) ?? .null,
                .int(record.registrationState),
                .text(record.createdAt),
                .text(record.updatedAt)
            ]
        )
    }

    func register(_ record: AccountProfileRecord, secretText: String) throws {
        try store.transaction {
            try save(record)
            try store.write(
                """
                INSERT INTO account_secret (
                    account_key, email, secret_text, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(email) DO UPDATE SET
                    account_key = excluded.account_key,
                    secret_text = excluded.secret_text,
                    updated_at = excluded.updated_at;
                """,
                bindings: [
                    .text(record.stableKey),
                    .text(record.email ?? ""),
                    .text(secretText),
                    .text(record.createdAt),
                    .text(record.updatedAt)
                ]
            )
        }
    }

    func accountKey(email: String) throws -> String? {
        try store.readText(
            """
            SELECT account_key
            FROM account_secret
            WHERE lower(email) = lower(?)
            LIMIT 1;
            """,
            bindings: [
                .text(email)
            ]
        )
    }

    func secretText(email: String) throws -> String? {
        try store.readText(
            """
            SELECT secret_text
            FROM account_secret
            WHERE lower(email) = lower(?)
            LIMIT 1;
            """,
            bindings: [
                .text(email)
            ]
        )
    }

    func remove(stableKey: String) throws -> String? {
        let binding = [LocalStoreValue.text(stableKey)]
        let avatarAsset = try store.readText(
            "SELECT avatar_asset FROM account_profile WHERE stable_key = ? LIMIT 1;",
            bindings: binding
        )

        try store.transaction {
            try store.write(
                """
                DELETE FROM dialogue_entry
                WHERE thread_key IN (
                    SELECT stable_key FROM dialogue_thread WHERE counterpart_account_key = ?
                );
                """,
                bindings: binding
            )
            try store.write(
                "DELETE FROM dialogue_thread WHERE counterpart_account_key = ?;",
                bindings: binding
            )
            try store.write(
                "DELETE FROM dialogue_entry WHERE author_account_key = ?;",
                bindings: binding
            )
            try store.write(
                """
                DELETE FROM work_theme_link
                WHERE work_key IN (
                    SELECT stable_key FROM creative_work WHERE owner_account_key = ?
                );
                """,
                bindings: binding
            )
            try store.write(
                """
                DELETE FROM work_reaction
                WHERE account_key = ?
                    OR work_key IN (
                        SELECT stable_key FROM creative_work WHERE owner_account_key = ?
                    );
                """,
                bindings: binding + binding
            )
            try store.write(
                """
                DELETE FROM work_reply
                WHERE author_account_key = ?
                    OR work_key IN (
                        SELECT stable_key FROM creative_work WHERE owner_account_key = ?
                    );
                """,
                bindings: binding + binding
            )
            try store.write("DELETE FROM creative_work WHERE owner_account_key = ?;", bindings: binding)
            try store.write(
                "DELETE FROM account_relation WHERE origin_account_key = ? OR target_account_key = ?;",
                bindings: binding + binding
            )
            try store.write("DELETE FROM mood_entry WHERE account_key = ?;", bindings: binding)
            try store.write(
                "DELETE FROM restricted_relation WHERE owner_account_key = ? OR target_account_key = ?;",
                bindings: binding + binding
            )
            try store.write(
                "DELETE FROM report_record WHERE source_account_key = ? OR target_key = ?;",
                bindings: binding + binding
            )
            try store.write("DELETE FROM credit_activity WHERE account_key = ?;", bindings: binding)
            try store.write("DELETE FROM credit_account WHERE account_key = ?;", bindings: binding)
            try store.write("DELETE FROM agreement_acceptance WHERE account_key = ?;", bindings: binding)
            try store.write("DELETE FROM local_session WHERE account_key = ?;", bindings: binding)
            try store.write("DELETE FROM account_secret WHERE account_key = ?;", bindings: binding)
            try store.write("DELETE FROM account_profile WHERE stable_key = ?;", bindings: binding)
        }

        return avatarAsset
    }

    func count() throws -> Int {
        try store.readInt("SELECT COUNT(*) FROM account_profile;")
    }
}
