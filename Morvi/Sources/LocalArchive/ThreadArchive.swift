import Foundation
import SQLite3

private let threadSQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class ThreadArchive {
    static let shared = ThreadArchive()

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

    func summaries(accountKey: String) -> [DialogueThreadRecord] {
        records(accountKey: accountKey, kind: .direct)
    }

    func assistantSummary(accountKey: String) -> DialogueThreadRecord? {
        records(accountKey: accountKey, kind: .assistant).first
    }

    func randomAssistantPhrase() -> String {
        let sql = "SELECT phrase_text FROM assistant_phrase_bank ORDER BY RANDOM() LIMIT 1;"
        guard let statement = prepare(sql) else {
            return Self.assistantPhraseBank.randomElement() ?? "I am here with you. Tell me a little more."
        }
        defer { sqlite3_finalize(statement) }
        if sqlite3_step(statement) == SQLITE_ROW, let value = text(at: 0, from: statement) {
            return value
        }
        return Self.assistantPhraseBank.randomElement() ?? "I am here with you. Tell me a little more."
    }

    func lines(accountKey: String, threadKey: String) -> [DialogueLineRecord] {
        let sql = """
        SELECT stable_key, side_kind, entry_kind, body_text, asset_name,
               audio_duration, occurred_at, avatar_asset, author_key,
               media_width, media_height, delivery_state
        FROM thread_line
        WHERE account_key = ? AND thread_key = ?
        ORDER BY sequence_number ASC, id ASC;
        """
        guard let statement = prepare(sql) else { return [] }
        defer { sqlite3_finalize(statement) }
        bind(accountKey, at: 1, to: statement)
        bind(threadKey, at: 2, to: statement)

        var records: [DialogueLineRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let stableKey = text(at: 0, from: statement) else { continue }
            let side: DialogueLineSide = sqlite3_column_int(statement, 1) == 1 ? .mine : .other
            let entryKind = sqlite3_column_int(statement, 2)
            let body = text(at: 3, from: statement)
            let asset = text(at: 4, from: statement)
            let duration = sqlite3_column_int(statement, 5)
            let occurredAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
            let avatar = text(at: 7, from: statement)
            let authorKey = text(at: 8, from: statement)
            let mediaWidth = optionalDouble(at: 9, from: statement)
            let mediaHeight = optionalDouble(at: 10, from: statement)
            let kind: DialogueLineKind
            switch entryKind {
            case 1:
                kind = .photo(asset ?? "")
            case 2:
                kind = .audio(Int(duration), asset)
            default:
                kind = .text(body ?? "")
            }
            records.append(
                DialogueLineRecord(
                    stableKey: stableKey,
                    side: side,
                    kind: kind,
                    avatarAssetName: avatar ?? "default_avatar",
                    occurredAt: occurredAt,
                    authorStableKey: authorKey,
                    mediaWidth: mediaWidth,
                    mediaHeight: mediaHeight,
                    isPending: sqlite3_column_int(statement, 11) == 1
                )
            )
        }
        return records
    }

    @discardableResult
    func save(_ record: DialogueThreadRecord, accountKey: String) -> Bool {
        saveSummary(record, accountKey: accountKey)
    }

    @discardableResult
    func save(
        _ record: DialogueLineRecord,
        accountKey: String,
        threadKey: String,
        sequence: Int
    ) -> Bool {
        saveLine(record, accountKey: accountKey, threadKey: threadKey, sequence: sequence)
    }

    func persist(
        lines: [DialogueLineRecord],
        summary: DialogueThreadRecord,
        accountKey: String,
        replacingAssistantPending: Bool = false
    ) -> Bool {
        guard execute("BEGIN IMMEDIATE TRANSACTION;") else { return false }
        if replacingAssistantPending,
           execute(
               "DELETE FROM thread_line WHERE account_key = ? AND thread_key = ? AND delivery_state = 1;",
               bindings: [accountKey, summary.stableKey]
           ) == false {
            _ = execute("ROLLBACK;")
            return false
        }

        var sequence = nextSequence(accountKey: accountKey, threadKey: summary.stableKey)
        for line in lines {
            guard saveLine(line, accountKey: accountKey, threadKey: summary.stableKey, sequence: sequence) else {
                _ = execute("ROLLBACK;")
                return false
            }
            sequence += 1
        }
        guard saveSummary(summary, accountKey: accountKey), execute("COMMIT;") else {
            _ = execute("ROLLBACK;")
            return false
        }
        return true
    }

    private func records(accountKey: String, kind: DialogueThreadKind) -> [DialogueThreadRecord] {
        let sql = """
        SELECT stable_key, thread_kind, counterpart_key, title, avatar_asset,
               latest_preview, updated_at
        FROM thread_summary
        WHERE account_key = ? AND thread_kind = ?
        ORDER BY updated_at DESC, id DESC;
        """
        guard let statement = prepare(sql) else { return [] }
        defer { sqlite3_finalize(statement) }
        bind(accountKey, at: 1, to: statement)
        sqlite3_bind_int(statement, 2, Int32(kind.rawValue))

        var records: [DialogueThreadRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let stableKey = text(at: 0, from: statement),
                  let title = text(at: 3, from: statement),
                  let avatarAssetName = text(at: 4, from: statement),
                  let latestPreview = text(at: 5, from: statement) else {
                continue
            }
            records.append(
                DialogueThreadRecord(
                    stableKey: stableKey,
                    kind: DialogueThreadKind(rawValue: Int(sqlite3_column_int(statement, 1))) ?? kind,
                    counterpartStableKey: text(at: 2, from: statement),
                    title: title,
                    avatarAssetName: avatarAssetName,
                    latestPreview: latestPreview,
                    updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
                )
            )
        }
        return records
    }

    private func saveSummary(_ record: DialogueThreadRecord, accountKey: String) -> Bool {
        let sql = """
        INSERT INTO thread_summary (
            account_key, stable_key, thread_kind, counterpart_key, title,
            avatar_asset, latest_preview, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(account_key, stable_key) DO UPDATE SET
            thread_kind = excluded.thread_kind,
            counterpart_key = excluded.counterpart_key,
            title = excluded.title,
            avatar_asset = excluded.avatar_asset,
            latest_preview = excluded.latest_preview,
            updated_at = excluded.updated_at;
        """
        guard let statement = prepare(sql) else { return false }
        defer { sqlite3_finalize(statement) }
        bind(accountKey, at: 1, to: statement)
        bind(record.stableKey, at: 2, to: statement)
        sqlite3_bind_int(statement, 3, Int32(record.kind.rawValue))
        bindOptional(record.counterpartStableKey, at: 4, to: statement)
        bind(record.title, at: 5, to: statement)
        bind(record.avatarAssetName, at: 6, to: statement)
        bind(record.latestPreview, at: 7, to: statement)
        sqlite3_bind_double(statement, 8, record.updatedAt.timeIntervalSince1970)
        return sqlite3_step(statement) == SQLITE_DONE
    }

    private func saveLine(
        _ record: DialogueLineRecord,
        accountKey: String,
        threadKey: String,
        sequence: Int
    ) -> Bool {
        let sql = """
        INSERT INTO thread_line (
            account_key, thread_key, stable_key, side_kind, entry_kind,
            body_text, asset_name, audio_duration, occurred_at, sequence_number,
            avatar_asset, author_key, media_width, media_height, delivery_state
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(account_key, stable_key) DO UPDATE SET
            body_text = excluded.body_text,
            asset_name = excluded.asset_name,
            audio_duration = excluded.audio_duration,
            sequence_number = excluded.sequence_number,
            avatar_asset = excluded.avatar_asset,
            author_key = excluded.author_key,
            media_width = excluded.media_width,
            media_height = excluded.media_height,
            delivery_state = excluded.delivery_state;
        """
        guard let statement = prepare(sql) else { return false }
        defer { sqlite3_finalize(statement) }
        bind(accountKey, at: 1, to: statement)
        bind(threadKey, at: 2, to: statement)
        bind(record.stableKey, at: 3, to: statement)
        sqlite3_bind_int(statement, 4, record.side == .mine ? 1 : 0)
        switch record.kind {
        case .text(let value):
            sqlite3_bind_int(statement, 5, 0)
            bind(value, at: 6, to: statement)
            sqlite3_bind_null(statement, 7)
            sqlite3_bind_int(statement, 8, 0)
        case .photo(let value):
            sqlite3_bind_int(statement, 5, 1)
            sqlite3_bind_null(statement, 6)
            bind(value, at: 7, to: statement)
            sqlite3_bind_int(statement, 8, 0)
        case .audio(let value, let asset):
            sqlite3_bind_int(statement, 5, 2)
            sqlite3_bind_null(statement, 6)
            bindOptional(asset, at: 7, to: statement)
            sqlite3_bind_int(statement, 8, Int32(value))
        }
        sqlite3_bind_double(statement, 9, record.occurredAt.timeIntervalSince1970)
        sqlite3_bind_int(statement, 10, Int32(sequence))
        bind(record.avatarAssetName, at: 11, to: statement)
        bindOptional(record.authorStableKey, at: 12, to: statement)
        bindOptional(record.mediaWidth, at: 13, to: statement)
        bindOptional(record.mediaHeight, at: 14, to: statement)
        sqlite3_bind_int(statement, 15, record.isPending ? 1 : 0)
        return sqlite3_step(statement) == SQLITE_DONE
    }

    private func nextSequence(accountKey: String, threadKey: String) -> Int {
        let sql = """
        SELECT IFNULL(MAX(sequence_number), 0) + 1
        FROM thread_line
        WHERE account_key = ? AND thread_key = ?;
        """
        guard let statement = prepare(sql) else { return 1 }
        defer { sqlite3_finalize(statement) }
        bind(accountKey, at: 1, to: statement)
        bind(threadKey, at: 2, to: statement)
        return sqlite3_step(statement) == SQLITE_ROW ? Int(sqlite3_column_int(statement, 0)) : 1
    }

    private var storeURL: URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = applicationSupport.appendingPathComponent("Morvi", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("threads.sqlite")
    }

    private func openStore() {
        guard sqlite3_open(storeURL.path, &handle) == SQLITE_OK else {
            handle = nil
            return
        }
        sqlite3_exec(handle, "PRAGMA foreign_keys = ON;", nil, nil, nil)
    }

    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS thread_summary (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_key TEXT NOT NULL,
            stable_key TEXT NOT NULL,
            thread_kind INTEGER NOT NULL DEFAULT 0,
            counterpart_key TEXT,
            title TEXT NOT NULL,
            avatar_asset TEXT NOT NULL,
            latest_preview TEXT NOT NULL,
            updated_at REAL NOT NULL,
            UNIQUE(account_key, stable_key)
        );
        CREATE TABLE IF NOT EXISTS thread_line (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_key TEXT NOT NULL,
            thread_key TEXT NOT NULL,
            stable_key TEXT NOT NULL,
            side_kind INTEGER NOT NULL,
            entry_kind INTEGER NOT NULL,
            body_text TEXT,
            asset_name TEXT,
            audio_duration INTEGER NOT NULL DEFAULT 0,
            occurred_at REAL NOT NULL,
            sequence_number INTEGER NOT NULL,
            avatar_asset TEXT,
            author_key TEXT,
            media_width REAL,
            media_height REAL,
            delivery_state INTEGER NOT NULL DEFAULT 0,
            UNIQUE(account_key, stable_key)
        );
        CREATE TABLE IF NOT EXISTS assistant_phrase_bank (
            stable_key TEXT PRIMARY KEY,
            phrase_text TEXT NOT NULL
        );
        """
        sqlite3_exec(handle, sql, nil, nil, nil)
        let migrations = [
            "ALTER TABLE thread_summary ADD COLUMN thread_kind INTEGER NOT NULL DEFAULT 0;",
            "ALTER TABLE thread_summary ADD COLUMN counterpart_key TEXT;",
            "ALTER TABLE thread_line ADD COLUMN avatar_asset TEXT;",
            "ALTER TABLE thread_line ADD COLUMN author_key TEXT;",
            "ALTER TABLE thread_line ADD COLUMN media_width REAL;",
            "ALTER TABLE thread_line ADD COLUMN media_height REAL;",
            "ALTER TABLE thread_line ADD COLUMN delivery_state INTEGER NOT NULL DEFAULT 0;"
        ]
        migrations.forEach { sqlite3_exec(handle, $0, nil, nil, nil) }
        seedAssistantPhraseBank()
    }

    private func seedAssistantPhraseBank() {
        guard execute("BEGIN IMMEDIATE TRANSACTION;") else { return }
        let sql = "INSERT OR IGNORE INTO assistant_phrase_bank (stable_key, phrase_text) VALUES (?, ?);"
        guard let statement = prepare(sql) else {
            _ = execute("ROLLBACK;")
            return
        }
        defer { sqlite3_finalize(statement) }
        for (index, phrase) in Self.assistantPhraseBank.enumerated() {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            bind(String(format: "assistant-phrase-%03d", index + 1), at: 1, to: statement)
            bind(phrase, at: 2, to: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                _ = execute("ROLLBACK;")
                return
            }
        }
        _ = execute("COMMIT;")
    }

    private func alignAnnaReferences() {
        let sql = """
        DELETE FROM thread_line
        WHERE account_key = 'identity-morv'
          AND EXISTS (
              SELECT 1 FROM thread_line keep
              WHERE keep.account_key = 'identity-anna'
                AND keep.stable_key = thread_line.stable_key
          );

        DELETE FROM thread_summary
        WHERE account_key = 'identity-morv'
          AND EXISTS (
              SELECT 1 FROM thread_summary keep
              WHERE keep.account_key = 'identity-anna'
                AND keep.stable_key = thread_summary.stable_key
          );

        UPDATE thread_summary
        SET account_key = 'identity-anna'
        WHERE account_key = 'identity-morv';

        UPDATE thread_line
        SET account_key = 'identity-anna'
        WHERE account_key = 'identity-morv';

        UPDATE thread_summary
        SET counterpart_key = 'identity-anna'
        WHERE counterpart_key = 'identity-morv';

        UPDATE thread_line
        SET author_key = 'identity-anna', avatar_asset = 'default_avatar'
        WHERE author_key = 'identity-morv';
        """
        sqlite3_exec(handle, sql, nil, nil, nil)
        seedAnnaRowanExchange()
    }

    private func seedAnnaRowanExchange() {
        let sql = """
        INSERT OR IGNORE INTO thread_line (
            account_key, thread_key, stable_key, side_kind, entry_kind,
            body_text, asset_name, audio_duration, occurred_at, sequence_number,
            avatar_asset, author_key, media_width, media_height, delivery_state
        ) VALUES (
            'identity-anna',
            'direct-identity-anna-identity-rowan',
            'seed-direct-rowan-anna-greeting',
            0,
            0,
            'Nice to meet you.',
            NULL,
            0,
            strftime('%s', 'now') - 300,
            1,
            'builtin_avatar_rowan',
            'identity-rowan',
            NULL,
            NULL,
            0
        );

        DELETE FROM thread_line
        WHERE account_key = 'identity-anna'
          AND thread_key = 'direct-identity-anna-identity-rowan'
          AND side_kind = 0
          AND entry_kind = 0
          AND body_text = 'Nice to meet you.'
          AND author_key = 'identity-rowan'
          AND stable_key <> 'seed-direct-rowan-anna-greeting';

        INSERT OR IGNORE INTO thread_summary (
            account_key, stable_key, thread_kind, counterpart_key, title,
            avatar_asset, latest_preview, updated_at
        ) VALUES (
            'identity-anna',
            'direct-identity-anna-identity-rowan',
            0,
            'identity-rowan',
            'Rowan',
            'builtin_avatar_rowan',
            'Nice to meet you.',
            strftime('%s', 'now') - 300
        );

        UPDATE thread_summary
        SET latest_preview = 'Nice to meet you.',
            updated_at = strftime('%s', 'now') - 300
        WHERE account_key = 'identity-anna'
          AND stable_key = 'direct-identity-anna-identity-rowan'
          AND latest_preview = '';
        """
        sqlite3_exec(handle, sql, nil, nil, nil)
    }

    private static let assistantPhraseBank = [
        "That makes sense. I am here with you.",
        "I hear you. Tell me a little more when you are ready.",
        "That sounds important. Let's take it one step at a time.",
        "You are doing your best, and that matters.",
        "I can stay with this thought with you.",
        "That is a real feeling. It deserves some space.",
        "Thank you for sharing that with me.",
        "I understand. We can slow this down together.",
        "That sounds like something worth noticing.",
        "You do not have to solve everything at once.",
        "I am listening. What part feels strongest right now?",
        "That is understandable from where you are standing.",
        "Let's keep this gentle and simple for a moment.",
        "You are allowed to feel that way.",
        "That sounds like it has been on your mind.",
        "I am here. We can sort through it together.",
        "That is a thoughtful way to put it.",
        "It may help to give this feeling a name.",
        "You have already taken a useful first step by saying it.",
        "That moment sounds meaningful.",
        "I can see why that would stay with you.",
        "Let's pause with that for a second.",
        "You are not alone in this conversation.",
        "That sounds like a lot to carry.",
        "Small steps are still steps.",
        "This is worth being kind to yourself about.",
        "I am glad you told me.",
        "That feeling is valid.",
        "We can look at this from a softer angle.",
        "You might give yourself a little room here.",
        "That sounds like a good thing to reflect on.",
        "I am with you. Keep going if you want.",
        "That is a fair reaction.",
        "Maybe the next step can be very small.",
        "It sounds like you are trying to understand yourself.",
        "That is a caring thing to notice.",
        "I can help you hold that thought for a moment.",
        "There is no rush here.",
        "That sounds like it matters to you.",
        "You can take this at your own pace.",
        "I am here to listen without judging.",
        "That is a lot of emotion in one place.",
        "Let's make room for what you are feeling.",
        "You are making sense.",
        "That sounds tender.",
        "I can understand why that would affect your day.",
        "A little clarity can start from one honest sentence.",
        "You do not need a perfect answer right now.",
        "This is a good place to begin.",
        "I appreciate how honestly you shared that.",
        "That sounds like a moment worth remembering.",
        "You can let the thought be simple for now.",
        "That may be asking for a bit of care.",
        "I am paying attention.",
        "That sounds like a feeling with layers.",
        "Maybe we can separate what happened from how it felt.",
        "You are allowed to need a pause.",
        "That sounds very human.",
        "I am here for the next thought too.",
        "This does not have to be figured out immediately.",
        "It sounds like you are checking in with yourself.",
        "That is a meaningful check-in.",
        "Let's stay with what feels true.",
        "You can be gentle with yourself here.",
        "That sounds like a moment of awareness.",
        "I hear the feeling underneath that.",
        "There may be something useful in noticing this.",
        "You are doing okay in this moment.",
        "That sounds like something your mind wants to understand.",
        "We can keep it simple: what do you need right now?",
        "That thought deserves patience.",
        "I am here, and I am listening.",
        "That sounds like it touched something real.",
        "It is okay to start with just one feeling.",
        "You do not have to make it neat.",
        "That sounds like a useful reflection.",
        "Maybe today just needs a little softness.",
        "You can choose the next step slowly.",
        "That is worth noticing without pressure.",
        "I can sit with that with you.",
        "It sounds like you are being honest with yourself.",
        "That can be enough for now.",
        "You are allowed to take up space here.",
        "That sounds like a steady place to begin.",
        "I hear you clearly.",
        "Let's keep following the thread gently.",
        "That feeling may be trying to tell you something.",
        "You can trust yourself to move through this.",
        "That is a brave thing to name.",
        "I am here for whatever comes next.",
        "This moment can be simple.",
        "You can breathe and continue when you are ready.",
        "That sounds like it deserves kindness.",
        "I understand why you would say that.",
        "Let's give this thought a little space.",
        "You have time to figure it out.",
        "That is a good observation.",
        "I can help you reflect on it.",
        "You are doing enough right now.",
        "Tell me more if you want to keep going."
    ]

    private func prepare(_ sql: String) -> OpaquePointer? {
        guard let handle else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        return statement
    }

    private func execute(_ sql: String) -> Bool {
        sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK
    }

    private func execute(_ sql: String, bindings: [String]) -> Bool {
        guard let statement = prepare(sql) else { return false }
        defer { sqlite3_finalize(statement) }
        for (index, value) in bindings.enumerated() {
            bind(value, at: Int32(index + 1), to: statement)
        }
        return sqlite3_step(statement) == SQLITE_DONE
    }

    private func bind(_ value: String, at index: Int32, to statement: OpaquePointer) {
        sqlite3_bind_text(statement, index, value, -1, threadSQLiteTransient)
    }

    private func bindOptional(_ value: String?, at index: Int32, to statement: OpaquePointer) {
        if let value {
            bind(value, at: index, to: statement)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bindOptional(_ value: Double?, at index: Int32, to statement: OpaquePointer) {
        if let value {
            sqlite3_bind_double(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func text(at index: Int32, from statement: OpaquePointer) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func optionalDouble(at index: Int32, from statement: OpaquePointer) -> Double? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(statement, index)
    }
}
