import Foundation
import SQLite

enum DatabaseError: Error {
    case notConnected
}

final class DatabaseManager {
    /// Where the database lives. Not in Documents: iCloud may sync that folder while the file is
    /// open, and macOS asks before an app may read it.
    static let databaseDirectoryURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("TimeTracker/Database", isDirectory: true)
    static let defaultDatabaseURL = databaseDirectoryURL.appendingPathComponent("timetracker.sqlite3")

    /// Where earlier versions kept the database, newest first.
    static var legacyDatabaseURLs: [URL] {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return [
            documents.appendingPathComponent("TimeTracker/database/timetracker.sqlite3"),
            applicationSupport.appendingPathComponent("TimeTracker/timetracker.sqlite3"),
            documents.appendingPathComponent("timetracker.sqlite3")
        ]
    }

    static let shared = DatabaseManager(legacyTimerDefaults: .standard)

    private let databaseURL: URL
    private var db: Connection?

    /// Earlier versions kept a running timer here; it's moved into the database once.
    private let legacyTimerDefaults: UserDefaults?

    private let projects = Table("projects")
    private let categories = Table("categories")
    private let timeEntries = Table("time_entries")
    private let famousNames = Table("famous_names")
    /// At most one row: the recording that's running.
    private let runningTimers = Table("running_timer")

    private let id = SQLite.Expression<Int64>("id")
    private let name = SQLite.Expression<String>("name")
    private let scope = SQLite.Expression<String>("scope")
    private let colorHex = SQLite.Expression<String>("color_hex")
    private let isDefault = SQLite.Expression<Bool>("is_default")
    private let sourceCalendarIdentifier = SQLite.Expression<String?>("source_calendar_identifier")
    private let createdAt = SQLite.Expression<Date>("created_at")
    private let updatedAt = SQLite.Expression<Date>("updated_at")

    private let projectId = SQLite.Expression<Int64>("project_id")
    private let categoryId = SQLite.Expression<Int64?>("category_id")
    private let notes = SQLite.Expression<String>("notes")
    private let startDate = SQLite.Expression<Date>("start_date")
    private let endDate = SQLite.Expression<Date?>("end_date")
    private let syncProvider = SQLite.Expression<String?>("sync_provider")
    private let syncCalendarIdentifier = SQLite.Expression<String?>("sync_calendar_identifier")
    private let calendarEventIdentifier = SQLite.Expression<String?>("calendar_event_identifier")
    private let famousPersonName = SQLite.Expression<String>("person_name")
    private let famousPersonDomain = SQLite.Expression<String>("person_domain")
    private let blockedFamousNames: Set<String> = [
        "Adolf Hitler",
        "Benito Mussolini",
        "Joseph Stalin",
        "Pol Pot",
        "Mao Zedong",
        "Francisco Franco"
    ]

    init(databaseURL: URL = DatabaseManager.defaultDatabaseURL, legacyTimerDefaults: UserDefaults? = nil) {
        self.databaseURL = databaseURL
        self.legacyTimerDefaults = legacyTimerDefaults
        setupDatabase()
    }

    static func prepareStorageIfNeeded(fileManager: FileManager = .default) {
        try? fileManager.createDirectory(at: databaseDirectoryURL, withIntermediateDirectories: true)
        migrateLegacyDatabaseIfNeeded(to: defaultDatabaseURL, from: legacyDatabaseURLs, fileManager: fileManager)
    }

    /// Copies the first database in `candidates` that exists to `destination`, unless there's
    /// one there already. The original stays where it was, as a backup. Returns what was copied.
    @discardableResult
    static func migrateLegacyDatabaseIfNeeded(
        to destination: URL,
        from candidates: [URL],
        fileManager: FileManager = .default
    ) -> URL? {
        guard !fileManager.fileExists(atPath: destination.path) else { return nil }

        for source in candidates where fileManager.fileExists(atPath: source.path) {
            if copyDatabaseBundle(from: source, to: destination, fileManager: fileManager) {
                return source
            }
        }
        return nil
    }

    /// Copies the database and any journal files beside it. The database file goes last and
    /// under a temporary name first, so a half-finished copy is never mistaken for a database.
    private static func copyDatabaseBundle(from sourceURL: URL, to destinationURL: URL, fileManager: FileManager) -> Bool {
        let partialURL = URL(fileURLWithPath: destinationURL.path + ".partial")

        do {
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            for suffix in ["-shm", "-wal"] {
                let source = URL(fileURLWithPath: sourceURL.path + suffix)
                let destination = URL(fileURLWithPath: destinationURL.path + suffix)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                try? fileManager.removeItem(at: destination)
                try fileManager.copyItem(at: source, to: destination)
            }
            try? fileManager.removeItem(at: partialURL)
            try fileManager.copyItem(at: sourceURL, to: partialURL)
            try fileManager.moveItem(at: partialURL, to: destinationURL)
            return true
        } catch {
            print("Database migration error copying \(sourceURL.path): \(error)")
            try? fileManager.removeItem(at: partialURL)
            for suffix in ["-shm", "-wal"] {
                try? fileManager.removeItem(at: URL(fileURLWithPath: destinationURL.path + suffix))
            }
            return false
        }
    }

    private func connection() throws -> Connection {
        guard let db else { throw DatabaseError.notConnected }
        return db
    }

    private func setupDatabase() {
        do {
            db = try Connection(databaseURL.path)
            try db?.execute("PRAGMA foreign_keys = ON")
            try migrateIfNeeded()
        } catch {
            print("Database setup error: \(error)")
        }
    }

    private func migrateIfNeeded() throws {
        let schemaVersion = try currentSchemaVersion()

        if schemaVersion < 1 {
            try migrateToV1()
            try setSchemaVersion(1)
        }

        if schemaVersion < 2 {
            try migrateToV2()
            try setSchemaVersion(2)
        }

        if schemaVersion < 3 {
            try migrateToV3()
            try setSchemaVersion(3)
        }

        if schemaVersion < 4 {
            try migrateToV4()
            try setSchemaVersion(4)
        }

        if schemaVersion < 5 {
            try migrateToV5()
            try setSchemaVersion(5)
        }

        if schemaVersion < 6 {
            try migrateToV6()
            try setSchemaVersion(6)
        }

        if schemaVersion < 7 {
            try migrateToV7()
            try setSchemaVersion(7)
        }

        if schemaVersion < 8 {
            try migrateToV8()
            try setSchemaVersion(8)
        }
    }

    private func migrateToV1() throws {
        try createProjectsTable()
        try createCategoriesTable()

        if try tableExists("categories"), try categoriesNeedCalendarSourceColumn() {
            try db?.run("ALTER TABLE categories ADD COLUMN source_calendar_identifier TEXT")
        }

        if try tableExists("time_entries") {
            try migrateTimeEntriesTable()
        } else {
            try createTimeEntriesTable()
        }

        try removeUnusedDefaultCategories()
    }

    private func createProjectsTable() throws {
        try db?.run(projects.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(name)
            t.column(scope, defaultValue: "")
            t.column(colorHex)
            t.column(createdAt)
            t.column(updatedAt)
        })
    }

    private func createCategoriesTable() throws {
        try db?.run(categories.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(name)
            t.column(colorHex)
            t.column(isDefault, defaultValue: false)
            t.column(sourceCalendarIdentifier)
        })
    }

    private func createTimeEntriesTable() throws {
        try db?.run(timeEntries.create(ifNotExists: true) { t in
            t.column(id, primaryKey: .autoincrement)
            t.column(name)
            t.column(notes, defaultValue: "")
            t.column(projectId)
            t.column(categoryId)
            t.column(startDate)
            t.column(endDate)
            t.column(createdAt)
            t.column(updatedAt)
            t.column(syncProvider)
            t.column(syncCalendarIdentifier)
            t.column(calendarEventIdentifier)
            t.foreignKey(projectId, references: projects, id)
            t.foreignKey(categoryId, references: categories, id, delete: .setNull)
        })
    }

    private func migrateTimeEntriesTable() throws {
        let legacyDefinition = try tableDefinition(for: "time_entries") ?? ""
        let hasProjectId = legacyDefinition.contains("project_id")
        let hasCalendarIdentifier = legacyDefinition.contains("calendar_event_identifier")
        let hasNullableCategory = !legacyDefinition.contains("category_id INTEGER NOT NULL")
        let hasNotes = legacyDefinition.contains("notes")
        let rowCount = try countRows(in: "time_entries")

        if hasProjectId, hasCalendarIdentifier, hasNullableCategory, hasNotes {
            return
        }

        let fallbackProjectId = rowCount > 0 ? try ensureMigratedProject() : nil
        let projectSelection = hasProjectId ? "COALESCE(project_id, \(fallbackProjectId ?? 0))" : "\(fallbackProjectId ?? 0)"
        let calendarSelection = hasCalendarIdentifier ? "calendar_event_identifier" : "NULL"

        try db?.transaction {
            try db?.run("ALTER TABLE time_entries RENAME TO time_entries_legacy")
            try createTimeEntriesTable()
            try db?.run("""
                INSERT INTO time_entries (
                    name,
                    notes,
                    project_id,
                    category_id,
                    start_date,
                    end_date,
                    created_at,
                    updated_at,
                    sync_provider,
                    sync_calendar_identifier,
                    calendar_event_identifier
                )
                SELECT
                    name,
                    "",
                    \(projectSelection),
                    category_id,
                    start_date,
                    end_date,
                    created_at,
                    updated_at,
                    NULL,
                    NULL,
                    \(calendarSelection)
                FROM time_entries_legacy
                """)
            try db?.run("DROP TABLE time_entries_legacy")
        }
    }

    private func migrateToV2() throws {
        guard try tableExists("time_entries"),
              let definition = try tableDefinition(for: "time_entries") else {
            return
        }

        if !definition.contains("sync_provider") {
            try db?.run("ALTER TABLE time_entries ADD COLUMN sync_provider TEXT")
        }

        if !definition.contains("sync_calendar_identifier") {
            try db?.run("ALTER TABLE time_entries ADD COLUMN sync_calendar_identifier TEXT")
        }

        try db?.run("""
            UPDATE time_entries
            SET sync_provider = 'apple'
            WHERE calendar_event_identifier IS NOT NULL
              AND sync_provider IS NULL
            """)
    }

    private func migrateToV3() throws {
        try createFamousNamesTable()
        try seedFamousNamesIfNeeded()
    }

    private func migrateToV4() throws {
        guard try tableExists("time_entries"),
              let definition = try tableDefinition(for: "time_entries") else {
            return
        }

        if !definition.contains("notes") {
            try db?.run("ALTER TABLE time_entries ADD COLUMN notes TEXT NOT NULL DEFAULT ''")
        }
    }

    private func migrateToV5() throws {
        guard try tableExists("projects"),
              let definition = try tableDefinition(for: "projects") else {
            return
        }

        if !definition.contains("scope") {
            try db?.run("ALTER TABLE projects ADD COLUMN scope TEXT NOT NULL DEFAULT ''")
        }
    }

    private func migrateToV6() throws {
        try db?.run("""
            CREATE TABLE IF NOT EXISTS sync_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
            """)
    }

    /// Recordings are read newest first, and per project.
    private func migrateToV7() throws {
        try db?.run("CREATE INDEX IF NOT EXISTS time_entries_by_start ON time_entries (start_date)")
        try db?.run("CREATE INDEX IF NOT EXISTS time_entries_by_project_and_start ON time_entries (project_id, start_date)")
    }

    /// The running timer moves out of UserDefaults, so all of a recording lives in one place.
    private func migrateToV8() throws {
        try db?.run("""
            CREATE TABLE IF NOT EXISTS running_timer (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                name TEXT NOT NULL,
                notes TEXT NOT NULL DEFAULT '',
                project_id INTEGER NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
                start_date TEXT NOT NULL
            )
            """)

        guard let legacyTimerDefaults, let state = Self.legacyRunningTimer(in: legacyTimerDefaults) else { return }
        // Only forget the old copy once the new one is saved.
        try writeRunningTimer(state)
        Self.removeLegacyRunningTimer(from: legacyTimerDefaults)
    }

    private func createFamousNamesTable() throws {
        try db?.run(famousNames.create(ifNotExists: true) { table in
            table.column(id, primaryKey: .autoincrement)
            table.column(famousPersonName, unique: true)
            table.column(famousPersonDomain)
        })
    }

    private func ensureMigratedProject() throws -> Int64 {
        if let existingProject = fetchAllProjects().first {
            return existingProject.id ?? 0
        }

        let now = Date()
        let rowId = try db?.run(projects.insert(
            name <- "Imported Recordings",
            scope <- "",
            colorHex <- "#9E9E9E",
            createdAt <- now,
            updatedAt <- now
        ))

        return rowId ?? 0
    }

    private func currentSchemaVersion() throws -> Int {
        Int(try db?.scalar("PRAGMA user_version") as? Int64 ?? 0)
    }

    private func setSchemaVersion(_ version: Int) throws {
        try db?.run("PRAGMA user_version = \(version)")
    }

    private func tableExists(_ tableName: String) throws -> Bool {
        let count = try db?.scalar("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?", tableName) as? Int64
        return (count ?? 0) > 0
    }

    private func tableDefinition(for tableName: String) throws -> String? {
        try db?.scalar("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?", tableName) as? String
    }

    private func categoriesNeedCalendarSourceColumn() throws -> Bool {
        guard let definition = try tableDefinition(for: "categories") else {
            return false
        }
        return !definition.contains("source_calendar_identifier")
    }

    private func countRows(in tableName: String) throws -> Int {
        Int(try db?.scalar("SELECT COUNT(*) FROM \(tableName)") as? Int64 ?? 0)
    }

    private func removeUnusedDefaultCategories() throws {
        try db?.run("""
            DELETE FROM categories
            WHERE is_default = 1
              AND id NOT IN (
                SELECT DISTINCT category_id
                FROM time_entries
                WHERE category_id IS NOT NULL
              )
            """)
    }

    private func seedFamousNamesIfNeeded() throws {
        let existingCount = try db?.scalar(famousNames.count) ?? 0
        guard existingCount == 0 else { return }

        try db?.transaction {
            for person in famousPeopleSeed {
                try db?.run(famousNames.insert(
                    famousPersonName <- person.name,
                    famousPersonDomain <- person.domain
                ))
            }
        }
    }

    private var famousPeopleSeed: [(name: String, domain: String)] {
        [
            ("Ada Lovelace", "Scientist"),
            ("Marie Curie", "Scientist"),
            ("Albert Einstein", "Scientist"),
            ("Isaac Newton", "Scientist"),
            ("Galileo Galilei", "Scientist"),
            ("Rosalind Franklin", "Scientist"),
            ("Katherine Johnson", "Scientist"),
            ("Alan Turing", "Scientist"),
            ("Nikola Tesla", "Scientist"),
            ("Srinivasa Ramanujan", "Scientist"),
            ("Chien-Shiung Wu", "Scientist"),
            ("Michael Faraday", "Scientist"),
            ("Jane Goodall", "Scientist"),
            ("Carl Sagan", "Scientist"),
            ("Ibn al-Haytham", "Scientist"),
            ("Socrates", "Philosopher"),
            ("Plato", "Philosopher"),
            ("Aristotle", "Philosopher"),
            ("Confucius", "Philosopher"),
            ("Hypatia", "Philosopher"),
            ("Maimonides", "Philosopher"),
            ("Thomas Aquinas", "Philosopher"),
            ("Rene Descartes", "Philosopher"),
            ("Baruch Spinoza", "Philosopher"),
            ("Mary Wollstonecraft", "Philosopher"),
            ("Simone de Beauvoir", "Philosopher"),
            ("Hannah Arendt", "Philosopher"),
            ("John Locke", "Philosopher"),
            ("Ibn Rushd", "Philosopher"),
            ("Laozi", "Philosopher"),
            ("William Shakespeare", "Writer"),
            ("Jane Austen", "Writer"),
            ("Leo Tolstoy", "Writer"),
            ("Virginia Woolf", "Writer"),
            ("Toni Morrison", "Writer"),
            ("James Baldwin", "Writer"),
            ("Rabindranath Tagore", "Writer"),
            ("Jorge Luis Borges", "Writer"),
            ("Chinua Achebe", "Writer"),
            ("Maya Angelou", "Writer"),
            ("George Orwell", "Writer"),
            ("Emily Dickinson", "Writer"),
            ("Mark Twain", "Writer"),
            ("Homer", "Writer"),
            ("Mary Shelley", "Writer"),
            ("Ashoka", "Ruler"),
            ("Akbar", "Ruler"),
            ("Sejong the Great", "Ruler"),
            ("Cyrus the Great", "Ruler"),
            ("Mansa Musa", "Ruler"),
            ("Hatshepsut", "Ruler"),
            ("Queen Tamar", "Ruler"),
            ("Alfred the Great", "Ruler"),
            ("Augustus", "Ruler"),
            ("Marcus Aurelius", "Ruler")
        ]
    }

    // MARK: - Project Operations

    func fetchAllProjects() -> [Project] {
        var result: [Project] = []

        do {
            let query = projects.order(createdAt.asc)
            for row in try connection().prepare(query) {
                result.append(Project(
                    id: row[id],
                    name: row[name],
                    scope: row[scope],
                    colorHex: row[colorHex],
                    createdAt: row[createdAt],
                    updatedAt: row[updatedAt]
                ))
            }
        } catch {
            print("Fetch projects error: \(error)")
        }

        return result
    }

    @discardableResult
    func insertProject(_ project: Project) -> Int64? {
        do {
            let rowId = try db?.run(projects.insert(
                name <- project.name,
                scope <- project.scope,
                colorHex <- project.colorHex,
                createdAt <- project.createdAt,
                updatedAt <- project.updatedAt
            ))
            return rowId
        } catch {
            print("Insert project error: \(error)")
            return nil
        }
    }

    @discardableResult
    func updateProject(_ project: Project) -> Bool {
        guard let projectIdentifier = project.id else { return false }

        do {
            let projectRow = projects.filter(id == projectIdentifier)
            try db?.run(projectRow.update(
                name <- project.name,
                scope <- project.scope,
                colorHex <- project.colorHex,
                updatedAt <- project.updatedAt
            ))
            return true
        } catch {
            print("Update project error: \(error)")
            return false
        }
    }

    /// Deletes a project and every recording in it, all or nothing.
    @discardableResult
    func deleteProjectAndEntries(withId projectIdentifier: Int64) -> Bool {
        do {
            let database = try connection()
            try database.transaction {
                try database.run(timeEntries.filter(projectId == projectIdentifier).delete())
                try database.run(projects.filter(id == projectIdentifier).delete())
            }
            return true
        } catch {
            print("Delete project error: \(error)")
            return false
        }
    }

    // MARK: - Time Entry Operations

    private func timeEntry(from row: Row) -> TimeEntry {
        TimeEntry(
            id: row[id],
            name: row[name],
            notes: row[notes],
            projectId: row[projectId],
            categoryId: row[categoryId],
            startDate: row[startDate],
            endDate: row[endDate],
            createdAt: row[createdAt],
            updatedAt: row[updatedAt],
            syncProvider: row[syncProvider].flatMap(SyncProvider.init(rawValue:)),
            syncCalendarIdentifier: row[syncCalendarIdentifier],
            syncEventIdentifier: row[calendarEventIdentifier]
        )
    }

    func fetchAllTimeEntries(projectFilterId: Int64? = nil) -> [TimeEntry] {
        var result: [TimeEntry] = []
        do {
            var query = timeEntries.order(startDate.desc)
            if let projectFilterId {
                query = query.filter(projectId == projectFilterId)
            }

            for row in try connection().prepare(query) {
                result.append(timeEntry(from: row))
            }
        } catch {
            print("Fetch time entries error: \(error)")
        }
        return result
    }

    @discardableResult
    func insertTimeEntry(_ entry: TimeEntry) -> Int64? {
        do {
            let rowId = try db?.run(timeEntries.insert(
                name <- entry.name,
                notes <- entry.notes,
                projectId <- entry.projectId,
                categoryId <- entry.categoryId,
                startDate <- entry.startDate,
                endDate <- entry.endDate,
                createdAt <- entry.createdAt,
                updatedAt <- entry.updatedAt,
                syncProvider <- entry.syncProvider?.rawValue,
                syncCalendarIdentifier <- entry.syncCalendarIdentifier,
                calendarEventIdentifier <- entry.syncEventIdentifier
            ))
            return rowId
        } catch {
            print("Insert time entry error: \(error)")
            return nil
        }
    }

    @discardableResult
    func updateTimeEntry(_ entry: TimeEntry) -> Bool {
        guard let entryIdentifier = entry.id else { return false }

        do {
            let entryRow = timeEntries.filter(id == entryIdentifier)
            try db?.run(entryRow.update(
                name <- entry.name,
                notes <- entry.notes,
                projectId <- entry.projectId,
                categoryId <- entry.categoryId,
                startDate <- entry.startDate,
                endDate <- entry.endDate,
                updatedAt <- entry.updatedAt,
                syncProvider <- entry.syncProvider?.rawValue,
                syncCalendarIdentifier <- entry.syncCalendarIdentifier,
                calendarEventIdentifier <- entry.syncEventIdentifier
            ))
            return true
        } catch {
            print("Update time entry error: \(error)")
            return false
        }
    }

    @discardableResult
    func deleteTimeEntry(_ entry: TimeEntry) -> Bool {
        guard let entryIdentifier = entry.id else { return false }

        do {
            try db?.run(timeEntries.filter(id == entryIdentifier).delete())
            return true
        } catch {
            print("Delete time entry error: \(error)")
            return false
        }
    }

    /// Names new recordings are given when the user doesn't name them. The seed list never
    /// changes after the first launch, so it is read once.
    private(set) lazy var recordingNameCandidates: [String] = fetchFamousPeopleNames()

    private func fetchFamousPeopleNames() -> [String] {
        var names: [String] = []

        do {
            for row in try connection().prepare(famousNames.order(famousPersonName.asc)) {
                let candidate = row[famousPersonName].trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty, !blockedFamousNames.contains(candidate) {
                    names.append(candidate)
                }
            }
        } catch {
            print("Fetch famous names error: \(error)")
        }

        return names
    }

    // MARK: - Running Timer State

    func saveRunningTimer(_ state: RunningTimerState) {
        do {
            try writeRunningTimer(state)
        } catch {
            print("Save running timer error: \(error)")
        }
    }

    func runningTimer() -> RunningTimerState? {
        do {
            guard let row = try connection().pluck(runningTimers.filter(id == 1)) else { return nil }
            return RunningTimerState(
                name: row[name],
                notes: row[notes],
                projectId: row[projectId],
                startDate: row[startDate]
            )
        } catch {
            print("Read running timer error: \(error)")
            return nil
        }
    }

    func clearRunningTimer() {
        do {
            try connection().run(runningTimers.delete())
        } catch {
            print("Clear running timer error: \(error)")
        }
    }

    private func writeRunningTimer(_ state: RunningTimerState) throws {
        try connection().run(runningTimers.insert(
            or: .replace,
            id <- 1,
            name <- state.name,
            notes <- state.notes,
            projectId <- state.projectId,
            startDate <- state.startDate
        ))
    }

    private static let legacyTimerKeys = (
        name: "running_timer_name",
        notes: "running_timer_notes",
        projectId: "running_timer_projectId",
        categoryId: "running_timer_categoryId",
        startDate: "running_timer_startDate"
    )

    /// A running timer as version 1.0 saved it.
    static func legacyRunningTimer(in defaults: UserDefaults) -> RunningTimerState? {
        let keys = legacyTimerKeys
        guard defaults.object(forKey: keys.projectId) != nil,
              let startDate = defaults.object(forKey: keys.startDate) as? Date else {
            return nil
        }

        return RunningTimerState(
            name: defaults.string(forKey: keys.name) ?? "",
            notes: defaults.string(forKey: keys.notes) ?? "",
            projectId: Int64(defaults.integer(forKey: keys.projectId)),
            startDate: startDate
        )
    }

    private static func removeLegacyRunningTimer(from defaults: UserDefaults) {
        let keys = legacyTimerKeys
        for key in [keys.name, keys.notes, keys.projectId, keys.categoryId, keys.startDate] {
            defaults.removeObject(forKey: key)
        }
    }
}
