import Combine
import Foundation

@MainActor
final class CalendarSyncCoordinator: ObservableObject {
    static let shared = CalendarSyncCoordinator()

    @Published private(set) var appleProvider: AppleCalendarProvider
    @Published private(set) var preferences: SyncPreferences

    private let settingsStore: SyncSettingsStore
    private var cancellables = Set<AnyCancellable>()

    private init(
        settingsStore: SyncSettingsStore = SyncSettingsStore()
    ) {
        let appleProvider = AppleCalendarProvider()

        self.appleProvider = appleProvider
        self.settingsStore = settingsStore

        settingsStore.migrateLegacyAppleSelectionIfNeeded()
        self.preferences = settingsStore.preferences

        appleProvider.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var autoSyncEnabled: Bool {
        preferences.autoSyncEnabled
    }

    var activeDestination: SyncDestination? {
        guard let activeDestinationID = preferences.activeDestinationID else { return nil }
        return allDestinations.first { $0.id == activeDestinationID }
    }

    var allDestinations: [SyncDestination] {
        appleProvider.availableDestinations
    }

    func refresh() async {
        await appleProvider.refresh()
        normalizePreferences()
    }

    func connect(_ provider: SyncProvider) async {
        await appleProvider.connect()

        normalizePreferences()
        ensureDestinationSelection(for: provider)

        if appleProvider.connectionState.isConnected, activeDestination != nil {
            setAutoSyncEnabled(true)
        }
    }

    func setAutoSyncEnabled(_ isEnabled: Bool) {
        preferences.autoSyncEnabled = isEnabled && preferences.activeDestinationID != nil
        settingsStore.preferences = preferences
        NotificationCenter.default.post(name: .syncPreferencesDidChange, object: nil)
    }

    func setSelectedDestinationID(_ destinationID: String?, for provider: SyncProvider) {
        settingsStore.setSelectedDestinationID(destinationID, for: provider)
        preferences.appleDestinationID = destinationID
        preferences.activeDestinationID = destinationID
        preferences.autoSyncEnabled = destinationID != nil && preferences.autoSyncEnabled
        settingsStore.preferences = preferences
        NotificationCenter.default.post(name: .syncPreferencesDidChange, object: nil)
    }

    func syncEntryIfNeeded(_ entry: TimeEntry) async -> TimeEntry {
        var syncedEntry = entry
        guard appleProvider.connectionState.isConnected, activeDestination != nil else {
            return syncedEntry
        }

        guard let route = SyncRouteResolver.resolve(for: entry, preferences: preferences) else {
            return syncedEntry
        }

        let projectName = DatabaseManager.shared.fetchProject(withId: entry.projectId)?.name ?? "Recording"
        let categoryName = entry.categoryId.flatMap { DatabaseManager.shared.fetchCategory(withId: $0)?.name }
        let destination = destination(for: route)

        do {
            let eventIdentifier = try await provider(for: route.provider).sync(
                entry: entry,
                destination: destination,
                projectName: projectName,
                categoryName: categoryName
            )

            guard eventIdentifier != nil else { return syncedEntry }

            syncedEntry.syncProvider = route.provider
            syncedEntry.syncCalendarIdentifier = destination?.calendarIdentifier ?? entry.syncCalendarIdentifier
            syncedEntry.syncEventIdentifier = eventIdentifier
            DatabaseManager.shared.updateTimeEntry(syncedEntry)
            return syncedEntry
        } catch {
            print("Calendar sync error: \(error)")
            return syncedEntry
        }
    }

    func deleteSyncIfNeeded(for entry: TimeEntry) async {
        guard let syncProvider = entry.syncProvider else { return }
        await provider(for: syncProvider).deleteSync(for: entry)
    }

    private func provider(for provider: SyncProvider) -> CalendarSyncProvider {
        appleProvider
    }

    private func destination(for route: SyncRoute) -> SyncDestination? {
        if let destinationID = route.destinationID,
           let exactDestination = allDestinations.first(where: { $0.id == destinationID }) {
            return exactDestination
        }

        if let calendarIdentifier = route.calendarIdentifier,
           let matchedDestination = allDestinations.first(where: {
               $0.provider == route.provider && $0.calendarIdentifier == calendarIdentifier
           }) {
            return matchedDestination
        }

        if let calendarIdentifier = route.calendarIdentifier {
            return SyncDestination(
                provider: route.provider,
                calendarIdentifier: calendarIdentifier,
                displayName: calendarIdentifier,
                colorHex: "#4A90D9"
            )
        }

        return activeDestination
    }

    private func normalizePreferences() {
        if let appleSelection = settingsStore.selectedDestinationID(for: .apple),
           appleProvider.availableDestinations.contains(where: { $0.id == appleSelection }) {
            preferences.appleDestinationID = appleSelection
        } else {
            preferences.appleDestinationID = nil
        }

        if let activeDestinationID = preferences.activeDestinationID,
           !allDestinations.contains(where: { $0.id == activeDestinationID }) {
            preferences.activeDestinationID = preferences.appleDestinationID
        }

        if preferences.activeDestinationID == nil {
            preferences.autoSyncEnabled = false
        }

        settingsStore.preferences = preferences
        NotificationCenter.default.post(name: .syncPreferencesDidChange, object: nil)
    }

    private func ensureDestinationSelection(for provider: SyncProvider) {
        guard let destination = preferredDestination(from: appleProvider.availableDestinations) else { return }
        setSelectedDestinationID(destination.id, for: provider)
    }

    private func preferredDestination(from destinations: [SyncDestination]) -> SyncDestination? {
        destinations.first(where: { $0.displayName == "TimeTracker" }) ?? destinations.first
    }
}
