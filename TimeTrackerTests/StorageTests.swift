import SQLite
import XCTest
@testable import TimeTracker

final class StorageTests: XCTestCase {
    func testTheNewestEarlierDatabaseIsCopiedOnceAndTheOriginalKept() throws {
        let root = makeTemporaryDirectory()
        let newer = root.appendingPathComponent("Documents/TimeTracker/database/timetracker.sqlite3")
        let older = root.appendingPathComponent("Application Support/TimeTracker/timetracker.sqlite3")
        let destination = root.appendingPathComponent("Application Support/TimeTracker/Database/timetracker.sqlite3")
        try write("newer", to: newer)
        try write("older", to: older)

        let copied = DatabaseManager.migrateLegacyDatabaseIfNeeded(to: destination, from: [newer, older])
        XCTAssertEqual(copied, newer)
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "newer")
        XCTAssertEqual(try String(contentsOf: newer, encoding: .utf8), "newer", "the original stays as a backup")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path + ".partial"))

        try write("changed since", to: destination)
        XCTAssertNil(DatabaseManager.migrateLegacyDatabaseIfNeeded(to: destination, from: [newer, older]))
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "changed since", "an existing database is never replaced")
    }

    func testJournalFilesComeAlong() throws {
        let root = makeTemporaryDirectory()
        let source = root.appendingPathComponent("old/timetracker.sqlite3")
        let destination = root.appendingPathComponent("new/timetracker.sqlite3")
        try write("db", to: source)
        try write("wal", to: URL(fileURLWithPath: source.path + "-wal"))

        DatabaseManager.migrateLegacyDatabaseIfNeeded(to: destination, from: [source])
        XCTAssertEqual(try String(contentsOfFile: destination.path + "-wal", encoding: .utf8), "wal")
    }

    func testNothingIsCopiedWithoutAnEarlierDatabase() {
        let root = makeTemporaryDirectory()
        let destination = root.appendingPathComponent("new/timetracker.sqlite3")
        XCTAssertNil(DatabaseManager.migrateLegacyDatabaseIfNeeded(to: destination, from: [root.appendingPathComponent("missing.sqlite3")]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testARunningTimerFromVersion1MovesIntoTheDatabase() throws {
        let defaults = makeDefaults()
        let databaseURL = makeTemporaryDirectory().appendingPathComponent("timetracker.sqlite3")
        let start = Date(timeIntervalSince1970: 1_790_000_000)

        // Version 1.0 had a project and a running timer for it.
        let first = DatabaseManager(databaseURL: databaseURL)
        let projectId = try XCTUnwrap(first.insertProject(Project(name: "Client", colorHex: "#FF6B6B")))
        try resetSchemaVersion(of: databaseURL, to: 6)
        defaults.set("Ada Lovelace", forKey: "running_timer_name")
        defaults.set("Draft", forKey: "running_timer_notes")
        defaults.set(projectId, forKey: "running_timer_projectId")
        defaults.set(start, forKey: "running_timer_startDate")

        let database = DatabaseManager(databaseURL: databaseURL, legacyTimerDefaults: defaults)
        let timer = try XCTUnwrap(database.runningTimer())
        XCTAssertEqual(timer.name, "Ada Lovelace")
        XCTAssertEqual(timer.notes, "Draft")
        XCTAssertEqual(timer.projectId, projectId)
        XCTAssertEqual(timer.startDate.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertNil(defaults.object(forKey: "running_timer_projectId"), "the old copy is cleared once it's saved")
        XCTAssertNil(defaults.object(forKey: "running_timer_startDate"))
    }

    func testTheRunningTimerSurvivesReopeningAndCanBeCleared() throws {
        let databaseURL = makeTemporaryDirectory().appendingPathComponent("timetracker.sqlite3")
        let database = DatabaseManager(databaseURL: databaseURL)
        let projectId = try XCTUnwrap(database.insertProject(Project(name: "Client", colorHex: "#FF6B6B")))
        let start = Date()
        database.saveRunningTimer(RunningTimerState(name: "First", notes: "", projectId: projectId, startDate: start))
        database.saveRunningTimer(RunningTimerState(name: "Renamed", notes: "Notes", projectId: projectId, startDate: start))

        let reopened = DatabaseManager(databaseURL: databaseURL)
        let timer = try XCTUnwrap(reopened.runningTimer())
        XCTAssertEqual(timer.name, "Renamed")
        XCTAssertEqual(timer.notes, "Notes")
        XCTAssertEqual(timer.startDate.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 0.001)

        reopened.clearRunningTimer()
        XCTAssertNil(reopened.runningTimer())
    }

    func testDeletingTheTimersProjectStopsIt() throws {
        let database = DatabaseManager(databaseURL: makeTemporaryDirectory().appendingPathComponent("timetracker.sqlite3"))
        let projectId = try XCTUnwrap(database.insertProject(Project(name: "Client", colorHex: "#FF6B6B")))
        database.saveRunningTimer(RunningTimerState(name: "Running", notes: "", projectId: projectId, startDate: Date()))

        XCTAssertTrue(database.deleteProjectAndEntries(withId: projectId))
        XCTAssertNil(database.runningTimer())
    }

    func testRecordingsAreIndexedAndTheSchemaIsCurrent() throws {
        let databaseURL = makeTemporaryDirectory().appendingPathComponent("timetracker.sqlite3")
        _ = DatabaseManager(databaseURL: databaseURL)

        let connection = try Connection(databaseURL.path)
        let indexes = try connection.prepare("SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'time_entries'")
            .compactMap { $0[0] as? String }
        XCTAssertTrue(indexes.contains("time_entries_by_start"))
        XCTAssertTrue(indexes.contains("time_entries_by_project_and_start"))
        XCTAssertEqual(try connection.scalar("PRAGMA user_version") as? Int64, 8)
    }

    func testAnExportIsAPDFInTheChosenFolder() throws {
        let folder = makeTemporaryDirectory().appendingPathComponent("exported")
        let now = Date()
        let entry = TimeEntry(name: "Ada Lovelace", notes: "Wrote the report", projectId: 1,
                              startDate: now.addingTimeInterval(-3600), endDate: now)

        let file = try RecordingsExporter.writePDF(for: [entry], from: now, to: now, projectFilter: "All Projects", in: folder)
        XCTAssertEqual(file.deletingLastPathComponent().standardizedFileURL, folder.standardizedFileURL)
        XCTAssertEqual(file.pathExtension, "pdf")
        XCTAssertEqual(try Data(contentsOf: file).prefix(4), Data("%PDF".utf8))
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    private func resetSchemaVersion(of databaseURL: URL, to version: Int) throws {
        let connection = try Connection(databaseURL.path)
        try connection.run("DROP TABLE IF EXISTS running_timer")
        try connection.run("PRAGMA user_version = \(version)")
    }

    private func makeDefaults() -> UserDefaults {
        let name = "TimeTrackerStorageTests-\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return UserDefaults(suiteName: name)!
    }
}
