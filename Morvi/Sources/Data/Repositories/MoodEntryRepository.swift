import Foundation

protocol MoodEntryRepository {
    func save(_ record: MoodEntryRecord) throws
    func count() throws -> Int
}

final class SQLiteMoodEntryRepository: MoodEntryRepository {
    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    func save(_ record: MoodEntryRecord) throws {
        try store.write(
            """
            INSERT INTO mood_entry (
                stable_key, account_key, mood_code, mood_asset, body_text,
                tone_code, recorded_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(stable_key) DO UPDATE SET
                mood_code = excluded.mood_code,
                mood_asset = excluded.mood_asset,
                body_text = excluded.body_text,
                tone_code = excluded.tone_code,
                recorded_at = excluded.recorded_at,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(record.stableKey),
                .text(record.accountKey),
                .int(record.moodCode),
                .text(record.moodAsset),
                .text(record.bodyText),
                .int(record.toneCode),
                .text(record.recordedAt),
                .text(record.updatedAt)
            ]
        )
    }

    func count() throws -> Int {
        try store.readInt("SELECT COUNT(*) FROM mood_entry;")
    }
}
