import Foundation

enum LocalDateText {
    static func now() -> String {
        formatter.string(from: Date())
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
