import Foundation

protocol DialogueRepository {
    func saveThread(_ record: DialogueThreadRecord) throws
    func saveEntry(_ record: DialogueEntryRecord) throws
    func summaries(accountKey: String) throws -> [DialogueThreadSummaryRecord]
    func entries(threadKey: String) throws -> [DialogueEntryRecord]
    func nextSequenceNumber(threadKey: String) throws -> Int
    func removePendingAssistantEntries(threadKey: String) throws
    func threadCount() throws -> Int
    func entryCount() throws -> Int
}

final class SQLiteDialogueRepository: DialogueRepository {
    static let didChangeNotification = Notification.Name("Morvi.dialogueRepositoryDidChange")

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
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
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

    func summaries(accountKey: String) throws -> [DialogueThreadSummaryRecord] {
        let rows = try store.readRows(
            """
            SELECT t.stable_key, t.thread_kind, t.counterpart_account_key, t.title, t.avatar_asset,
                e.body_text, e.entry_kind, e.audio_duration
            FROM dialogue_thread t
            LEFT JOIN dialogue_entry e
                ON e.stable_key = t.latest_entry_key
                AND e.removed_at IS NULL
            WHERE t.is_archived = 0
                AND t.thread_kind != 2
                AND (
                    t.counterpart_account_key = ?
                    OR EXISTS (
                        SELECT 1
                        FROM dialogue_entry owned_entry
                        WHERE owned_entry.thread_key = t.stable_key
                            AND owned_entry.author_account_key = ?
                            AND owned_entry.removed_at IS NULL
                    )
                )
            ORDER BY COALESCE(t.latest_entry_at, t.updated_at, t.created_at) DESC, t.id DESC;
            """,
            bindings: [
                .text(accountKey),
                .text(accountKey)
            ]
        )

        return rows.compactMap { row in
            guard row.count == 8 else { return nil }
            return DialogueThreadSummaryRecord(
                stableKey: textValue(row[0]) ?? "",
                threadKind: intValue(row[1]),
                counterpartAccountKey: textValue(row[2]),
                title: textValue(row[3]) ?? "",
                avatarAsset: textValue(row[4]),
                latestPreviewText: previewText(
                    bodyText: textValue(row[5]),
                    entryKind: intValue(row[6]),
                    duration: doubleValue(row[7])
                )
            )
        }
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

    private func previewText(bodyText: String?, entryKind: Int, duration: Double?) -> String {
        if let bodyText, bodyText.isEmpty == false {
            return bodyText
        }
        if entryKind == 2 {
            return "[voice]"
        }
        if entryKind == 1 {
            return "[photo]"
        }
        return "Say something"
    }
}
