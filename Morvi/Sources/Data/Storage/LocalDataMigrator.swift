import Foundation

final class LocalDataMigrator {
    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    func run() throws {
        try store.prepare()
        var version = try store.readInt("PRAGMA user_version;")
        if version < 1 {
            try createInitialSchema()
            try store.execute("PRAGMA user_version = 1;")
            version = 1
        }
        if version < 2 {
            try createBuiltInContentSchema()
            try store.execute("PRAGMA user_version = 2;")
            version = 2
        }
        if version < 3 {
            try createAccessSecretSchema()
            try store.execute("PRAGMA user_version = 3;")
            version = 3
        }
        if version < 4 {
            try createLocalIdentitySchema()
            try store.execute("PRAGMA user_version = 4;")
            version = 4
        }
        if version < 5 {
            try enforceIdentifierFloors()
            try store.execute("PRAGMA user_version = 5;")
        }
    }

    private func createInitialSchema() throws {
        try store.execute(Self.initialSchema)
    }

    private func createBuiltInContentSchema() throws {
        try store.execute(Self.builtInContentSchema)
    }

    private func createAccessSecretSchema() throws {
        try store.execute(Self.accessSecretSchema)
    }

    private func createLocalIdentitySchema() throws {
        try store.execute(Self.localIdentitySchema)
    }

    private func enforceIdentifierFloors() throws {
        let standardTables = [
            "local_session",
            "account_relation",
            "creative_work",
            "theme_catalog",
            "work_reaction",
            "work_reply",
            "mood_entry",
            "restricted_relation",
            "report_record",
            "credit_activity",
            "agreement_acceptance",
            "dialogue_thread",
            "dialogue_entry",
            "permission_copy"
        ]

        try store.transaction {
            try store.write("UPDATE account_profile SET id = id + 9999;", bindings: [])
            try store.write("UPDATE work_theme_link SET theme_id = theme_id + 999;", bindings: [])
            for table in standardTables {
                try store.write("UPDATE \(table) SET id = id + 999;", bindings: [])
            }

            try setSequenceFloor(for: "account_profile", minimum: 9999)
            for table in standardTables {
                try setSequenceFloor(for: table, minimum: 999)
            }
        }
    }

    private func setSequenceFloor(for table: String, minimum: Int) throws {
        let maximumID = try store.readInt("SELECT COALESCE(MAX(id), 0) FROM \(table);")
        let sequence = max(minimum, maximumID)
        try store.write(
            "UPDATE sqlite_sequence SET seq = ? WHERE name = ?;",
            bindings: [.int(sequence), .text(table)]
        )
        guard try store.readInt(
            "SELECT COUNT(*) FROM sqlite_sequence WHERE name = '\(table)';"
        ) == 0 else {
            return
        }
        try store.write(
            "INSERT INTO sqlite_sequence (name, seq) VALUES (?, ?);",
            bindings: [.text(table), .int(sequence)]
        )
    }
}

private extension LocalDataMigrator {
    static let initialSchema = """
    CREATE TABLE IF NOT EXISTS account_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stable_key TEXT NOT NULL UNIQUE,
        email TEXT UNIQUE,
        display_name TEXT NOT NULL,
        gender_code INTEGER,
        birth_date TEXT,
        location_text TEXT,
        avatar_asset TEXT,
        cover_asset TEXT,
        registration_state INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS account_secret (
        account_key TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        secret_text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS local_session (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_key TEXT NOT NULL,
        access_kind INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        signed_in_at TEXT NOT NULL,
        expires_at TEXT
    );

    CREATE TABLE IF NOT EXISTS account_relation (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        origin_account_key TEXT NOT NULL,
        target_account_key TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(origin_account_key, target_account_key)
    );

    CREATE TABLE IF NOT EXISTS creative_work (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stable_key TEXT NOT NULL UNIQUE,
        owner_account_key TEXT NOT NULL,
        title TEXT NOT NULL,
        body_text TEXT,
        media_kind INTEGER NOT NULL,
        media_asset TEXT,
        cover_asset TEXT,
        media_width REAL,
        media_height REAL,
        duration_seconds REAL,
        visibility_code INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        removed_at TEXT
    );

    CREATE TABLE IF NOT EXISTS theme_catalog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS work_theme_link (
        work_key TEXT NOT NULL,
        theme_id INTEGER NOT NULL,
        PRIMARY KEY(work_key, theme_id)
    );

    CREATE TABLE IF NOT EXISTS work_reaction (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        work_key TEXT NOT NULL,
        account_key TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(work_key, account_key)
    );

    CREATE TABLE IF NOT EXISTS work_reply (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stable_key TEXT NOT NULL UNIQUE,
        work_key TEXT NOT NULL,
        author_account_key TEXT NOT NULL,
        parent_reply_key TEXT,
        body_text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        removed_at TEXT
    );

    CREATE TABLE IF NOT EXISTS mood_entry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stable_key TEXT NOT NULL UNIQUE,
        account_key TEXT NOT NULL,
        mood_code INTEGER NOT NULL,
        mood_asset TEXT NOT NULL,
        body_text TEXT NOT NULL,
        tone_code INTEGER NOT NULL DEFAULT 0,
        recorded_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS restricted_relation (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner_account_key TEXT NOT NULL,
        target_account_key TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(owner_account_key, target_account_key)
    );

    CREATE TABLE IF NOT EXISTS report_record (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_account_key TEXT NOT NULL,
        target_kind INTEGER NOT NULL,
        target_key TEXT NOT NULL,
        reason_code INTEGER NOT NULL,
        detail_text TEXT,
        created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS credit_account (
        account_key TEXT PRIMARY KEY,
        balance_value INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS credit_activity (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_key TEXT NOT NULL,
        change_value INTEGER NOT NULL,
        activity_kind INTEGER NOT NULL,
        reference_key TEXT,
        created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS agreement_acceptance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_key TEXT,
        agreement_kind INTEGER NOT NULL,
        version_text TEXT NOT NULL,
        accepted_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS dialogue_thread (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stable_key TEXT NOT NULL UNIQUE,
        thread_kind INTEGER NOT NULL,
        counterpart_account_key TEXT,
        title TEXT NOT NULL,
        avatar_asset TEXT,
        latest_entry_key TEXT,
        latest_entry_at TEXT,
        last_read_at TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS dialogue_entry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stable_key TEXT NOT NULL UNIQUE,
        thread_key TEXT NOT NULL,
        author_account_key TEXT,
        speaker_kind INTEGER NOT NULL,
        entry_kind INTEGER NOT NULL,
        body_text TEXT,
        media_asset TEXT,
        media_width REAL,
        media_height REAL,
        audio_duration REAL,
        sequence_number INTEGER NOT NULL,
        delivery_state INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        removed_at TEXT
    );

    CREATE INDEX IF NOT EXISTS idx_account_relation_origin ON account_relation(origin_account_key);
    CREATE INDEX IF NOT EXISTS idx_account_relation_target ON account_relation(target_account_key);
    CREATE INDEX IF NOT EXISTS idx_creative_work_owner ON creative_work(owner_account_key, created_at);
    CREATE INDEX IF NOT EXISTS idx_work_reply_work ON work_reply(work_key, created_at);
    CREATE INDEX IF NOT EXISTS idx_mood_entry_account ON mood_entry(account_key, recorded_at);
    CREATE INDEX IF NOT EXISTS idx_dialogue_thread_latest ON dialogue_thread(latest_entry_at);
    CREATE INDEX IF NOT EXISTS idx_dialogue_entry_thread ON dialogue_entry(thread_key, sequence_number);
    """

    static let accessSecretSchema = """
    CREATE TABLE IF NOT EXISTS account_secret (
        account_key TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        secret_text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """

    static let builtInContentSchema = """
    CREATE TABLE IF NOT EXISTS permission_copy (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stable_key TEXT NOT NULL UNIQUE,
        permission_kind INTEGER NOT NULL,
        title TEXT NOT NULL,
        body_text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS local_seed_state (
        stable_key TEXT PRIMARY KEY,
        created_at TEXT NOT NULL
    );
    """

    static let localIdentitySchema = """
    CREATE TABLE IF NOT EXISTS local_identity_state (
        stable_key TEXT PRIMARY KEY,
        text_value TEXT,
        integer_value INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
    );
    """
}
