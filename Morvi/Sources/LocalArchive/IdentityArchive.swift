import Foundation
import SQLite3
import UIKit

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct StoredIdentity: Equatable {
    let stableKey: String
    let mailbox: String
    let passcode: String
    let displayName: String
    let avatarReference: String
    let birthday: String
    let location: String
    let gender: String
    let providerReference: String?
    let entryKind: IdentityEntryKind
}

enum IdentityEntryKind: String {
    case mailbox
    case visitor
    case apple
}

enum IdentityArchiveIssue: LocalizedError {
    case duplicateMailbox
    case invalidCredentials
    case unavailable

    var errorDescription: String? {
        switch self {
        case .duplicateMailbox:
            return "Registration failed"
        case .invalidCredentials:
            return "Invalid email or password"
        case .unavailable:
            return "Unable to complete this request"
        }
    }
}

final class IdentityArchive {
    static let shared = IdentityArchive()

    private var handle: OpaquePointer?
    private let fileManager = FileManager.default
    private let accessLock = NSRecursiveLock()

    private init() {
        openArchive()
        prepareSchema()
        migrateLegacyArchiveIfNeeded()
        seedMailboxIdentity()
    }

    deinit {
        sqlite3_close(handle)
    }

    func authenticate(mailbox: String, passcode: String) throws -> StoredIdentity {
        accessLock.lock()
        defer { accessLock.unlock() }
        let statement = try makeStatement(
            """
            SELECT stable_key, mailbox, passcode, display_name, avatar_reference, birthday, location, gender, provider_reference, entry_kind
            FROM identity_archive
            WHERE lower(mailbox) = lower(?) AND passcode = ?
            LIMIT 1;
            """
        )
        defer { sqlite3_finalize(statement) }
        bind(mailbox, at: 1, to: statement)
        bind(passcode, at: 2, to: statement)
        guard sqlite3_step(statement) == SQLITE_ROW, let record = makeIdentity(from: statement) else {
            throw IdentityArchiveIssue.invalidCredentials
        }
        setActiveKey(record.stableKey)
        return record
    }

    func activeIdentity() -> StoredIdentity? {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard let statement = try? makeStatement(
            """
            SELECT a.stable_key, a.mailbox, a.passcode, a.display_name, a.avatar_reference, a.birthday, a.location, a.gender, a.provider_reference, a.entry_kind
            FROM identity_archive a
            INNER JOIN active_identity s ON s.stable_key = a.stable_key
            WHERE s.slot = 1
            LIMIT 1;
            """
        ) else { return nil }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return makeIdentity(from: statement)
    }

    func restoreVisitor() throws -> StoredIdentity {
        accessLock.lock()
        defer { accessLock.unlock() }
        let statement = try makeStatement(
            """
            SELECT stable_key, mailbox, passcode, display_name, avatar_reference, birthday, location, gender, provider_reference, entry_kind
            FROM identity_archive
            WHERE entry_kind = 'visitor'
            ORDER BY created_at DESC
            LIMIT 1;
            """
        )
        defer { sqlite3_finalize(statement) }
        if sqlite3_step(statement) == SQLITE_ROW, let record = makeIdentity(from: statement) {
            setActiveKey(record.stableKey)
            return record
        }
        let identity = StoredIdentity(
            stableKey: "identity-visitor-\(UUID().uuidString.lowercased())",
            mailbox: "",
            passcode: "",
            displayName: try uniqueVisitorName(),
            avatarReference: "default_avatar",
            birthday: "",
            location: "",
            gender: "",
            providerReference: nil,
            entryKind: .visitor
        )
        try insert(identity)
        setActiveKey(identity.stableKey)
        return identity
    }

    func register(
        mailbox: String,
        passcode: String,
        displayName: String,
        birthday: String,
        location: String,
        gender: String,
        portrait: UIImage
    ) throws {
        accessLock.lock()
        defer { accessLock.unlock() }
        let normalizedMailbox = mailbox.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard existingIdentity(mailbox: normalizedMailbox) == nil else {
            throw IdentityArchiveIssue.duplicateMailbox
        }
        let identity = StoredIdentity(
            stableKey: "identity-mailbox-\(UUID().uuidString.lowercased())",
            mailbox: normalizedMailbox,
            passcode: passcode,
            displayName: displayName,
            avatarReference: try storePortrait(portrait),
            birthday: birthday,
            location: location,
            gender: gender,
            providerReference: nil,
            entryKind: .mailbox
        )
        try insert(identity)
    }

    func resolveAppleIdentity(
        providerReference: String,
        mailbox: String?,
        displayName: String?
    ) throws -> StoredIdentity {
        accessLock.lock()
        defer { accessLock.unlock() }
        if let existing = existingIdentity(providerReference: providerReference) {
            setActiveKey(existing.stableKey)
            return existing
        }
        let identity = StoredIdentity(
            stableKey: "identity-apple-\(UUID().uuidString.lowercased())",
            mailbox: mailbox ?? "apple-\(providerReference.prefix(12))@privaterelay.appleid.com",
            passcode: "",
            displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? displayName! : "Apple",
            avatarReference: "default_avatar",
            birthday: "",
            location: "",
            gender: "",
            providerReference: providerReference,
            entryKind: .apple
        )
        try insert(identity)
        setActiveKey(identity.stableKey)
        return identity
    }

    func updateDisplayName(_ displayName: String, stableKey: String) {
        accessLock.lock()
        defer { accessLock.unlock() }
        executeUpdate("UPDATE identity_archive SET display_name = ? WHERE stable_key = ?;", values: [displayName, stableKey])
    }

    func updatePortrait(_ portrait: UIImage, stableKey: String) throws -> String {
        accessLock.lock()
        defer { accessLock.unlock() }
        let reference = try storePortrait(portrait)
        executeUpdate("UPDATE identity_archive SET avatar_reference = ? WHERE stable_key = ?;", values: [reference, stableKey])
        return reference
    }

    func resetPasscode(mailbox: String, passcode: String) -> Bool {
        (try? resetPasscodeResult(mailbox: mailbox, passcode: passcode)) ?? false
    }

    func resetPasscodeResult(mailbox: String, passcode: String) throws -> Bool {
        accessLock.lock()
        defer { accessLock.unlock() }
        let statement = try makeStatement(
            "UPDATE identity_archive SET passcode = ? WHERE lower(mailbox) = lower(?);"
        )
        defer { sqlite3_finalize(statement) }
        bind(passcode, at: 1, to: statement)
        bind(mailbox, at: 2, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw IdentityArchiveIssue.unavailable
        }
        return sqlite3_changes(handle) > 0
    }

    func clearActiveIdentity() {
        accessLock.lock()
        defer { accessLock.unlock() }
        executeUpdate("DELETE FROM active_identity WHERE slot = 1;")
    }

    func eraseIdentity(stableKey: String) {
        accessLock.lock()
        defer { accessLock.unlock() }
        executeUpdate("DELETE FROM active_identity WHERE slot = 1;")
        executeUpdate("DELETE FROM identity_archive WHERE stable_key = ?;", values: [stableKey])
    }

    func portrait(named reference: String) -> UIImage? {
        if reference.hasPrefix("portrait-") {
            return UIImage(contentsOfFile: portraitsDirectory.appendingPathComponent(reference).path)
        }
        guard reference.hasPrefix("local-avatar/") else { return nil }
        let fileName = String(reference.dropFirst("local-avatar/".count))
        return UIImage(contentsOfFile: legacyPortraitsDirectory.appendingPathComponent(fileName).path)
    }

    private var archiveURL: URL {
        let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Morvi", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("identity_archive.sqlite")
    }

    private var portraitsDirectory: URL {
        let folder = archiveURL.deletingLastPathComponent().appendingPathComponent("portraits", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private var legacyArchiveURL: URL {
        archiveURL.deletingLastPathComponent().appendingPathComponent("morvi.sqlite")
    }

    private var legacyPortraitsDirectory: URL {
        let folder = archiveURL.deletingLastPathComponent().appendingPathComponent("Avatars", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func openArchive() {
        guard sqlite3_open(archiveURL.path, &handle) == SQLITE_OK else { return }
        _ = sqlite3_exec(handle, "PRAGMA foreign_keys = ON;", nil, nil, nil)
    }

    private func prepareSchema() {
        _ = sqlite3_exec(
            handle,
            """
            CREATE TABLE IF NOT EXISTS identity_archive (
                stable_key TEXT PRIMARY KEY NOT NULL,
                mailbox TEXT UNIQUE NOT NULL,
                passcode TEXT NOT NULL,
                display_name TEXT NOT NULL,
                avatar_reference TEXT NOT NULL,
                birthday TEXT NOT NULL,
                location TEXT NOT NULL,
                gender TEXT NOT NULL,
                provider_reference TEXT UNIQUE,
                entry_kind TEXT NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS active_identity (
                slot INTEGER PRIMARY KEY CHECK(slot = 1),
                stable_key TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS identity_migration_state (
                migration_key TEXT PRIMARY KEY NOT NULL,
                completed_at REAL NOT NULL
            );
            """,
            nil,
            nil,
            nil
        )
    }

    private func migrateLegacyArchiveIfNeeded() {
        let migrationKey = "legacy-auth-v1"
        guard fileManager.fileExists(atPath: legacyArchiveURL.path),
              migrationWasCompleted(migrationKey) == false else {
            return
        }

        var legacyHandle: OpaquePointer?
        guard sqlite3_open_v2(
            legacyArchiveURL.path,
            &legacyHandle,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let legacyHandle else {
            sqlite3_close(legacyHandle)
            return
        }
        defer { sqlite3_close(legacyHandle) }

        let providerReferences = legacyProviderReferences(in: legacyHandle)
        let query = """
        SELECT
            p.stable_key,
            COALESCE(p.email, ''),
            COALESCE(s.secret_text, ''),
            p.display_name,
            COALESCE(p.avatar_asset, 'default_avatar'),
            COALESCE(p.birth_date, ''),
            COALESCE(p.location_text, ''),
            CASE p.gender_code WHEN 0 THEN 'Male' WHEN 1 THEN 'Female' WHEN 2 THEN 'Other' ELSE '' END,
            COALESCE((
                SELECT access_kind FROM local_session
                WHERE account_key = p.stable_key
                ORDER BY id DESC LIMIT 1
            ), 0)
        FROM account_profile p
        LEFT JOIN account_secret s ON s.account_key = p.stable_key
        WHERE s.account_key IS NOT NULL
           OR EXISTS (SELECT 1 FROM local_session ls WHERE ls.account_key = p.stable_key)
           OR EXISTS (
                SELECT 1 FROM local_identity_state state
                WHERE state.text_value = p.stable_key
                  AND (state.stable_key = 'guest_account_anchor' OR state.stable_key LIKE 'apple_account_anchor_%')
           );
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(legacyHandle, query, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let stableKey = legacyText(at: 0, from: statement),
                let displayName = legacyText(at: 3, from: statement)
            else { continue }
            let accessKind = Int(sqlite3_column_int(statement, 8))
            let entryKind: IdentityEntryKind
            if accessKind == 1 || stableKey.hasPrefix("acct-guest-") {
                entryKind = .visitor
            } else if accessKind == 2 || stableKey.hasPrefix("acct-apple-") {
                entryKind = .apple
            } else {
                entryKind = .mailbox
            }
            let providerReference = providerReferences[stableKey]
            let rawMailbox = legacyText(at: 1, from: statement) ?? ""
            let mailbox: String
            if rawMailbox.isEmpty, entryKind == .apple, let providerReference {
                mailbox = "apple-\(providerReference.prefix(12))@privaterelay.appleid.com"
            } else {
                mailbox = rawMailbox
            }
            insertIfMissing(
                StoredIdentity(
                    stableKey: stableKey,
                    mailbox: mailbox,
                    passcode: legacyText(at: 2, from: statement) ?? "",
                    displayName: displayName,
                    avatarReference: legacyText(at: 4, from: statement) ?? "default_avatar",
                    birthday: legacyText(at: 5, from: statement) ?? "",
                    location: legacyText(at: 6, from: statement) ?? "",
                    gender: legacyText(at: 7, from: statement) ?? "",
                    providerReference: providerReference,
                    entryKind: entryKind
                )
            )
        }

        if activeIdentity() == nil,
           let activeKey = legacyActiveIdentityKey(in: legacyHandle),
           identity(query: "stable_key = ?", value: activeKey) != nil {
            setActiveKey(activeKey)
        }
        executeUpdate(
            "INSERT OR REPLACE INTO identity_migration_state (migration_key, completed_at) VALUES (?, ?);",
            values: [migrationKey, String(Date().timeIntervalSince1970)]
        )
    }

    private func migrationWasCompleted(_ key: String) -> Bool {
        guard let statement = try? makeStatement(
            "SELECT 1 FROM identity_migration_state WHERE migration_key = ? LIMIT 1;"
        ) else { return false }
        defer { sqlite3_finalize(statement) }
        bind(key, at: 1, to: statement)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func legacyProviderReferences(in legacyHandle: OpaquePointer) -> [String: String] {
        let query = """
        SELECT stable_key, text_value
        FROM local_identity_state
        WHERE stable_key LIKE 'apple_account_anchor_%';
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(legacyHandle, query, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return [:]
        }
        defer { sqlite3_finalize(statement) }
        var references: [String: String] = [:]
        let prefix = "apple_account_anchor_"
        while sqlite3_step(statement) == SQLITE_ROW,
              let anchor = legacyText(at: 0, from: statement),
              let stableKey = legacyText(at: 1, from: statement) {
            references[stableKey] = String(anchor.dropFirst(prefix.count))
        }
        return references
    }

    private func legacyActiveIdentityKey(in legacyHandle: OpaquePointer) -> String? {
        let query = """
        SELECT account_key FROM local_session
        WHERE is_active = 1 AND (expires_at IS NULL OR expires_at > datetime('now'))
        ORDER BY id DESC LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(legacyHandle, query, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return nil
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return legacyText(at: 0, from: statement)
    }

    private func insertIfMissing(_ identity: StoredIdentity) {
        guard let statement = try? makeStatement(
            """
            INSERT OR IGNORE INTO identity_archive (
                stable_key, mailbox, passcode, display_name, avatar_reference, birthday, location, gender, provider_reference, entry_kind, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        ) else { return }
        defer { sqlite3_finalize(statement) }
        bind(identity.stableKey, at: 1, to: statement)
        bind(identity.mailbox, at: 2, to: statement)
        bind(identity.passcode, at: 3, to: statement)
        bind(identity.displayName, at: 4, to: statement)
        bind(identity.avatarReference, at: 5, to: statement)
        bind(identity.birthday, at: 6, to: statement)
        bind(identity.location, at: 7, to: statement)
        bind(identity.gender, at: 8, to: statement)
        if let providerReference = identity.providerReference {
            bind(providerReference, at: 9, to: statement)
        } else {
            sqlite3_bind_null(statement, 9)
        }
        bind(identity.entryKind.rawValue, at: 10, to: statement)
        sqlite3_bind_double(statement, 11, Date().timeIntervalSince1970)
        _ = sqlite3_step(statement)
    }

    private func legacyText(at index: Int32, from statement: OpaquePointer?) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func seedMailboxIdentity() {
        alignAnnaMailboxIdentity()
        guard existingIdentity(mailbox: "morv@gmail.com") == nil else { return }
        let identity = StoredIdentity(
            stableKey: "identity-anna",
            mailbox: "morv@gmail.com",
            passcode: "morv",
            displayName: "Anna",
            avatarReference: "default_avatar",
            birthday: "",
            location: "",
            gender: "",
            providerReference: nil,
            entryKind: .mailbox
        )
        try? insert(identity)
    }

    private func alignAnnaMailboxIdentity() {
        let mailboxIdentity = existingIdentity(mailbox: "morv@gmail.com")
        let annaIdentity = existingIdentity(stableKey: "identity-anna")
        if let annaIdentity {
            if let mailboxIdentity, mailboxIdentity.stableKey != annaIdentity.stableKey {
                executeUpdate(
                    "UPDATE identity_archive SET mailbox = ? WHERE stable_key = ?;",
                    values: ["removed-\(mailboxIdentity.stableKey)@morvi.local", mailboxIdentity.stableKey]
                )
            }
            executeUpdate(
                """
                UPDATE identity_archive
                SET mailbox = ?, passcode = ?, entry_kind = ?, provider_reference = NULL
                WHERE stable_key = ?;
                """,
                values: ["morv@gmail.com", "morv", IdentityEntryKind.mailbox.rawValue, annaIdentity.stableKey]
            )
            executeUpdate("DELETE FROM identity_archive WHERE stable_key = ?;", values: ["identity-morv"])
            executeUpdate(
                "UPDATE active_identity SET stable_key = ? WHERE stable_key = ?;",
                values: ["identity-anna", "identity-morv"]
            )
            return
        }
        guard let mailboxIdentity else { return }
        if mailboxIdentity.stableKey != "identity-anna" {
            executeUpdate(
                """
                UPDATE identity_archive
                SET stable_key = ?, passcode = ?, display_name = ?, avatar_reference = ?,
                    birthday = '', location = '', gender = '', provider_reference = NULL, entry_kind = ?
                WHERE stable_key = ?;
                """,
                values: ["identity-anna", "morv", "Anna", "default_avatar", IdentityEntryKind.mailbox.rawValue, mailboxIdentity.stableKey]
            )
            executeUpdate(
                "UPDATE active_identity SET stable_key = ? WHERE stable_key = ?;",
                values: ["identity-anna", mailboxIdentity.stableKey]
            )
        } else {
            executeUpdate(
                """
                UPDATE identity_archive
                SET passcode = ?, provider_reference = NULL, entry_kind = ?
                WHERE stable_key = ?;
                """,
                values: ["morv", IdentityEntryKind.mailbox.rawValue, "identity-anna"]
            )
        }
    }

    private func insert(_ identity: StoredIdentity) throws {
        let statement = try makeStatement(
            """
            INSERT INTO identity_archive (
                stable_key, mailbox, passcode, display_name, avatar_reference, birthday, location, gender, provider_reference, entry_kind, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )
        defer { sqlite3_finalize(statement) }
        bind(identity.stableKey, at: 1, to: statement)
        bind(identity.mailbox, at: 2, to: statement)
        bind(identity.passcode, at: 3, to: statement)
        bind(identity.displayName, at: 4, to: statement)
        bind(identity.avatarReference, at: 5, to: statement)
        bind(identity.birthday, at: 6, to: statement)
        bind(identity.location, at: 7, to: statement)
        bind(identity.gender, at: 8, to: statement)
        if let providerReference = identity.providerReference {
            bind(providerReference, at: 9, to: statement)
        } else {
            sqlite3_bind_null(statement, 9)
        }
        bind(identity.entryKind.rawValue, at: 10, to: statement)
        sqlite3_bind_double(statement, 11, Date().timeIntervalSince1970)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw IdentityArchiveIssue.unavailable
        }
    }

    private func existingIdentity(mailbox: String) -> StoredIdentity? {
        identity(query: "mailbox = ?", value: mailbox)
    }

    private func existingIdentity(stableKey: String) -> StoredIdentity? {
        identity(query: "stable_key = ?", value: stableKey)
    }

    private func existingIdentity(providerReference: String) -> StoredIdentity? {
        identity(query: "provider_reference = ?", value: providerReference)
    }

    private func identity(query: String, value: String) -> StoredIdentity? {
        guard let statement = try? makeStatement(
            """
            SELECT stable_key, mailbox, passcode, display_name, avatar_reference, birthday, location, gender, provider_reference, entry_kind
            FROM identity_archive
            WHERE \(query)
            LIMIT 1;
            """
        ) else { return nil }
        defer { sqlite3_finalize(statement) }
        bind(value, at: 1, to: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return makeIdentity(from: statement)
    }

    private func makeIdentity(from statement: OpaquePointer?) -> StoredIdentity? {
        guard
            let stableKey = text(at: 0, from: statement),
            let mailbox = text(at: 1, from: statement),
            let passcode = text(at: 2, from: statement),
            let displayName = text(at: 3, from: statement),
            let avatarReference = text(at: 4, from: statement),
            let birthday = text(at: 5, from: statement),
            let location = text(at: 6, from: statement),
            let gender = text(at: 7, from: statement),
            let entryKindText = text(at: 9, from: statement),
            let entryKind = IdentityEntryKind(rawValue: entryKindText)
        else { return nil }
        return StoredIdentity(
            stableKey: stableKey,
            mailbox: mailbox,
            passcode: passcode,
            displayName: displayName,
            avatarReference: avatarReference,
            birthday: birthday,
            location: location,
            gender: gender,
            providerReference: text(at: 8, from: statement),
            entryKind: entryKind
        )
    }

    private func setActiveKey(_ stableKey: String) {
        executeUpdate(
            "INSERT OR REPLACE INTO active_identity (slot, stable_key) VALUES (1, ?);",
            values: [stableKey]
        )
    }

    private func storePortrait(_ portrait: UIImage) throws -> String {
        let fileName = "avatar-\(UUID().uuidString.lowercased()).jpg"
        guard let data = portrait.jpegData(compressionQuality: 0.88) else {
            throw IdentityArchiveIssue.unavailable
        }
        try data.write(to: legacyPortraitsDirectory.appendingPathComponent(fileName), options: .atomic)
        return "local-avatar/\(fileName)"
    }

    private func makeStatement(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw IdentityArchiveIssue.unavailable
        }
        return statement
    }

    private func executeUpdate(_ sql: String, values: [String] = []) {
        guard let statement = try? makeStatement(sql) else { return }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            bind(value, at: Int32(index + 1), to: statement)
        }
        _ = sqlite3_step(statement)
    }

    private func bind(_ value: String, at index: Int32, to statement: OpaquePointer?) {
        sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
    }

    private func text(at index: Int32, from statement: OpaquePointer?) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func randomLetters() -> String {
        String((0..<6).compactMap { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".randomElement() })
    }

    private func uniqueVisitorName() throws -> String {
        for _ in 0..<100 {
            let name = "Guest-\(randomLetters())"
            guard identity(query: "display_name = ?", value: name) == nil else { continue }
            return name
        }
        throw IdentityArchiveIssue.unavailable
    }
}
