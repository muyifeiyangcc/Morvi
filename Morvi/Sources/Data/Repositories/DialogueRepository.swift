import Foundation

protocol DialogueRepository {
    func saveThread(_ record: DialogueThreadRecord) throws
    func saveEntry(_ record: DialogueEntryRecord) throws
    func entries(threadKey: String) throws -> [DialogueEntryRecord]
    func nextSequenceNumber(threadKey: String) throws -> Int
    func removePendingAssistantEntries(threadKey: String) throws
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

    func entries(threadKey: String) throws -> [DialogueEntryRecord] {
        let rows = try store.readRows(
            """
            SELECT stable_key, thread_key, author_account_key, speaker_kind, entry_kind,
                body_text, media_asset, media_width, media_height, audio_duration,
                sequence_number, delivery_state, created_at
            FROM dialogue_entry
            WHERE thread_key = ?
                AND removed_at IS NULL
            ORDER BY sequence_number ASC, id ASC;
            """,
            bindings: [.text(threadKey)]
        )
        return rows.compactMap { row in
            guard row.count == 13 else { return nil }
            return DialogueEntryRecord(
                stableKey: textValue(row[0]) ?? "",
                threadKey: textValue(row[1]) ?? "",
                authorAccountKey: textValue(row[2]),
                speakerKind: intValue(row[3]),
                entryKind: intValue(row[4]),
                bodyText: textValue(row[5]),
                mediaAsset: textValue(row[6]),
                mediaWidth: doubleValue(row[7]),
                mediaHeight: doubleValue(row[8]),
                audioDuration: doubleValue(row[9]),
                sequenceNumber: intValue(row[10]),
                deliveryState: intValue(row[11]),
                createdAt: textValue(row[12]) ?? ""
            )
        }
    }

    func nextSequenceNumber(threadKey: String) throws -> Int {
        try store.readInt(
            """
            SELECT IFNULL(MAX(sequence_number), 0) + 1
            FROM dialogue_entry
            WHERE thread_key = ?
                AND removed_at IS NULL;
            """,
            bindings: [.text(threadKey)]
        )
    }

    func removePendingAssistantEntries(threadKey: String) throws {
        try store.write(
            """
            UPDATE dialogue_entry
            SET removed_at = datetime('now')
            WHERE thread_key = ?
                AND speaker_kind = 1
                AND delivery_state = 1
                AND removed_at IS NULL;
            """,
            bindings: [.text(threadKey)]
        )
    }

    func threadCount() throws -> Int {
        try store.readInt("SELECT COUNT(*) FROM dialogue_thread;")
    }

    func entryCount() throws -> Int {
        try store.readInt("SELECT COUNT(*) FROM dialogue_entry;")
    }

    private func textValue(_ value: LocalStoreValue) -> String? {
        switch value {
        case .text(let text):
            return text
        case .int(let number):
            return "\(number)"
        case .double(let number):
            return "\(number)"
        case .null:
            return nil
        }
    }

    private func intValue(_ value: LocalStoreValue) -> Int {
        switch value {
        case .int(let number):
            return number
        case .double(let number):
            return Int(number)
        case .text(let text):
            return Int(text) ?? 0
        case .null:
            return 0
        }
    }

    private func doubleValue(_ value: LocalStoreValue) -> Double? {
        switch value {
        case .double(let number):
            return number
        case .int(let number):
            return Double(number)
        case .text(let text):
            return Double(text)
        case .null:
            return nil
        }
    }
}
