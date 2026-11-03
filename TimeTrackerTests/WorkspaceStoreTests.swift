import Combine
import XCTest
@testable import TimeTracker

@MainActor
final class WorkspaceStoreTests: XCTestCase {
    private func makeStore() -> (WorkspaceStore, DatabaseManager) {
        let databaseURL = makeTemporaryDirectory().appendingPathComponent("timetracker.sqlite3")
        let database = DatabaseManager(databaseURL: databaseURL)
        return (WorkspaceStore(database: database), database)
    }

    func testNewProjectsAreSavedAndListedInOrder() throws {
        let (store, database) = makeStore()
        let first = try XCTUnwrap(store.saveProject(Project(name: "Client", colorHex: "#FF6B6B")))
        store.saveProject(Project(name: "Reading", colorHex: "#4ECDC4"))

        XCTAssertNotNil(first.id)
        XCTAssertEqual(store.projects.map(\.name), ["Client", "Reading"])
        XCTAssertEqual(database.fetchAllProjects().map(\.name), ["Client", "Reading"])
    }

    func testChangingAProjectUpdatesItInPlace() throws {
        let (store, database) = makeStore()
        var project = try XCTUnwrap(store.saveProject(Project(name: "Client", colorHex: "#FF6B6B")))
        project.name = "Client A"
        store.saveProject(project)

        XCTAssertEqual(store.projects.map(\.name), ["Client A"])
        XCTAssertEqual(database.fetchAllProjects().map(\.name), ["Client A"])
    }

    func testRecordingsStayNewestFirstAndGetANameWhenTheyHaveNone() throws {
        let (store, _) = makeStore()
        let project = try XCTUnwrap(store.saveProject(Project(name: "Client", colorHex: "#FF6B6B")))
        let projectId = try XCTUnwrap(project.id)
        let now = Date()

        store.saveEntry(TimeEntry(name: "Older", projectId: projectId, startDate: now.addingTimeInterval(-7200), endDate: now.addingTimeInterval(-3600)))
        let unnamed = store.saveEntry(TimeEntry(name: "   ", notes: "  draft  ", projectId: projectId, startDate: now, endDate: now.addingTimeInterval(60)))
        store.saveEntry(TimeEntry(name: "Middle", projectId: projectId, startDate: now.addingTimeInterval(-3600), endDate: now))

        XCTAssertEqual(store.entries.map(\.name), [unnamed.name, "Middle", "Older"])
        XCTAssertFalse(unnamed.name.trimmingCharacters(in: .whitespaces).isEmpty)
        XCTAssertEqual(unnamed.notes, "draft")
    }

    func testEditingARecordingMovesItToItsNewPlace() throws {
        let (store, database) = makeStore()
        let projectId = try XCTUnwrap(store.saveProject(Project(name: "Client", colorHex: "#FF6B6B"))?.id)
        let now = Date()
        var early = store.saveEntry(TimeEntry(name: "Early", projectId: projectId, startDate: now.addingTimeInterval(-7200)))
        store.saveEntry(TimeEntry(name: "Late", projectId: projectId, startDate: now))

        early.startDate = now.addingTimeInterval(600)
        store.saveEntry(early)

        XCTAssertEqual(store.entries.map(\.name), ["Early", "Late"])
        XCTAssertEqual(database.fetchAllTimeEntries().map(\.name), ["Early", "Late"])
    }

    func testDeletingAProjectDeletesItsRecordingsAndNoOthers() throws {
        let (store, database) = makeStore()
        let client = try XCTUnwrap(store.saveProject(Project(name: "Client", colorHex: "#FF6B6B")))
        let reading = try XCTUnwrap(store.saveProject(Project(name: "Reading", colorHex: "#4ECDC4")))
        for index in 0..<3 {
            store.saveEntry(TimeEntry(name: "Client \(index)", projectId: client.id!, startDate: Date()))
        }
        store.saveEntry(TimeEntry(name: "Book", projectId: reading.id!, startDate: Date()))

        XCTAssertTrue(store.deleteProject(client))
        XCTAssertEqual(store.projects.map(\.name), ["Reading"])
        XCTAssertEqual(store.entries.map(\.name), ["Book"])
        XCTAssertEqual(database.fetchAllTimeEntries().map(\.name), ["Book"])
        XCTAssertEqual(database.fetchAllProjects().map(\.name), ["Reading"])
    }

    func testDeletingARecordingRemovesIt() throws {
        let (store, database) = makeStore()
        let projectId = try XCTUnwrap(store.saveProject(Project(name: "Client", colorHex: "#FF6B6B"))?.id)
        let entry = store.saveEntry(TimeEntry(name: "Gone", projectId: projectId, startDate: Date()))

        store.deleteEntry(entry)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(database.fetchAllTimeEntries().isEmpty)
    }

    func testSuggestedNamesAvoidOnesTheProjectAlreadyUses() throws {
        let (store, database) = makeStore()
        let projectId = try XCTUnwrap(store.saveProject(Project(name: "Client", colorHex: "#FF6B6B"))?.id)
        let candidates = database.recordingNameCandidates
        XCTAssertGreaterThan(candidates.count, 2)
        for name in candidates.dropLast() {
            store.saveEntry(TimeEntry(name: name, projectId: projectId, startDate: Date()))
        }

        XCTAssertEqual(store.nextRecordingName(for: projectId), candidates.last)
    }

    func testOtherScreensHearAboutChangesWithoutReloading() throws {
        let (store, _) = makeStore()
        let viewModel = EntriesViewModel(store: store)
        let projectId = try XCTUnwrap(store.saveProject(Project(name: "Client", colorHex: "#FF6B6B"))?.id)

        store.saveEntry(TimeEntry(name: "Seen", projectId: projectId, startDate: Date()))
        XCTAssertEqual(viewModel.entries.map(\.name), ["Seen"])
        XCTAssertEqual(viewModel.projects.map(\.name), ["Client"])
        XCTAssertEqual(viewModel.daySections.count, 1)
    }
}
