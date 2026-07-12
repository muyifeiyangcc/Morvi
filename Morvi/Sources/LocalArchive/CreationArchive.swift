import Foundation
import SQLite3

private let creationSQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class CreationArchive {
    static let shared = CreationArchive()

    private var handle: OpaquePointer?
    private let fileManager = FileManager.default

    private init() {
        openStore()
        createTables()
        alignAnnaReferences()
    }

    deinit {
        sqlite3_close(handle)
    }

    func seedIfNeeded(records: [CreationRecord], replyGroups: [String: [CreationReplyRecord]]) {
        guard storedRecordCount == 0 else { return }
        let baseTime = Date().timeIntervalSince1970
        for (index, record) in records.enumerated() {
            save(record, sortStamp: baseTime - Double(index))
        }
        for (creationKey, replies) in replyGroups {
            for reply in replies {
                save(reply, creationKey: creationKey)
            }
        }
    }

    func records() -> [CreationRecord] {
        let sql = """
        SELECT stable_key, title, body_text, author_key, author_name, avatar_asset,
               cover_asset, tag_payload, media_kind, appreciation_count, reply_count
        FROM creation_snapshot
        ORDER BY sort_stamp DESC;
        """
        guard let statement = prepare(sql) else { return [] }
        defer { sqlite3_finalize(statement) }
        var records: [CreationRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let stableKey = text(at: 0, from: statement),
                  let title = text(at: 1, from: statement),
                  let bodyText = text(at: 2, from: statement),
                  let authorKey = text(at: 3, from: statement),
                  let authorName = text(at: 4, from: statement),
                  let avatarAsset = text(at: 5, from: statement),
                  let coverAsset = text(at: 6, from: statement) else {
                continue
            }
            records.append(
                CreationRecord(
                    stableKey: stableKey,
                    title: title,
                    bodyText: bodyText,
                    authorKey: authorKey,
                    authorName: authorName,
                    avatarAssetName: avatarAsset,
                    coverAssetName: coverAsset,
                    tags: decodeTags(text(at: 7, from: statement)),
                    mediaKind: sqlite3_column_int(statement, 8) == 1 ? .video : .photo,
                    appreciationCount: Int(sqlite3_column_int(statement, 9)),
                    replyCount: Int(sqlite3_column_int(statement, 10))
                )
            )
        }
        return records
    }

    func replyGroups() -> [String: [CreationReplyRecord]] {
        let sql = """
        SELECT creation_key, stable_key, author_key, author_name, avatar_asset, body_text, occurred_at
        FROM creation_reply
        ORDER BY occurred_at ASC;
        """
        guard let statement = prepare(sql) else { return [:] }
        defer { sqlite3_finalize(statement) }
        var groups: [String: [CreationReplyRecord]] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let creationKey = text(at: 0, from: statement),
                  let stableKey = text(at: 1, from: statement),
                  let authorKey = text(at: 2, from: statement),
                  let authorName = text(at: 3, from: statement),
                  let avatarAsset = text(at: 4, from: statement),
                  let bodyText = text(at: 5, from: statement) else {
                continue
            }
            groups[creationKey, default: []].append(
                CreationReplyRecord(
                    stableKey: stableKey,
                    authorKey: authorKey,
                    authorName: authorName,
                    avatarAssetName: avatarAsset,
                    bodyText: bodyText,
                    occurredAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
                )
            )
        }
        return groups
    }

    @discardableResult
    func save(_ record: CreationRecord, sortStamp: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        let sql = """
        INSERT INTO creation_snapshot (
            stable_key, title, body_text, author_key, author_name, avatar_asset, cover_asset,
            tag_payload, media_kind, appreciation_count, reply_count, sort_stamp
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(stable_key) DO UPDATE SET
            title = excluded.title,
            body_text = excluded.body_text,
            author_key = excluded.author_key,
            author_name = excluded.author_name,
            avatar_asset = excluded.avatar_asset,
            cover_asset = excluded.cover_asset,
            tag_payload = excluded.tag_payload,
            media_kind = excluded.media_kind,
            appreciation_count = excluded.appreciation_count,
            reply_count = excluded.reply_count;
        """
        guard let statement = prepare(sql) else { return false }
        defer { sqlite3_finalize(statement) }
        bind(record.stableKey, at: 1, to: statement)
        bind(record.title, at: 2, to: statement)
        bind(record.bodyText, at: 3, to: statement)
        bind(record.authorKey, at: 4, to: statement)
        bind(record.authorName, at: 5, to: statement)
        bind(record.avatarAssetName, at: 6, to: statement)
        bind(record.coverAssetName, at: 7, to: statement)
        bind(encodeTags(record.tags), at: 8, to: statement)
        sqlite3_bind_int(statement, 9, record.mediaKind == .video ? 1 : 0)
        sqlite3_bind_int(statement, 10, Int32(record.appreciationCount))
        sqlite3_bind_int(statement, 11, Int32(record.replyCount))
        sqlite3_bind_double(statement, 12, sortStamp)
        return sqlite3_step(statement) == SQLITE_DONE
    }

    @discardableResult
    func save(_ reply: CreationReplyRecord, creationKey: String) -> Bool {
        let sql = """
        INSERT INTO creation_reply (
            creation_key, stable_key, author_key, author_name, avatar_asset, body_text, occurred_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(stable_key) DO UPDATE SET
            author_key = excluded.author_key,
            author_name = excluded.author_name,
            avatar_asset = excluded.avatar_asset,
            body_text = excluded.body_text,
            occurred_at = excluded.occurred_at;
        """
        guard let statement = prepare(sql) else { return false }
        defer { sqlite3_finalize(statement) }
        bind(creationKey, at: 1, to: statement)
        bind(reply.stableKey, at: 2, to: statement)
        bind(reply.authorKey, at: 3, to: statement)
        bind(reply.authorName, at: 4, to: statement)
        bind(reply.avatarAssetName, at: 5, to: statement)
        bind(reply.bodyText, at: 6, to: statement)
        sqlite3_bind_double(statement, 7, reply.occurredAt.timeIntervalSince1970)
        return sqlite3_step(statement) == SQLITE_DONE
    }

    func appreciatedKeys(accountKey: String) -> Set<String> {
        let sql = "SELECT creation_key FROM creation_appreciation WHERE account_key = ?;"
        guard let statement = prepare(sql) else { return [] }
        defer { sqlite3_finalize(statement) }
        bind(accountKey, at: 1, to: statement)
        var keys: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let key = text(at: 0, from: statement) {
                keys.insert(key)
            }
        }
        return keys
    }

    @discardableResult
    func setAppreciated(_ selected: Bool, creationKey: String, accountKey: String) -> Bool {
        if selected {
            let sql = "INSERT OR IGNORE INTO creation_appreciation (account_key, creation_key) VALUES (?, ?);"
            guard let statement = prepare(sql) else { return false }
            defer { sqlite3_finalize(statement) }
            bind(accountKey, at: 1, to: statement)
            bind(creationKey, at: 2, to: statement)
            return sqlite3_step(statement) == SQLITE_DONE
        } else {
            let sql = "DELETE FROM creation_appreciation WHERE account_key = ? AND creation_key = ?;"
            guard let statement = prepare(sql) else { return false }
            defer { sqlite3_finalize(statement) }
            bind(accountKey, at: 1, to: statement)
            bind(creationKey, at: 2, to: statement)
            return sqlite3_step(statement) == SQLITE_DONE
        }
    }

    func append(_ reply: CreationReplyRecord, creationKey: String, updating record: CreationRecord) -> Bool {
        guard beginTransaction() else { return false }
        guard save(reply, creationKey: creationKey), save(record) else {
            rollbackTransaction()
            return false
        }
        return commitTransaction()
    }

    func setAppreciated(
        _ selected: Bool,
        creationKey: String,
        accountKey: String,
        updating record: CreationRecord
    ) -> Bool {
        guard beginTransaction() else { return false }
        guard setAppreciated(selected, creationKey: creationKey, accountKey: accountKey), save(record) else {
            rollbackTransaction()
            return false
        }
        return commitTransaction()
    }

    private var storedRecordCount: Int {
        guard let statement = prepare("SELECT COUNT(*) FROM creation_snapshot;") else { return 0 }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private var storeURL: URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = applicationSupport.appendingPathComponent("Morvi", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("creations.sqlite")
    }

    private func openStore() {
        guard sqlite3_open(storeURL.path, &handle) == SQLITE_OK else {
            handle = nil
            return
        }
    }

    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS creation_snapshot (
            stable_key TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            body_text TEXT NOT NULL,
            author_key TEXT NOT NULL DEFAULT '',
            author_name TEXT NOT NULL,
            avatar_asset TEXT NOT NULL,
            cover_asset TEXT NOT NULL,
            tag_payload TEXT NOT NULL,
            media_kind INTEGER NOT NULL,
            appreciation_count INTEGER NOT NULL,
            reply_count INTEGER NOT NULL,
            sort_stamp REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS creation_reply (
            stable_key TEXT PRIMARY KEY,
            creation_key TEXT NOT NULL,
            author_key TEXT NOT NULL DEFAULT '',
            author_name TEXT NOT NULL,
            avatar_asset TEXT NOT NULL,
            body_text TEXT NOT NULL,
            occurred_at REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS creation_appreciation (
            account_key TEXT NOT NULL,
            creation_key TEXT NOT NULL,
            PRIMARY KEY(account_key, creation_key)
        );
        """
        sqlite3_exec(handle, sql, nil, nil, nil)
        sqlite3_exec(handle, "ALTER TABLE creation_snapshot ADD COLUMN author_key TEXT NOT NULL DEFAULT '';", nil, nil, nil)
        sqlite3_exec(handle, "ALTER TABLE creation_reply ADD COLUMN author_key TEXT NOT NULL DEFAULT '';", nil, nil, nil)
    }

    private func alignAnnaReferences() {
        let sql = """
        UPDATE creation_snapshot
        SET author_key = 'identity-anna', author_name = 'Anna', avatar_asset = 'default_avatar'
        WHERE author_key = 'identity-morv';

        UPDATE creation_reply
        SET author_key = 'identity-anna', author_name = 'Anna', avatar_asset = 'default_avatar'
        WHERE author_key = 'identity-morv';

        DELETE FROM creation_appreciation
        WHERE account_key = 'identity-morv'
          AND EXISTS (
              SELECT 1 FROM creation_appreciation keep
              WHERE keep.account_key = 'identity-anna'
                AND keep.creation_key = creation_appreciation.creation_key
          );

        UPDATE creation_appreciation
        SET account_key = 'identity-anna'
        WHERE account_key = 'identity-morv';

        INSERT OR IGNORE INTO creation_snapshot (
            stable_key, title, body_text, author_key, author_name, avatar_asset, cover_asset,
            tag_payload, media_kind, appreciation_count, reply_count, sort_stamp
        ) VALUES (
            'creation-anna',
            'Moments Matter',
            'Capturing today''s happiness. Saving it for tomorrow''s memories.',
            'identity-anna',
            'Anna',
            'builtin_avatar_amelia',
            'builtin_video_cover_amelia',
            '["Travel","Food","Family","Friends","Lifestyle"]',
            1,
            666,
            777,
            strftime('%s', 'now')
        );

        INSERT OR IGNORE INTO creation_reply (
            creation_key, stable_key, author_key, author_name, avatar_asset, body_text, occurred_at
        ) VALUES
            ('creation-anna', 'creation-reply-anna-jasper', 'identity-jasper', 'Jasper', 'builtin_avatar_jasper', 'The video content is great! Keep going!The video content is great! Keep going!', strftime('%s', 'now') - 300),
            ('creation-anna', 'creation-reply-anna-rowan', 'identity-rowan', 'Rowan', 'builtin_avatar_rowan', 'The video content is great! Keep going!', strftime('%s', 'now') - 240),
            ('creation-anna', 'creation-reply-anna-sophia', 'identity-sophia', 'Sophia', 'builtin_avatar_sophia', 'The video content is great! Keep going!', strftime('%s', 'now') - 180);
        """
        sqlite3_exec(handle, sql, nil, nil, nil)
    }

    private func beginTransaction() -> Bool {
        sqlite3_exec(handle, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil) == SQLITE_OK
    }

    private func commitTransaction() -> Bool {
        guard sqlite3_exec(handle, "COMMIT;", nil, nil, nil) == SQLITE_OK else {
            rollbackTransaction()
            return false
        }
        return true
    }

    private func rollbackTransaction() {
        sqlite3_exec(handle, "ROLLBACK;", nil, nil, nil)
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        guard let handle else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        return statement
    }

    private func bind(_ value: String, at index: Int32, to statement: OpaquePointer) {
        sqlite3_bind_text(statement, index, value, -1, creationSQLiteTransient)
    }

    private func text(at index: Int32, from statement: OpaquePointer) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func encodeTags(_ tags: [String]) -> String {
        guard let data = try? JSONEncoder().encode(tags) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func decodeTags(_ payload: String?) -> [String] {
        guard let payload, let data = payload.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}
