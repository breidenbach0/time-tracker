import AppKit
import EventKit
import Foundation

@MainActor
final class AppleCalendarProvider: ObservableObject, CalendarSyncProvider {
    let provider: SyncProvider = .apple

    @Published private(set) var connectionState: SyncConnectionState = .disconnected
    @Published private(set) var availableDestinations: [SyncDestination] = []

    static let appCalendarTitle = "TimeTracker"

    private let eventStore = EKEventStore()

    init() {
        refreshAuthorization()
        refreshDestinations()

        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        refreshAuthorization()
        refreshDestinations()
    }

    func connect() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        connectionState = .connecting

        switch status {
        case .notDetermined:
            do {
                if #available(macOS 14.0, *) {
                    _ = try await eventStore.requestFullAccessToEvents()
                } else {
                    _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                        eventStore.requestAccess(to: .event) { granted, error in
                            if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: granted)
                            }
                        }
                    }
                }
            } catch {
                connectionState = .restricted("TimeTracker could not request Apple Calendar access: \(error.localizedDescription)")
            }
        case .authorized, .fullAccess:
            break
        case .restricted:
            connectionState = .restricted("Apple Calendar access is restricted on this Mac.")
        case .denied, .writeOnly:
            connectionState = .restricted("Grant Calendar access in System Settings to enable Apple Calendar sync.")
        @unknown default:
            connectionState = .restricted("Apple Calendar access is unavailable.")
        }

        if hasReadableAccess {
            do {
                _ = try ensureAppCalendar()
            } catch {
                print("Apple Calendar creation error: \(error)")
            }
        }

        await refresh()
    }

    func disconnect() {
        availableDestinations = []
        refreshAuthorization()
    }

    func sync(entry: TimeEntry, destination: SyncDestination?, projectName: String, categoryName: String?) async throws -> String? {
        guard hasReadableAccess else { return entry.syncEventIdentifier }

        let targetCalendar = selectedCalendar(for: entry, destination: destination) ?? eventStore.defaultCalendarForNewEvents
        guard let targetCalendar else { return entry.syncEventIdentifier }

        let event: EKEvent
        if let existingIdentifier = entry.syncEventIdentifier,
           let existingEvent = eventStore.event(withIdentifier: existingIdentifier) {
            event = existingEvent
        } else {
            event = EKEvent(eventStore: eventStore)
        }

        event.calendar = targetCalendar
        event.title = entry.name
        event.startDate = entry.startDate
        event.endDate = entry.endDate ?? entry.startDate.addingTimeInterval(60)
        event.notes = noteText(projectName: projectName, categoryName: categoryName, entryNotes: entry.notes)

        try eventStore.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    func deleteSync(for entry: TimeEntry) async {
        guard hasReadableAccess,
              let identifier = entry.syncEventIdentifier,
              let event = eventStore.event(withIdentifier: identifier) else {
            return
        }

        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
        } catch {
            print("Apple Calendar delete error: \(error)")
        }
    }

    private func refreshAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)

        if #available(macOS 14.0, *) {
            switch status {
            case .notDetermined:
                connectionState = .disconnected
            case .restricted:
                connectionState = .restricted("Apple Calendar access is restricted on this Mac.")
            case .denied, .writeOnly:
                connectionState = .restricted("Grant Calendar access in System Settings to enable Apple Calendar sync.")
            case .authorized, .fullAccess:
                connectionState = .connected
            @unknown default:
                connectionState = .restricted("Apple Calendar access is unavailable.")
            }
        } else {
            switch status {
            case .notDetermined:
                connectionState = .disconnected
            case .restricted:
                connectionState = .restricted("Apple Calendar access is restricted on this Mac.")
            case .denied:
                connectionState = .restricted("Grant Calendar access in System Settings to enable Apple Calendar sync.")
            case .authorized:
                connectionState = .connected
            case .fullAccess:
                connectionState = .connected
            case .writeOnly:
                connectionState = .restricted("Grant full Calendar access in System Settings to enable Apple Calendar sync.")
            @unknown default:
                connectionState = .restricted("Apple Calendar access is unavailable.")
            }
        }
    }

    private func refreshDestinations() {
        guard hasReadableAccess else {
            availableDestinations = []
            return
        }

        do {
            _ = try ensureAppCalendar()
        } catch {
            print("Apple Calendar refresh error: \(error)")
        }

        availableDestinations = eventStore.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .sorted { lhs, rhs in
                if lhs.title == Self.appCalendarTitle { return true }
                if rhs.title == Self.appCalendarTitle { return false }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .map {
                SyncDestination(
                    provider: .apple,
                    calendarIdentifier: $0.calendarIdentifier,
                    displayName: $0.title,
                    colorHex: Self.colorHex(for: $0)
                )
            }
    }

    private var hasReadableAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)

        if #available(macOS 14.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    private func selectedCalendar(for entry: TimeEntry, destination: SyncDestination?) -> EKCalendar? {
        if let existingIdentifier = entry.syncEventIdentifier,
           let existingEvent = eventStore.event(withIdentifier: existingIdentifier) {
            return existingEvent.calendar
        }

        if let calendarIdentifier = entry.syncCalendarIdentifier ?? destination?.calendarIdentifier {
            return eventStore.calendar(withIdentifier: calendarIdentifier)
        }

        return nil
    }

    private func ensureAppCalendar() throws -> EKCalendar? {
        if let existingCalendar = eventStore.calendars(for: .event).first(where: {
            $0.title == Self.appCalendarTitle && $0.allowsContentModifications
        }) {
            return existingCalendar
        }

        guard let source = preferredCalendarSource() else {
            return nil
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = Self.appCalendarTitle
        calendar.source = source
        calendar.cgColor = NSColor.systemGray.cgColor

        try eventStore.saveCalendar(calendar, commit: true)
        return calendar
    }

    private func preferredCalendarSource() -> EKSource? {
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            return defaultSource
        }

        return eventStore.sources.first(where: { $0.sourceType == .calDAV })
            ?? eventStore.sources.first(where: { $0.sourceType == .local })
            ?? eventStore.sources.first
    }

    private func noteText(projectName: String, categoryName: String?, entryNotes: String) -> String {
        var parts = ["Tracked with TimeTracker", "Project: \(projectName)"]

        if let categoryName, !categoryName.isEmpty {
            parts.append("Category: \(categoryName)")
        }

        let trimmedNotes = entryNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            parts.append("Notes:\n\(trimmedNotes)")
        }

        return parts.joined(separator: "\n")
    }

    private static func colorHex(for calendar: EKCalendar) -> String {
        guard let color = calendar.cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent,
            options: nil
        ),
        let components = color.components else {
            return "#4A90D9"
        }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        switch components.count {
        case 2:
            red = components[0]
            green = components[0]
            blue = components[0]
        default:
            red = components[0]
            green = components[1]
            blue = components[2]
        }

        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}
