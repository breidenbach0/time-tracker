import Foundation

enum SyncProvider: String, CaseIterable, Codable, Hashable, Identifiable {
    case apple

    var id: String { rawValue }

    var displayName: String {
        "Apple Calendar"
    }

    var badgeTitle: String {
        "Apple"
    }
}

struct SyncDestination: Identifiable, Equatable, Hashable, Codable {
    let provider: SyncProvider
    let calendarIdentifier: String
    let displayName: String
    let colorHex: String

    var id: String {
        "\(provider.rawValue)::\(calendarIdentifier)"
    }
}

enum SyncConnectionState: Equatable {
    case unavailable(String)
    case disconnected
    case connecting
    case connected
    case restricted(String)

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }

    var statusTitle: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .disconnected:
            return "Not Connected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .restricted:
            return "Restricted"
        }
    }

    var detailText: String {
        switch self {
        case .unavailable(let message), .restricted(let message):
            return message
        case .disconnected:
            return "Connect this provider to sync recordings into one calendar."
        case .connecting:
            return "Complete the authentication flow to finish connecting."
        case .connected:
            return "Choose one writable calendar and TimeTracker will sync new recordings there."
        }
    }
}

struct SyncPreferences: Equatable {
    var autoSyncEnabled: Bool
    var activeDestinationID: String?
    var appleDestinationID: String?
}

struct SyncRoute: Equatable {
    let provider: SyncProvider
    let calendarIdentifier: String?
    let destinationID: String?
}

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
    static func dateFormatter(
        for format: DateDisplayFormat,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = format.rawValue
        return formatter
    }

    static func timeFormatter(
        for format: TimeDisplayFormat,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = format == .twentyFourHour ? "HH:mm" : "h:mm a"
        return formatter
    }
}

enum SyncRouteResolver {
    static func resolve(for entry: TimeEntry, preferences: SyncPreferences) -> SyncRoute? {
        if let provider = entry.syncProvider,
           entry.syncEventIdentifier != nil {
            let destinationID = entry.syncCalendarIdentifier.map {
                SyncDestination(
                    provider: provider,
                    calendarIdentifier: $0,
                    displayName: $0,
                    colorHex: "#4A90D9"
                ).id
            }

            return SyncRoute(
                provider: provider,
                calendarIdentifier: entry.syncCalendarIdentifier,
                destinationID: destinationID
            )
        }

        guard preferences.autoSyncEnabled,
              let activeDestinationID = preferences.activeDestinationID else {
            return nil
        }

        let parts = activeDestinationID.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 3,
              let provider = SyncProvider(rawValue: String(parts[0])) else {
            return nil
        }

        let calendarIdentifier = activeDestinationID.components(separatedBy: "::").dropFirst().joined(separator: "::")
        guard !calendarIdentifier.isEmpty else { return nil }

        return SyncRoute(
            provider: provider,
            calendarIdentifier: calendarIdentifier,
            destinationID: activeDestinationID
        )
    }
}
