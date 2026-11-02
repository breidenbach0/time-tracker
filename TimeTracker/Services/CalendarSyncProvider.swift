import Foundation

@MainActor
protocol CalendarSyncProvider: AnyObject {
    var provider: SyncProvider { get }
    var connectionState: SyncConnectionState { get }
    var availableDestinations: [SyncDestination] { get }

    func refresh() async
    func connect() async
    func disconnect()
    func sync(entry: TimeEntry, destination: SyncDestination?, projectName: String, categoryName: String?) async throws -> String?
    func deleteSync(for entry: TimeEntry) async
}
