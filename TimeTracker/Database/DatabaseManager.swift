import Foundation
import SQLite

final class DatabaseManager {
    static let rootDirectoryURL: URL = {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("TimeTracker", isDirectory: true)
    }()

    static let exportsDirectoryURL = rootDirectoryURL.appendingPathComponent("exported", isDirectory: true)
    static let databaseDirectoryURL = rootDirectoryURL.appendingPathComponent("database", isDirectory: true)

    static let defaultDatabaseURL: URL = {
        ensureStorageDirectories()
        return databaseDirectoryURL.appendingPathComponent("timetracker.sqlite3")
    }()
    static let shared = DatabaseManager()

    private let databaseURL: URL
    private var db: Connection?

    private let projects = Table("projects")
    private let categories = Table("categories")
    private let timeEntries = Table("time_entries")
    private let famousNames = Table("famous_names")

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

    init(databaseURL: URL = DatabaseManager.defaultDatabaseURL) {
        self.databaseURL = databaseURL
        setupDatabase()
    }

    static func ensureStorageDirectories(fileManager: FileManager = .default) {
        try? fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: exportsDirectoryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: databaseDirectoryURL, withIntermediateDirectories: true)
    }

    static func prepareStorageIfNeeded(fileManager: FileManager = .default) {
        ensureStorageDirectories(fileManager: fileManager)
        migrateLegacyDatabaseIfNeeded(fileManager: fileManager)
    }

    private static func migrateLegacyDatabaseIfNeeded(fileManager: FileManager) {
        let destinationURL = defaultDatabaseURL
        guard !fileManager.fileExists(atPath: destinationURL.path) else { return }

        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TimeTracker/timetracker.sqlite3")
        let legacyDocumentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("timetracker.sqlite3")

        for sourceURL in [appSupportURL, legacyDocumentsURL] {
            guard fileManager.fileExists(atPath: sourceURL.path) else { continue }
            copyDatabaseBundle(from: sourceURL, to: destinationURL, fileManager: fileManager)
            break
        }
    }

    private static func copyDatabaseBundle(from sourceURL: URL, to destinationURL: URL, fileManager: FileManager) {
        let suffixes = ["", "-shm", "-wal"]

        for suffix in suffixes {
            let sourceComponent = URL(fileURLWithPath: sourceURL.path + suffix)
            let destinationComponent = URL(fileURLWithPath: destinationURL.path + suffix)

            guard fileManager.fileExists(atPath: sourceComponent.path) else { continue }

            do {
                try fileManager.copyItem(at: sourceComponent, to: destinationComponent)
            } catch {
                print("Database migration error for \(sourceComponent.lastPathComponent): \(error)")
            }
        }
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
            for row in try db!.prepare(query) {
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

    func fetchProject(withId projectIdentifier: Int64) -> Project? {
        do {
            let query = projects.filter(id == projectIdentifier)
            guard let row = try db?.pluck(query) else { return nil }

            return Project(
                id: row[id],
                name: row[name],
                scope: row[scope],
                colorHex: row[colorHex],
                createdAt: row[createdAt],
                updatedAt: row[updatedAt]
            )
        } catch {
            print("Fetch project error: \(error)")
            return nil
        }
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
            postWorkspaceChanged()
            return rowId
        } catch {
            print("Insert project error: \(error)")
            return nil
        }
    }

    func updateProject(_ project: Project) {
        guard let projectIdentifier = project.id else { return }

        do {
            let projectRow = projects.filter(id == projectIdentifier)
            try db?.run(projectRow.update(
                name <- project.name,
                scope <- project.scope,
                colorHex <- project.colorHex,
                updatedAt <- Date()
            ))
            postWorkspaceChanged()
        } catch {
            print("Update project error: \(error)")
        }
    }

    func projectHasEntries(_ project: Project) -> Bool {
        guard let projectIdentifier = project.id else { return false }

        do {
            let count = try db?.scalar(timeEntries.filter(projectId == projectIdentifier).count) ?? 0
            return count > 0
        } catch {
            print("Project count error: \(error)")
            return true
        }
    }

    func deleteProject(_ project: Project) {
        guard let projectIdentifier = project.id, !projectHasEntries(project) else { return }

        do {
            let projectRow = projects.filter(id == projectIdentifier)
            try db?.run(projectRow.delete())
            postWorkspaceChanged()
        } catch {
            print("Delete project error: \(error)")
        }
    }

    // MARK: - Category Operations

    func fetchAllCategories() -> [Category] {
        var result: [Category] = []
        do {
            let query = categories.order(name.asc)
            for row in try db!.prepare(query) {
                result.append(Category(
                    id: row[id],
                    name: row[name],
                    colorHex: row[colorHex],
                    isDefault: row[isDefault],
                    sourceCalendarIdentifier: row[sourceCalendarIdentifier]
                ))
            }
        } catch {
            print("Fetch categories error: \(error)")
        }
        return result
    }

    func fetchCategory(withId categoryIdentifier: Int64) -> Category? {
        do {
            let query = categories.filter(id == categoryIdentifier)
            guard let row = try db?.pluck(query) else { return nil }

            return Category(
                id: row[id],
                name: row[name],
                colorHex: row[colorHex],
                isDefault: row[isDefault],
                sourceCalendarIdentifier: row[sourceCalendarIdentifier]
            )
        } catch {
            print("Fetch category error: \(error)")
            return nil
        }
    }

    func insertCategory(_ category: Category) -> Int64? {
        do {
            let rowId = try db?.run(categories.insert(
                name <- category.name,
                colorHex <- category.colorHex,
                isDefault <- category.isDefault,
                sourceCalendarIdentifier <- category.sourceCalendarIdentifier
            ))
            postWorkspaceChanged()
            return rowId
        } catch {
            print("Insert category error: \(error)")
            return nil
        }
    }

    func updateCategory(_ category: Category) {
        guard let categoryIdentifier = category.id else { return }

        do {
            let categoryRow = categories.filter(id == categoryIdentifier)
            try db?.run(categoryRow.update(
                name <- category.name,
                colorHex <- category.colorHex,
                sourceCalendarIdentifier <- category.sourceCalendarIdentifier
            ))
            postWorkspaceChanged()
        } catch {
            print("Update category error: \(error)")
        }
    }

    func deleteCategory(_ category: Category) {
        guard let categoryIdentifier = category.id else { return }

        do {
            let categoryRow = categories.filter(id == categoryIdentifier)
            try db?.run(categoryRow.delete())
            postWorkspaceChanged()
        } catch {
            print("Delete category error: \(error)")
        }
    }

    // MARK: - Time Entry Operations

    func fetchAllTimeEntries(projectFilterId: Int64? = nil) -> [TimeEntry] {
        var result: [TimeEntry] = []
        do {
            var query = timeEntries.order(startDate.desc)
            if let projectFilterId {
                query = query.filter(projectId == projectFilterId)
            }

            for row in try db!.prepare(query) {
                result.append(TimeEntry(
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
                ))
            }
        } catch {
            print("Fetch time entries error: \(error)")
        }
        return result
    }

    func fetchTimeEntries(for date: Date, projectFilterId: Int64? = nil) -> [TimeEntry] {
        var result: [TimeEntry] = []
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            var query = timeEntries
                .filter(startDate >= startOfDay && startDate < endOfDay)
                .order(startDate.asc)

            if let projectFilterId {
                query = query.filter(projectId == projectFilterId)
            }

            for row in try db!.prepare(query) {
                result.append(TimeEntry(
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
                ))
            }
        } catch {
            print("Fetch time entries for date error: \(error)")
        }
        return result
    }

    func fetchTimeEntries(from start: Date, to end: Date, projectFilterId: Int64? = nil) -> [TimeEntry] {
        var result: [TimeEntry] = []
        do {
            var query = timeEntries
                .filter(startDate >= start && startDate < end)
                .order(startDate.asc)

            if let projectFilterId {
                query = query.filter(projectId == projectFilterId)
            }

            for row in try db!.prepare(query) {
                result.append(TimeEntry(
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
                ))
            }
        } catch {
            print("Fetch time entries range error: \(error)")
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
            postWorkspaceChanged()
            return rowId
        } catch {
            print("Insert time entry error: \(error)")
            return nil
        }
    }

    func updateTimeEntry(_ entry: TimeEntry) {
        guard let entryIdentifier = entry.id else { return }

        do {
            let entryRow = timeEntries.filter(id == entryIdentifier)
            try db?.run(entryRow.update(
                name <- entry.name,
                notes <- entry.notes,
                projectId <- entry.projectId,
                categoryId <- entry.categoryId,
                startDate <- entry.startDate,
                endDate <- entry.endDate,
                updatedAt <- Date(),
                syncProvider <- entry.syncProvider?.rawValue,
                syncCalendarIdentifier <- entry.syncCalendarIdentifier,
                calendarEventIdentifier <- entry.syncEventIdentifier
            ))
            postWorkspaceChanged()
        } catch {
            print("Update time entry error: \(error)")
        }
    }

    func deleteTimeEntry(_ entry: TimeEntry) {
        guard let entryIdentifier = entry.id else { return }

        do {
            let entryRow = timeEntries.filter(id == entryIdentifier)
            try db?.run(entryRow.delete())
            postWorkspaceChanged()
        } catch {
            print("Delete time entry error: \(error)")
        }
    }

    func nextRecordingName(for projectIdentifier: Int64) -> String {
        let allNames = fetchFamousPeopleNames()
        guard !allNames.isEmpty else { return "Recording" }

        let usedNames = Set(
            fetchAllTimeEntries(projectFilterId: projectIdentifier)
                .map(\.name)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )

        let availableNames = allNames.filter { !usedNames.contains($0) }
        return (availableNames.randomElement() ?? allNames.randomElement()) ?? "Recording"
    }

    private func fetchFamousPeopleNames() -> [String] {
        var names: [String] = []

        do {
            for row in try db!.prepare(famousNames.order(famousPersonName.asc)) {
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

    // MARK: - Sync Settings

    func syncSetting(forKey key: String) -> String? {
        do {
            let query = "SELECT value FROM sync_settings WHERE key = ?"
            return try db?.scalar(query, key) as? String
        } catch {
            print("Sync setting read error: \(error)")
            return nil
        }
    }

    func setSyncSetting(_ value: String?, forKey key: String) {
        do {
            if let value {
                try db?.run("INSERT OR REPLACE INTO sync_settings (key, value) VALUES (?, ?)", key, value)
            } else {
                try db?.run("DELETE FROM sync_settings WHERE key = ?", key)
            }
        } catch {
            print("Sync setting write error: \(error)")
        }
    }

    func removeSyncSetting(forKey key: String) {
        setSyncSetting(nil, forKey: key)
    }

    func appSetting(forKey key: String) -> String? {
        syncSetting(forKey: key)
    }

    func setAppSetting(_ value: String?, forKey key: String) {
        setSyncSetting(value, forKey: key)
    }

    // MARK: - Running Timer State

    func saveRunningTimerState(name: String, notes: String, projectId: Int64, categoryId: Int64?, startDate: Date) {
        UserDefaults.standard.set(name, forKey: "running_timer_name")
        UserDefaults.standard.set(notes, forKey: "running_timer_notes")
        UserDefaults.standard.set(projectId, forKey: "running_timer_projectId")
        UserDefaults.standard.set(categoryId, forKey: "running_timer_categoryId")
        UserDefaults.standard.set(startDate, forKey: "running_timer_startDate")
    }

    func getRunningTimerState() -> (name: String, notes: String, projectId: Int64, categoryId: Int64?, startDate: Date)? {
        guard UserDefaults.standard.object(forKey: "running_timer_projectId") != nil,
              let startDate = UserDefaults.standard.object(forKey: "running_timer_startDate") as? Date else {
            return nil
        }

        let name = UserDefaults.standard.string(forKey: "running_timer_name") ?? ""
        let notes = UserDefaults.standard.string(forKey: "running_timer_notes") ?? ""
        let projectId = Int64(UserDefaults.standard.integer(forKey: "running_timer_projectId"))
        let categoryId: Int64?

        if UserDefaults.standard.object(forKey: "running_timer_categoryId") != nil {
            categoryId = Int64(UserDefaults.standard.integer(forKey: "running_timer_categoryId"))
        } else {
            categoryId = nil
        }

        return (name, notes, projectId, categoryId, startDate)
    }

    func clearRunningTimerState() {
        UserDefaults.standard.removeObject(forKey: "running_timer_name")
        UserDefaults.standard.removeObject(forKey: "running_timer_notes")
        UserDefaults.standard.removeObject(forKey: "running_timer_projectId")
        UserDefaults.standard.removeObject(forKey: "running_timer_categoryId")
        UserDefaults.standard.removeObject(forKey: "running_timer_startDate")
    }

    private func postWorkspaceChanged() {
        NotificationCenter.default.post(name: .workspaceDidChange, object: nil)
    }
}
