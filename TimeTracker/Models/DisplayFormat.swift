import Foundation

enum DateDisplayFormat: String, CaseIterable, Identifiable {
    case dayMonthYear = "dd.MM.yy"
    case monthDayYear = "MM.dd.yy"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dayMonthYear:
            return "DD.MM.YY"
        case .monthDayYear:
            return "MM.DD.YY"
        }
    }
}

enum TimeDisplayFormat: String, CaseIterable, Identifiable {
    case twentyFourHour
    case twelveHour

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twentyFourHour:
            return "24 Hour"
        case .twelveHour:
            return "12 Hour"
        }
    }
}

enum DisplayPreferenceKeys {
    static let dateFormat = "display_preferences.date_format"
    static let timeFormat = "display_preferences.time_format"
}

enum DisplayFormatter {
    // DateFormatter is expensive to create and these are requested during every render,
    // so instances are cached per pattern and locale. They are never mutated after creation.
    private static var cache: [String: DateFormatter] = [:]
    private static let cacheLock = NSLock()

    static func dateFormatter(
        for format: DateDisplayFormat,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> DateFormatter {
        formatter(pattern: format.rawValue, locale: locale)
    }

    static func timeFormatter(
        for format: TimeDisplayFormat,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> DateFormatter {
        formatter(pattern: format == .twentyFourHour ? "HH:mm" : "h:mm a", locale: locale)
    }

    static func formatter(pattern: String, locale: Locale = .current) -> DateFormatter {
        let key = "\(locale.identifier)|\(pattern)"
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cached = cache[key] {
            return cached
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = pattern
        cache[key] = formatter
        return formatter
    }
}
