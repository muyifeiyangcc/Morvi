import Foundation

protocol CreativeWorkRepository {
    func save(_ record: CreativeWorkRecord) throws
    func count() throws -> Int
}

final class SQLiteCreativeWorkRepository: CreativeWorkRepository {
    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    func save(_ record: CreativeWorkRecord) throws {
        try store.write(
            """
            INSERT INTO creative_work (
                stable_key, owner_account_key, title, body_text, media_kind, media_asset,
                cover_asset, media_width, media_height, duration_seconds, visibility_code,
                created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(stable_key) DO UPDATE SET
                title = excluded.title,
                body_text = excluded.body_text,
                media_kind = excluded.media_kind,
                media_asset = excluded.media_asset,
                cover_asset = excluded.cover_asset,
                media_width = excluded.media_width,
                media_height = excluded.media_height,
                duration_seconds = excluded.duration_seconds,
                visibility_code = excluded.visibility_code,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(record.stableKey),
                .text(record.ownerAccountKey),
                .text(record.title),
                record.bodyText.map(LocalStoreValue.text) ?? .null,
                .int(record.mediaKind),
                record.mediaAsset.map(LocalStoreValue.text) ?? .null,
                record.coverAsset.map(LocalStoreValue.text) ?? .null,
                record.mediaWidth.map(LocalStoreValue.double) ?? .null,
                record.mediaHeight.map(LocalStoreValue.double) ?? .null,
                record.durationSeconds.map(LocalStoreValue.double) ?? .null,
                .int(record.visibilityCode),
                .text(record.createdAt),
                .text(record.updatedAt)
            ]
        )
    }

    func count() throws -> Int {
        try store.readInt("SELECT COUNT(*) FROM creative_work;")
    }
}
