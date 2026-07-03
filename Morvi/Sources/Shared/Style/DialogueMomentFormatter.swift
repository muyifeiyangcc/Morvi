import Foundation

enum DialogueMomentFormatter {
    static func title(
        for eventDate: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> String {
        let elapsedSeconds = max(0, referenceDate.timeIntervalSince(eventDate))
        if elapsedSeconds < 60 {
            return "Just now"
        }
        if elapsedSeconds < 10 * 60 {
            return "5 min ago"
        }
        if elapsedSeconds < 30 * 60 {
            return "10 min ago"
        }
        if elapsedSeconds < 60 * 60 {
            return "30 min ago"
        }

        let englishCalendar = configuredCalendar(from: calendar)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = englishCalendar

        if englishCalendar.isDate(eventDate, inSameDayAs: referenceDate) {
            formatter.dateFormat = "h:mm a"
        } else if englishCalendar.component(.year, from: eventDate) == englishCalendar.component(.year, from: referenceDate) {
            formatter.dateFormat = "MMM d, h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy, h:mm a"
        }
        return formatter.string(from: eventDate)
    }

    private static func configuredCalendar(from calendar: Calendar) -> Calendar {
        var englishCalendar = calendar
        englishCalendar.locale = Locale(identifier: "en_US_POSIX")
        return englishCalendar
    }
}
