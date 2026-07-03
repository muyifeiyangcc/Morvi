import Foundation
import SQLite3

enum LocalStoreValue {
    case text(String)
    case int(Int)
    case double(Double)
    case null
}

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
