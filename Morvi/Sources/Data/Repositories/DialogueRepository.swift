import Foundation

protocol DialogueRepository {
    func saveThread(_ record: DialogueThreadRecord) throws
    func saveEntry(_ record: DialogueEntryRecord) throws
    func threadCount() throws -> Int
    func entryCount() throws -> Int
}

final class SQLiteDialogueRepository: DialogueRepository {
    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    func saveThread(_ record: DialogueThreadRecord) throws {
        try store.write(
            """
            INSERT INTO dialogue_thread (
                stable_key, thread_kind, counterpart_account_key, title, avatar_asset,
                latest_entry_key, latest_entry_at, last_read_at, is_archived,
                created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(stable_key) DO UPDATE SET
                title = excluded.title,
                avatar_asset = excluded.avatar_asset,
                latest_entry_key = excluded.latest_entry_key,
                latest_entry_at = excluded.latest_entry_at,
                last_read_at = excluded.last_read_at,
                is_archived = excluded.is_archived,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(record.stableKey),
                .int(record.threadKind),
                record.counterpartAccountKey.map(LocalStoreValue.text) ?? .null,
                .text(record.title),
                record.avatarAsset.map(LocalStoreValue.text) ?? .null,
                record.latestEntryKey.map(LocalStoreValue.text) ?? .null,
                record.latestEntryAt.map(LocalStoreValue.text) ?? .null,
                record.lastReadAt.map(LocalStoreValue.text) ?? .null,
                .int(record.isArchived ? 1 : 0),
                .text(record.createdAt),
                .text(record.updatedAt)
            ]
        )
    }

    func saveEntry(_ record: DialogueEntryRecord) throws {
        try store.write(
            """
            INSERT INTO dialogue_entry (
                stable_key, thread_key, author_account_key, speaker_kind, entry_kind,
                body_text, media_asset, media_width, media_height, audio_duration,
                sequence_number, delivery_state, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(stable_key) DO UPDATE SET
                body_text = excluded.body_text,
                media_asset = excluded.media_asset,
                media_width = excluded.media_width,
                media_height = excluded.media_height,
                audio_duration = excluded.audio_duration,
                sequence_number = excluded.sequence_number,
                delivery_state = excluded.delivery_state;
            """,
            bindings: [
                .text(record.stableKey),
                .text(record.threadKey),
                record.authorAccountKey.map(LocalStoreValue.text) ?? .null,
                .int(record.speakerKind),
                .int(record.entryKind),
                record.bodyText.map(LocalStoreValue.text) ?? .null,
                record.mediaAsset.map(LocalStoreValue.text) ?? .null,
                record.mediaWidth.map(LocalStoreValue.double) ?? .null,
                record.mediaHeight.map(LocalStoreValue.double) ?? .null,
                record.audioDuration.map(LocalStoreValue.double) ?? .null,
                .int(record.sequenceNumber),
                .int(record.deliveryState),
                .text(record.createdAt)
            ]
        )
    }

    func threadCount() throws -> Int {
        try store.readInt("SELECT COUNT(*) FROM dialogue_thread;")
    }

    func entryCount() throws -> Int {
        try store.readInt("SELECT COUNT(*) FROM dialogue_entry;")
    }
}
