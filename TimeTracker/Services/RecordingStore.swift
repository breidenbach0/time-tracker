import Foundation

@MainActor
final class RecordingStore {
    static let shared = RecordingStore()

    private init() {}

    func saveEntry(_ entry: TimeEntry) -> TimeEntry {
        var storedEntry = entry
        let trimmedName = storedEntry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        storedEntry.notes = storedEntry.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            storedEntry.name = DatabaseManager.shared.nextRecordingName(for: storedEntry.projectId)
        } else {
            storedEntry.name = trimmedName
        }

        if storedEntry.id == nil {
            storedEntry.id = DatabaseManager.shared.insertTimeEntry(storedEntry)
        } else {
            DatabaseManager.shared.updateTimeEntry(storedEntry)
        }

        return storedEntry
    }

    func deleteEntry(_ entry: TimeEntry) {
        DatabaseManager.shared.deleteTimeEntry(entry)
    }
}
