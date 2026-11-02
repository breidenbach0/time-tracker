import XCTest
@testable import TimeTracker

final class SyncRouteResolverTests: XCTestCase {
    func testUnsyncedEntryUsesActiveDestinationWhenAutoSyncIsEnabled() {
        let entry = TimeEntry(
            name: "Focus Block",
            projectId: 1,
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800)
        )

        let preferences = SyncPreferences(
            autoSyncEnabled: true,
            activeDestinationID: "apple::primary",
            appleDestinationID: "apple::primary"
        )

        let route = SyncRouteResolver.resolve(for: entry, preferences: preferences)

        XCTAssertEqual(route?.provider, .apple)
        XCTAssertEqual(route?.calendarIdentifier, "primary")
    }

    func testAlreadySyncedEntryKeepsItsOriginalProviderAndCalendar() {
        let entry = TimeEntry(
            name: "Focus Block",
            projectId: 1,
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            syncProvider: .apple,
            syncCalendarIdentifier: "apple-home",
            syncEventIdentifier: "event-1"
        )

        let preferences = SyncPreferences(
            autoSyncEnabled: true,
            activeDestinationID: "apple::primary",
            appleDestinationID: "apple::apple-home"
        )

        let route = SyncRouteResolver.resolve(for: entry, preferences: preferences)

        XCTAssertEqual(route?.provider, .apple)
        XCTAssertEqual(route?.calendarIdentifier, "apple-home")
    }
}
