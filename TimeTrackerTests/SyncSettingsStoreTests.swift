import XCTest
@testable import TimeTracker

final class SyncSettingsStoreTests: XCTestCase {
    func testPreferencesPersistAcrossStoreInstances() {
        let suiteName = "SyncSettingsStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create test defaults suite.")
        }

        defaults.removePersistentDomain(forName: suiteName)

        let store = SyncSettingsStore(userDefaults: defaults)
        store.preferences = SyncPreferences(
            autoSyncEnabled: true,
            activeDestinationID: "apple::calendar-1",
            appleDestinationID: "apple::calendar-1"
        )

        let reloadedStore = SyncSettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloadedStore.preferences.autoSyncEnabled, true)
        XCTAssertEqual(reloadedStore.preferences.activeDestinationID, "apple::calendar-1")
        XCTAssertEqual(reloadedStore.preferences.appleDestinationID, "apple::calendar-1")
    }
}
