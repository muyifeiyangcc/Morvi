import Foundation

protocol MoodEntryRepository {
    func save(_ record: MoodEntryRecord) throws
    func entries(accountKey: String, from startText: String, through endText: String) throws -> [MoodEntryRecord]
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
                stable_key, account_key, mood_code, mood_asset, mood_title,
                body_text, tone_code, recorded_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(stable_key) DO UPDATE SET
                mood_code = excluded.mood_code,
                mood_asset = excluded.mood_asset,
                mood_title = excluded.mood_title,
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
                .text(record.moodTitle),
                .text(record.bodyText),
                .int(record.toneCode),
                .text(record.recordedAt),
                .text(record.updatedAt)
            ]
        )
    }

    func entries(accountKey: String, from startText: String, through endText: String) throws -> [MoodEntryRecord] {
        let rows = try store.readRows(
            """
            SELECT stable_key, account_key, mood_code, mood_asset, mood_title,
                   body_text, tone_code, recorded_at, updated_at
            FROM mood_entry
            WHERE account_key = ?
                AND recorded_at >= ?
                AND recorded_at < ?
            ORDER BY recorded_at DESC, id DESC;
            """,
            bindings: [.text(accountKey), .text(startText), .text(endText)]
        )
        return rows.compactMap { row in
            guard row.count == 9,
                  case let .text(stableKey) = row[0],
                  case let .text(resolvedAccountKey) = row[1],
                  case let .int(moodCode) = row[2],
                  case let .text(moodAsset) = row[3],
                  case let .text(moodTitle) = row[4],
                  case let .text(bodyText) = row[5],
                  case let .int(toneCode) = row[6],
                  case let .text(recordedAt) = row[7],
                  case let .text(updatedAt) = row[8] else {
                return nil
            }
            return MoodEntryRecord(
                stableKey: stableKey,
                accountKey: resolvedAccountKey,
                moodCode: moodCode,
                moodAsset: moodAsset,
                moodTitle: moodTitle,
                bodyText: bodyText,
                toneCode: toneCode,
                recordedAt: recordedAt,
                updatedAt: updatedAt
            )
        }
    }

    func count() throws -> Int {
        try store.readInt("SELECT COUNT(*) FROM mood_entry;")
    }
}
