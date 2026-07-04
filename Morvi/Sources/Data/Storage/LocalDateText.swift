import Foundation

enum LocalDateText {
    static func now() -> String {
        string(from: Date())
    }

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from text: String) -> Date? {
        formatter.date(from: text)
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
