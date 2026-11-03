import SwiftUI

struct AddEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let editingEntry: TimeEntry?
    /// For a new recording: the day it starts on (today if nil) and its project (the first if nil).
    let initialDate: Date?
    let initialProjectId: Int64?
    private let store = WorkspaceStore.shared

    @State private var name = ""
    @State private var notes = ""
    @State private var projectId: Int64?
    @State private var projects: [Project] = []
    @State private var autoNameHint = "Recording"
    @State private var dateInput = ""
    @State private var startMinutes = 9 * 60
    @State private var endMinutes = 10 * 60
    @State private var showingNotesEditor = false

    @AppStorage(DisplayPreferenceKeys.dateFormat) private var dateFormatRawValue = DateDisplayFormat.dayMonthYear.rawValue
    @AppStorage(DisplayPreferenceKeys.timeFormat) private var timeFormatRawValue = TimeDisplayFormat.twentyFourHour.rawValue

    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case date
    }

    init(editingEntry: TimeEntry? = nil, initialDate: Date? = nil, initialProjectId: Int64? = nil) {
        self.editingEntry = editingEntry
        self.initialDate = initialDate
        self.initialProjectId = initialProjectId
    }

    var body: some View {
        ZStack {
            AppBackdrop()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
                        topBar
                        nameHeader
                        notesSection
                        projectSection
                        dateSection
                        rangeSection
                    }
                    .padding(.horizontal, AppTheme.spacingLG)
                    .padding(.top, AppTheme.spacingMD)
                    .padding(.bottom, AppTheme.spacingMD)
                }

                Rectangle()
                    .fill(AppTheme.border)
                    .frame(height: 1)

                footer
            }
            .frame(width: 680)
            .frame(minHeight: 640, maxHeight: 760)
        }
        .frame(minWidth: 660, minHeight: 640)
        .onAppear {
            loadProjects()

            if let editingEntry {
                populate(from: editingEntry)
            } else {
                let preferredProject = projects.first { $0.id == initialProjectId }
                projectId = preferredProject?.id ?? projects.first?.id
                dateInput = dateFormatter.string(from: initialDate ?? Date())
                startMinutes = 9 * 60
                endMinutes = 10 * 60
            }

            refreshAutoNameHint()
            showingNotesEditor = !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .onChange(of: projectId) { _ in
            refreshAutoNameHint()
        }
    }

    private var topBar: some View {
        HStack {
            AppTheme.sectionLabel(editingEntry == nil ? "New Recording" : "Edit Recording")

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glassCircle())
        }
    }

    private var nameHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            TextField(
                "",
                text: $name,
                prompt: Text(autoNameHint)
                    .foregroundColor(AppTheme.textTertiary)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
            .focused($focusedField, equals: .name)

            Rectangle()
                .fill(focusedField == .name ? AppTheme.highlight : AppTheme.border)
                .frame(height: 1)
                .animation(.easeOut(duration: 0.15), value: focusedField)
        }
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            AppTheme.sectionLabel("Project")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.spacingSM) {
                    ForEach(projects) { project in
                        SelectablePill(
                            title: project.name,
                            colorHex: project.colorHex,
                            isSelected: project.id == projectId
                        ) {
                            projectId = project.id
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var notesSection: some View {
        RecordingNotesEditor(
            notes: $notes,
            isExpanded: $showingNotesEditor
        )
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            AppTheme.sectionLabel("Date")

            TextField(datePlaceholder, text: $dateInput)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, AppTheme.spacingMD)
                .padding(.vertical, 13)
                .fieldSurface(cornerRadius: AppTheme.cornerRadiusLarge, isFocused: focusedField == .date)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                        .strokeBorder(AppTheme.danger.opacity(isDateValid ? 0 : 0.6), lineWidth: 1)
                )
                .focused($focusedField, equals: .date)
        }
    }

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            AppTheme.sectionLabel("Worked Hours")

            WorkRangeDial(
                startMinutes: $startMinutes,
                endMinutes: $endMinutes,
                timeFormatter: timeFormatter,
                tint: Color(hex: selectedProject?.colorHex ?? "#F5F5F7")
            )
            .frame(maxWidth: .infinity)
            .padding(AppTheme.spacingLG)
            .cardSurface(cornerRadius: AppTheme.cornerRadiusXL, fill: AppTheme.surface.opacity(0.6))
        }
    }

    private var footer: some View {
        HStack(spacing: AppTheme.spacingSM) {
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 120, height: 40)
            }
            .buttonStyle(.glassCapsule())
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                saveEntry()
            } label: {
                Label(
                    editingEntry == nil ? "Add Recording" : "Save Recording",
                    systemImage: editingEntry == nil ? "plus" : "checkmark"
                )
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.onAccent)
                .frame(width: 190, height: 40)
            }
            .buttonStyle(.glassCapsule(tint: AppTheme.accent.opacity(0.92)))
            .keyboardShortcut(.defaultAction)
            .disabled(projectId == nil || !isDateValid || workedDurationMinutes <= 0)
        }
        .glassGroup(spacing: AppTheme.spacingSM)
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.vertical, AppTheme.spacingMD)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedDate: Date? {
        dateFormatter.date(from: dateInput.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isDateValid: Bool {
        parsedDate != nil
    }

    private var workedDurationMinutes: Int {
        let delta = (endMinutes - startMinutes + (24 * 60)) % (24 * 60)
        return delta
    }

    private var selectedProject: Project? {
        guard let projectId else { return nil }
        return projects.first { $0.id == projectId }
    }

    private func loadProjects() {
        projects = store.projects
    }

    private func populate(from entry: TimeEntry) {
        name = entry.name
        notes = entry.notes
        projectId = entry.projectId
        dateInput = dateFormatter.string(from: entry.startDate)
        startMinutes = minutesSinceMidnight(for: entry.startDate)

        if let endDate = entry.endDate {
            endMinutes = minutesSinceMidnight(for: endDate)
        } else {
            endMinutes = (startMinutes + 60) % (24 * 60)
        }
    }

    private func refreshAutoNameHint() {
        guard let projectId else {
            autoNameHint = "Recording"
            return
        }

        autoNameHint = store.nextRecordingName(for: projectId)
    }

    private func saveEntry() {
        guard let projectId, let parsedDate else { return }

        let startDate = combine(date: parsedDate, minutes: startMinutes)
        var endDate = combine(date: parsedDate, minutes: endMinutes)

        if endDate <= startDate {
            endDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        }

        let resolvedName = trimmedName.isEmpty ? autoNameHint : trimmedName

        store.saveEntry(TimeEntry(
            id: editingEntry?.id,
            name: resolvedName,
            notes: notes,
            projectId: projectId,
            categoryId: nil,
            startDate: startDate,
            endDate: endDate,
            createdAt: editingEntry?.createdAt ?? Date(),
            updatedAt: Date(),
            syncProvider: editingEntry?.syncProvider,
            syncCalendarIdentifier: editingEntry?.syncCalendarIdentifier,
            syncEventIdentifier: editingEntry?.syncEventIdentifier
        ))

        dismiss()
    }

    private func combine(date: Date, minutes: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = minutes / 60
        components.minute = minutes % 60
        return Calendar.current.date(from: components) ?? date
    }

    private func minutesSinceMidnight(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 9) * 60 + (components.minute ?? 0)
    }

    private var selectedDateFormat: DateDisplayFormat {
        DateDisplayFormat(rawValue: dateFormatRawValue) ?? .dayMonthYear
    }

    private var selectedTimeFormat: TimeDisplayFormat {
        TimeDisplayFormat(rawValue: timeFormatRawValue) ?? .twentyFourHour
    }

    private var dateFormatter: DateFormatter {
        DisplayFormatter.dateFormatter(for: selectedDateFormat)
    }

    private var timeFormatter: DateFormatter {
        DisplayFormatter.timeFormatter(for: selectedTimeFormat)
    }

    private var datePlaceholder: String {
        selectedDateFormat.title
    }
}
