import Foundation

struct TimeEntry: Identifiable, Equatable {
    var id: Int64?
    var name: String
    var notes: String
    var projectId: Int64
    var categoryId: Int64?
    var startDate: Date
    var endDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var syncProviderRawValue: String?
    var syncCalendarIdentifier: String?
    var syncEventIdentifier: String?

    var syncProvider: SyncProvider? {
        get {
            guard let syncProviderRawValue else { return nil }
            return SyncProvider(rawValue: syncProviderRawValue)
        }
        set {
            syncProviderRawValue = newValue?.rawValue
        }
    }

    var isSynced: Bool {
        syncProvider != nil && syncEventIdentifier != nil
    }

    // Compatibility shim for older callsites while the UI migrates.
    var calendarEventIdentifier: String? {
        get { syncEventIdentifier }
        set { syncEventIdentifier = newValue }
    }

    var duration: TimeInterval {
        guard let endDate = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        return endDate.timeIntervalSince(startDate)
    }

    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    init(
        id: Int64? = nil,
        name: String,
        notes: String = "",
        projectId: Int64,
        categoryId: Int64? = nil,
        startDate: Date,
        endDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncProvider: SyncProvider? = nil,
        syncCalendarIdentifier: String? = nil,
        syncEventIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.projectId = projectId
        self.categoryId = categoryId
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncProviderRawValue = syncProvider?.rawValue
        self.syncCalendarIdentifier = syncCalendarIdentifier
        self.syncEventIdentifier = syncEventIdentifier
    }
}
