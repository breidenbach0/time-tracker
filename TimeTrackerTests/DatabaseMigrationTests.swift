import Foundation
import SQLite
import XCTest
@testable import TimeTracker

final class DatabaseMigrationTests: XCTestCase {
    func testLegacyAppleSyncedRowsMigrateToProviderAwareMetadata() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("timetracker-migration-\(UUID().uuidString).sqlite3")

        let db = try Connection(databaseURL.path)

        let projects = Table("projects")
        let categories = Table("categories")
        let timeEntries = Table("time_entries")

        let id = Expression<Int64>("id")
        let name = Expression<String>("name")
        let colorHex = Expression<String>("color_hex")
        let isDefault = Expression<Bool>("is_default")
        let sourceCalendarIdentifier = Expression<String?>("source_calendar_identifier")
        let createdAt = Expression<Date>("created_at")
        let updatedAt = Expression<Date>("updated_at")
        let projectId = Expression<Int64>("project_id")
        let categoryId = Expression<Int64?>("category_id")
        let startDate = Expression<Date>("start_date")
        let endDate = Expression<Date?>("end_date")
        let calendarEventIdentifier = Expression<String?>("calendar_event_identifier")

        try db.run("PRAGMA user_version = 1")

        try db.run(projects.create { table in
            table.column(id, primaryKey: .autoincrement)
            table.column(name)
            table.column(colorHex)
            table.column(createdAt)
            table.column(updatedAt)
        })

        try db.run(categories.create { table in
            table.column(id, primaryKey: .autoincrement)
            table.column(name)
            table.column(colorHex)
            table.column(isDefault, defaultValue: false)
            table.column(sourceCalendarIdentifier)
        })

        try db.run(timeEntries.create { table in
            table.column(id, primaryKey: .autoincrement)
            table.column(name)
            table.column(projectId)
            table.column(categoryId)
            table.column(startDate)
            table.column(endDate)
            table.column(createdAt)
            table.column(updatedAt)
            table.column(calendarEventIdentifier)
            table.foreignKey(projectId, references: projects, id)
            table.foreignKey(categoryId, references: categories, id, delete: .setNull)
        })

        let now = Date()
        let insertedProjectID = try db.run(projects.insert(
            name <- "Legacy Project",
            colorHex <- "#4A90D9",
            createdAt <- now,
            updatedAt <- now
        ))

        try db.run(timeEntries.insert(
            name <- "Legacy Synced Entry",
            projectId <- insertedProjectID,
            categoryId <- nil,
            startDate <- now,
            endDate <- now.addingTimeInterval(1800),
            createdAt <- now,
            updatedAt <- now,
            calendarEventIdentifier <- "apple-event-1"
        ))

        let manager = DatabaseManager(databaseURL: databaseURL)
        let migratedEntry = try XCTUnwrap(manager.fetchAllTimeEntries().first)

        XCTAssertEqual(migratedEntry.syncProvider, .apple)
        XCTAssertEqual(migratedEntry.syncEventIdentifier, "apple-event-1")
    }
}
