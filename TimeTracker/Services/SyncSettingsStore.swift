import Foundation
import Combine

final class SyncSettingsStore {
    private enum Key {
        static let autoSyncEnabled = "sync_auto_enabled"
        static let activeDestinationID = "sync_active_destination_id"
        static let appleDestinationID = "sync_apple_destination_id"
        static let didMigrateLegacyPreferences = "sync_did_migrate_legacy_preferences"
    }

    private let userDefaults: UserDefaults
    private let databaseManager: DatabaseManager

    init(
        userDefaults: UserDefaults = .standard,
        databaseManager: DatabaseManager = .shared
    ) {
        self.userDefaults = userDefaults
        self.databaseManager = databaseManager

        migrateLegacyAppleSelectionIfNeeded()
        migrateUserDefaultsToDatabaseIfNeeded()
    }

    var preferences: SyncPreferences {
        get {
            SyncPreferences(
                autoSyncEnabled: bool(for: Key.autoSyncEnabled) ?? false,
                activeDestinationID: string(for: Key.activeDestinationID),
                appleDestinationID: string(for: Key.appleDestinationID)
            )
        }
        set {
            set(newValue.autoSyncEnabled, forKey: Key.autoSyncEnabled)
            set(newValue.activeDestinationID, forKey: Key.activeDestinationID)
            set(newValue.appleDestinationID, forKey: Key.appleDestinationID)
        }
    }

    func setSelectedDestinationID(_ destinationID: String?, for provider: SyncProvider) {
        set(destinationID, forKey: Key.appleDestinationID)
    }

    func selectedDestinationID(for provider: SyncProvider) -> String? {
        string(for: Key.appleDestinationID)
    }

    func migrateLegacyAppleSelectionIfNeeded() {
        guard !boolFromDatabaseOrDefaults(for: Key.didMigrateLegacyPreferences) else { return }

        defer {
            set(true, forKey: Key.didMigrateLegacyPreferences)
        }

        guard let legacyAppleCalendar = userDefaults.string(forKey: "selected_calendar_identifier") else {
            return
        }

        let destinationID = SyncDestination(
            provider: .apple,
            calendarIdentifier: legacyAppleCalendar,
            displayName: legacyAppleCalendar,
            colorHex: "#4A90D9"
        ).id

        set(destinationID, forKey: Key.appleDestinationID)

        if string(for: Key.activeDestinationID) == nil {
            set(destinationID, forKey: Key.activeDestinationID)
        }

        if bool(for: Key.autoSyncEnabled) == nil {
            set(true, forKey: Key.autoSyncEnabled)
        }
    }

    private func migrateUserDefaultsToDatabaseIfNeeded() {
        let didMigrate = userDefaults.bool(forKey: "sync_db_migration_complete")
        guard !didMigrate else { return }

        let keys: [String] = [
            Key.autoSyncEnabled,
            Key.activeDestinationID,
            Key.appleDestinationID,
            Key.didMigrateLegacyPreferences
        ]

        for key in keys {
            guard string(for: key) == nil else { continue }

            if let value = userDefaults.string(forKey: key) {
                set(value, forKey: key)
            } else if let boolKey = [Key.autoSyncEnabled, Key.didMigrateLegacyPreferences].first(where: { $0 == key }) {
                let boolValue = userDefaults.bool(forKey: key)
                set(boolValue, forKey: key)
            }
        }

        userDefaults.set(true, forKey: "sync_db_migration_complete")
    }

    // MARK: - Database-backed read/write

    private func string(for key: String) -> String? {
        databaseManager.syncSetting(forKey: key)
    }

    private func bool(for key: String) -> Bool? {
        guard let value = string(for: key) else { return nil }
        return value == "true"
    }

    private func set(_ value: String?, forKey key: String) {
        databaseManager.setSyncSetting(value, forKey: key)
    }

    private func set(_ value: Bool, forKey key: String) {
        databaseManager.setSyncSetting(value ? "true" : "false", forKey: key)
    }

    private func boolFromDatabaseOrDefaults(for key: String) -> Bool {
        if let dbValue = bool(for: key) {
            return dbValue
        }
        return userDefaults.bool(forKey: key)
    }
}