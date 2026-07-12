import Foundation
import SQLite3

private let storedValueSQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class StoredValueLedger {
    static let shared = StoredValueLedger()

    private var database: OpaquePointer?
    private let fileManager = FileManager.default
    private let lock = NSRecursiveLock()

    private init() {
        openDatabase()
        createSchema()
        alignAnnaMailboxBalance()
    }

    deinit {
        sqlite3_close(database)
    }

    func balance(for identityKey: String) -> Int {
        lock.lock()
        defer { lock.unlock() }

        if let value = storedBalance(for: identityKey) {
            return value
        }

        let migratedValue = legacyBalance(for: identityKey) ?? 0
        store(balance: migratedValue, for: identityKey)
        return migratedValue
    }

    @discardableResult
    func add(_ amount: Int, for identityKey: String) -> Int {
        lock.lock()
        defer { lock.unlock() }

        let updatedValue = max(balance(for: identityKey) + max(amount, 0), 0)
        store(balance: updatedValue, for: identityKey)
        return updatedValue
    }

    func consume(_ amount: Int, for identityKey: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let requiredValue = max(amount, 0)
        let currentValue = balance(for: identityKey)
        guard currentValue >= requiredValue else { return false }
        store(balance: currentValue - requiredValue, for: identityKey)
        return true
    }

    private var databaseURL: URL {
        let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Morvi", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("stored_value_ledger.sqlite")
    }

    private var legacyDatabaseURL: URL {
        databaseURL.deletingLastPathComponent().appendingPathComponent("morvi.sqlite")
    }

    private func openDatabase() {
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else { return }
        _ = sqlite3_exec(database, "PRAGMA foreign_keys = ON;", nil, nil, nil)
    }

    private func createSchema() {
        _ = sqlite3_exec(
            database,
            """
            CREATE TABLE IF NOT EXISTS stored_value_ledger (
                identity_key TEXT PRIMARY KEY NOT NULL,
                balance_value INTEGER NOT NULL,
                updated_at REAL NOT NULL
            );
            """,
            nil,
            nil,
            nil
        )
    }

    private func alignAnnaMailboxBalance() {
        _ = sqlite3_exec(
            database,
            """
            UPDATE stored_value_ledger
            SET balance_value = MAX(balance_value, COALESCE((SELECT balance_value FROM stored_value_ledger WHERE identity_key = 'identity-morv'), 0)),
                updated_at = strftime('%s', 'now')
            WHERE identity_key = 'identity-anna'
              AND EXISTS (SELECT 1 FROM stored_value_ledger WHERE identity_key = 'identity-morv');

            UPDATE stored_value_ledger
            SET identity_key = 'identity-anna',
                updated_at = strftime('%s', 'now')
            WHERE identity_key = 'identity-morv'
              AND NOT EXISTS (SELECT 1 FROM stored_value_ledger WHERE identity_key = 'identity-anna');

            DELETE FROM stored_value_ledger WHERE identity_key = 'identity-morv';
            """,
            nil,
            nil,
            nil
        )
    }

    private func storedBalance(for identityKey: String) -> Int? {
        var statement: OpaquePointer?
        guard let database, sqlite3_prepare_v2(
            database,
            "SELECT balance_value FROM stored_value_ledger WHERE identity_key = ? LIMIT 1;",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, identityKey, -1, storedValueSQLiteTransient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func store(balance: Int, for identityKey: String) {
        var statement: OpaquePointer?
        guard let database, sqlite3_prepare_v2(
            database,
            """
            INSERT INTO stored_value_ledger (identity_key, balance_value, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(identity_key) DO UPDATE SET
                balance_value = excluded.balance_value,
                updated_at = excluded.updated_at;
            """,
            -1,
            &statement,
            nil
        ) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, identityKey, -1, storedValueSQLiteTransient)
        sqlite3_bind_int64(statement, 2, sqlite3_int64(balance))
        sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
        _ = sqlite3_step(statement)
    }

    private func legacyBalance(for identityKey: String) -> Int? {
        guard fileManager.fileExists(atPath: legacyDatabaseURL.path) else { return nil }
        var legacyDatabase: OpaquePointer?
        guard sqlite3_open_v2(legacyDatabaseURL.path, &legacyDatabase, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(legacyDatabase)
            return nil
        }
        defer { sqlite3_close(legacyDatabase) }
        var statement: OpaquePointer?
        guard let legacyDatabase, sqlite3_prepare_v2(
            legacyDatabase,
            "SELECT balance_value FROM credit_account WHERE account_key = ? LIMIT 1;",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, identityKey, -1, storedValueSQLiteTransient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return Int(sqlite3_column_int64(statement, 0))
    }
}
