import Foundation

protocol AccountProfileRepository {
    func save(_ record: AccountProfileRecord) throws
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

    func count() throws -> Int {
        try store.readInt("SELECT COUNT(*) FROM account_profile;")
    }
}
