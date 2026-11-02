import SwiftUI

struct AddEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let editingEntry: TimeEntry?
    let onSave: (() -> Void)?

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

    init(editingEntry: TimeEntry? = nil, onSave: (() -> Void)? = nil) {
        self.editingEntry = editingEntry
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            AppTheme.primary.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
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

                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .fill(AppTheme.border)
                    .frame(height: 1)

                footer
            }
            .frame(width: 680)
            .frame(minHeight: 640, maxHeight: 760)
            .background(AppTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
        .frame(minWidth: 660, minHeight: 640)
        .onAppear {
            loadProjects()

            if let editingEntry {
                populate(from: editingEntry)
            } else {
                projectId = projects.first?.id
                dateInput = dateFormatter.string(from: Date())
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
            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var nameHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            TextField(
                "",
                text: $name,
                prompt: Text(autoNameHint)
                    .foregroundColor(AppTheme.textSecondary.opacity(0.58))
            )
            .textFieldStyle(.plain)
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .focused($focusedField, equals: .name)

            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            Text("Project")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)

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
            Text("Date")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)

            TextField(datePlaceholder, text: $dateInput)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, AppTheme.spacingMD)
                .padding(.vertical, 14)
                .background(AppTheme.surfaceMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                        .stroke(isDateValid ? AppTheme.border : Color.red.opacity(0.55), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
                .focused($focusedField, equals: .date)
        }
    }

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            Text("Worked Hours")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)

            WorkRangeDial(
                startMinutes: $startMinutes,
                endMinutes: $endMinutes,
                timeFormatter: timeFormatter
            )
            .frame(maxWidth: .infinity)
        }
    }

    private var footer: some View {
        HStack(spacing: AppTheme.spacingSM) {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.bordered)
            .frame(minWidth: 120)

            Spacer()

            Button {
                saveEntry()
            } label: {
                Label(
                    editingEntry == nil ? "Add Recording" : "Save Recording",
                    systemImage: editingEntry == nil ? "plus" : "checkmark"
                )
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .foregroundColor(AppTheme.primary)
            .frame(minWidth: 190)
            .disabled(projectId == nil || !isDateValid || workedDurationMinutes <= 0)
        }
        .padding(.horizontal, AppTheme.spacingLG)
        .padding(.vertical, AppTheme.spacingMD)
        .background(AppTheme.primary)
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
        projects = DatabaseManager.shared.fetchAllProjects()
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

        autoNameHint = DatabaseManager.shared.nextRecordingName(for: projectId)
    }

    private func saveEntry() {
        guard let projectId, let parsedDate else { return }

        let startDate = combine(date: parsedDate, minutes: startMinutes)
        var endDate = combine(date: parsedDate, minutes: endMinutes)

        if endDate <= startDate {
            endDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        }

        let resolvedName = trimmedName.isEmpty ? autoNameHint : trimmedName

        _ = RecordingStore.shared.saveEntry(TimeEntry(
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

        onSave?()
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

private struct WorkRangeDial: View {
    @Binding var startMinutes: Int
    @Binding var endMinutes: Int
    let timeFormatter: DateFormatter

    @State private var activeHandle: Handle?

    private enum Handle {
        case start
        case end
    }

    private let totalMinutes = 24 * 60
    private let stepMinutes = 5

    var body: some View {
        VStack(spacing: AppTheme.spacingSM) {
            HStack {
                timeBlock(title: "Stop", value: formattedTime(for: endMinutes), alignment: .leading)
                Spacer()
                timeBlock(title: "Start", value: formattedTime(for: startMinutes), alignment: .trailing)
            }

            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                let lineWidth = max(20, side * 0.088)
                let ringInset = lineWidth / 2 + 14
                let radius = (side / 2) - ringInset
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

                ZStack {
                    dotRing(radius: radius + 14, center: center)

                    Circle()
                        .stroke(AppTheme.surfaceMuted, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .frame(width: radius * 2, height: radius * 2)

                    RangeArcShape(startMinutes: startMinutes, endMinutes: endMinutes, totalMinutes: totalMinutes)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppTheme.textPrimary.opacity(0.95),
                                    AppTheme.accent.opacity(0.88)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: radius * 2, height: radius * 2)

                    Circle()
                        .fill(AppTheme.surface.opacity(0.94))
                        .frame(width: radius * 2 - lineWidth - 20, height: radius * 2 - lineWidth - 20)

                    innerClockLabels(radius: radius - lineWidth * 0.78, center: center)

                    handle(for: .start, center: center, radius: radius)
                    handle(for: .end, center: center, radius: radius)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateHandle(from: value.location, in: geometry.size)
                        }
                        .onEnded { _ in
                            activeHandle = nil
                        }
                )
            }
            .frame(height: 226)

            VStack(spacing: 4) {
                Text("Worked")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)

                Text(workedDurationText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var workedDurationMinutes: Int {
        (endMinutes - startMinutes + totalMinutes) % totalMinutes
    }

    private var workedDurationText: String {
        let hours = workedDurationMinutes / 60
        let minutes = workedDurationMinutes % 60
        return String(format: "%02dh %02dm", hours, minutes)
    }

    @ViewBuilder
    private func dotRing(radius: CGFloat, center: CGPoint) -> some View {
        ZStack {
            ForEach(0..<96, id: \.self) { index in
                let minute = index * 15
                Circle()
                    .fill(isMinuteWithinRange(minute) ? AppTheme.textPrimary.opacity(0.9) : AppTheme.border.opacity(0.9))
                    .frame(width: index.isMultiple(of: 4) ? 4 : 2.5, height: index.isMultiple(of: 4) ? 4 : 2.5)
                    .position(position(for: minute, center: center, radius: radius))
            }
        }
    }

    @ViewBuilder
    private func innerClockLabels(radius: CGFloat, center: CGPoint) -> some View {
        ZStack {
            clockMarker("12AM", minute: 0, center: center, radius: radius)
            clockMarker("6AM", minute: 6 * 60, center: center, radius: radius)
            clockMarker("12PM", minute: 12 * 60, center: center, radius: radius)
            clockMarker("6PM", minute: 18 * 60, center: center, radius: radius)
        }
    }

    @ViewBuilder
    private func clockMarker(_ title: String, minute: Int, center: CGPoint, radius: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
            .position(position(for: minute, center: center, radius: radius))
    }

    @ViewBuilder
    private func handle(for handle: Handle, center: CGPoint, radius: CGFloat) -> some View {
        let minute = handle == .start ? startMinutes : endMinutes
        let isActive = activeHandle == handle
        let handleRadius = max(14, radius * 0.12)

        Circle()
            .fill(handle == .start ? AppTheme.textPrimary : AppTheme.surfaceAlt)
            .overlay(
                Circle()
                    .stroke(AppTheme.primary.opacity(0.55), lineWidth: 1)
            )
            .frame(width: handleRadius * 1.45, height: handleRadius * 1.45)
            .shadow(color: .black.opacity(isActive ? 0.28 : 0.18), radius: isActive ? 12 : 8, x: 0, y: 4)
            .scaleEffect(isActive ? 1.06 : 1)
            .position(position(for: minute, center: center, radius: radius))
    }

    private func updateHandle(from location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y

        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 {
            degrees += 360
        }

        let rawMinutes = Int((degrees / 360) * Double(totalMinutes))
        let snappedMinutes = snap(rawMinutes)

        if activeHandle == nil {
            activeHandle = nearestHandle(to: snappedMinutes)
        }

        switch activeHandle {
        case .start:
            startMinutes = snappedMinutes
        case .end:
            endMinutes = snappedMinutes
        case .none:
            break
        }
    }

    private func nearestHandle(to minute: Int) -> Handle {
        let startDistance = circularDistance(from: minute, to: startMinutes)
        let endDistance = circularDistance(from: minute, to: endMinutes)
        return startDistance <= endDistance ? .start : .end
    }

    private func circularDistance(from lhs: Int, to rhs: Int) -> Int {
        let delta = abs(lhs - rhs)
        return min(delta, totalMinutes - delta)
    }

    private func isMinuteWithinRange(_ minute: Int) -> Bool {
        if startMinutes == endMinutes {
            return false
        }

        if startMinutes < endMinutes {
            return minute >= startMinutes && minute <= endMinutes
        }

        return minute >= startMinutes || minute <= endMinutes
    }

    private func snap(_ minute: Int) -> Int {
        let snapped = Int((Double(minute) / Double(stepMinutes)).rounded()) * stepMinutes
        let normalized = ((snapped % totalMinutes) + totalMinutes) % totalMinutes
        return normalized
    }

    private func position(for minute: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = angle(for: minute)
        return CGPoint(
            x: center.x + cos(angle.radians) * radius,
            y: center.y + sin(angle.radians) * radius
        )
    }

    private func angle(for minute: Int) -> Angle {
        let normalizedMinute = ((minute % totalMinutes) + totalMinutes) % totalMinutes
        return .degrees((Double(normalizedMinute) / Double(totalMinutes) * 360) - 90)
    }

    private func formattedTime(for minute: Int) -> String {
        var components = DateComponents()
        components.hour = minute / 60
        components.minute = minute % 60
        let date = Calendar.current.date(from: components) ?? Date()
        return timeFormatter.string(from: date)
    }

    private func timeBlock(title: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}

private struct RangeArcShape: Shape {
    let startMinutes: Int
    let endMinutes: Int
    let totalMinutes: Int

    func path(in rect: CGRect) -> Path {
        let duration = (endMinutes - startMinutes + totalMinutes) % totalMinutes
        guard duration > 0 else { return Path() }

        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let steps = max(12, duration / 5)

        var path = Path()

        for index in 0...steps {
            let progress = Double(index) / Double(steps)
            let minute = startMinutes + Int(Double(duration) * progress)
            let angle = Angle.degrees((Double(minute % totalMinutes) / Double(totalMinutes) * 360) - 90)
            let point = CGPoint(
                x: center.x + cos(angle.radians) * radius,
                y: center.y + sin(angle.radians) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

struct RecordingNotesEditor: View {
    @Binding var notes: String
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                TextEditor(text: $notes)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 96, maxHeight: 118)
                    .background(AppTheme.surfaceMuted)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
                    .padding(.top, AppTheme.spacingXS)
            },
            label: {
                HStack(spacing: AppTheme.spacingXS) {
                    Text("Notes")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)

                    if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Added")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.surfaceMuted)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    isExpanded.toggle()
                }
            }
        )
        .disclosureGroupStyle(.automatic)
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }
}
