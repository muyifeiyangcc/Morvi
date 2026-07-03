import Foundation

enum LocalStoreError: Error, LocalizedError {
    case openFailed(String)
    case statementFailed(String)
    case executionFailed(String)
    case missingDatabase

    var errorDescription: String? {
        switch self {
        case .openFailed(let detail):
            return "Open local store failed: \(detail)"
        case .statementFailed(let detail):
            return "Prepare local statement failed: \(detail)"
        case .executionFailed(let detail):
            return "Execute local statement failed: \(detail)"
        case .missingDatabase:
            return "Local store is not open."
        }
    }
}
