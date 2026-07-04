import Foundation
import SQLite3

final class LocalStore {
    static let shared = LocalStore()

    private let queue = DispatchQueue(label: "morvi.local.store")
    private let queueKey = DispatchSpecificKey<Bool>()
    private var handle: OpaquePointer?

    private init() {
        queue.setSpecific(key: queueKey, value: true)
    }

    func prepare() throws {
        try access {
            if handle != nil { return }
            let databaseURL = try Self.databaseURL()
            try FileManager.default.createDirectory(
                at: databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            var database: OpaquePointer?
            let result = sqlite3_open_v2(
                databaseURL.path,
                &database,
                SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
                nil
            )
            guard result == SQLITE_OK, let database else {
                let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
                if let database {
                    sqlite3_close(database)
                }
                throw LocalStoreError.openFailed(detail)
            }
            handle = database
            try execute("PRAGMA foreign_keys = ON;")
            try execute("PRAGMA journal_mode = WAL;")
            try execute("PRAGMA synchronous = NORMAL;")
        }
    }

    deinit {
        if let handle {
            sqlite3_close(handle)
        }
    }

    func execute(_ sql: String) throws {
        try access {
            try executeUnlocked(sql)
        }
    }

    func readInt(_ sql: String) throws -> Int {
        try access {
            guard let handle else { throw LocalStoreError.missingDatabase }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
                throw LocalStoreError.statementFailed(lastError)
            }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int64(statement, 0))
        }
    }

    func readText(_ sql: String) throws -> String? {
        try access {
            guard let handle else { throw LocalStoreError.missingDatabase }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
                throw LocalStoreError.statementFailed(lastError)
            }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            guard let text = sqlite3_column_text(statement, 0) else { return nil }
            return String(cString: text)
        }
    }

    func write(_ sql: String, bindings: [LocalStoreValue]) throws {
        try access {
            guard let handle else { throw LocalStoreError.missingDatabase }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
                throw LocalStoreError.statementFailed(lastError)
            }
            defer { sqlite3_finalize(statement) }
            try bind(bindings, to: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw LocalStoreError.executionFailed(lastError)
            }
        }
    }

    func transaction(_ work: () throws -> Void) throws {
        try access {
            try executeUnlocked("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try work()
                try executeUnlocked("COMMIT;")
            } catch {
                try? executeUnlocked("ROLLBACK;")
                throw error
            }
        }
    }

    private func access<T>(_ work: () throws -> T) throws -> T {
        if DispatchQueue.getSpecific(key: queueKey) == true {
            return try work()
        }
        return try queue.sync {
            try work()
        }
    }

    private func executeUnlocked(_ sql: String) throws {
        guard let handle else { throw LocalStoreError.missingDatabase }
        var errorMessage: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(handle, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let detail = errorMessage.map { String(cString: $0) } ?? lastError
            if let errorMessage {
                sqlite3_free(errorMessage)
            }
            throw LocalStoreError.executionFailed(detail)
        }
    }

    private func bind(_ values: [LocalStoreValue], to statement: OpaquePointer?) throws {
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            let result: Int32
            switch value {
            case .text(let text):
                result = sqlite3_bind_text(statement, position, text, -1, SQLITE_TRANSIENT)
            case .int(let number):
                result = sqlite3_bind_int64(statement, position, Int64(number))
            case .double(let number):
                result = sqlite3_bind_double(statement, position, number)
            case .null:
                result = sqlite3_bind_null(statement, position)
            }
            guard result == SQLITE_OK else {
                throw LocalStoreError.statementFailed(lastError)
            }
        }
    }

    private var lastError: String {
        guard let handle else { return "missing database" }
        return String(cString: sqlite3_errmsg(handle))
    }

    private static func databaseURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appendingPathComponent("Morvi", isDirectory: true)
            .appendingPathComponent("morvi.sqlite")
    }
}
