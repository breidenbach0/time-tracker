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
            isExpanded: $showingNotesEditor,
            project: selectedProject,
            recordingName: trimmedName.isEmpty ? autoNameHint : trimmedName,
            durationText: workedDurationText
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

    private var workedDurationText: String {
        let hours = workedDurationMinutes / 60
        let minutes = workedDurationMinutes % 60
        return String(format: "%02dh %02dm", hours, minutes)
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

    let project: Project?
    let recordingName: String
    let durationText: String?

    @State private var isGenerating = false

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                ZStack(alignment: .topTrailing) {
                    TextEditor(text: $notes)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(.leading, 10)
                        .padding(.trailing, 44)
                        .padding(.vertical, 8)
                        .frame(minHeight: 96, maxHeight: 118)
                        .background(AppTheme.surfaceMuted)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))

                    Button {
                        generateNote()
                    } label: {
                        Image(systemName: isGenerating ? "hourglass" : "sparkles")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(isGenerating)
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    .help(NoteAISettings.currentModelHelpText())
                }
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

    private func generateNote() {
        isExpanded = true
        isGenerating = true

        Task {
            let generated = await NoteSuggestionService.generateNote(
                project: project,
                recordingName: recordingName,
                durationText: durationText,
                existingNotes: notes
            )

            await MainActor.run {
                notes = generated
                isGenerating = false
            }
        }
    }
}

enum NoteSuggestionService {
    static func generateNote(
        project: Project?,
        recordingName: String,
        durationText: String?,
        existingNotes: String
    ) async -> String {
        let fallback = fallbackNote(
            project: project,
            recordingName: recordingName,
            durationText: durationText,
            existingNotes: existingNotes
        )

        do {
            let generated = try await NoteLLMClient.generateNote(
                project: project,
                recordingName: recordingName,
                durationText: durationText,
                existingNotes: existingNotes
            )
            let cleaned = NoteLLMClient.cleanNoteText(generated)

            if !cleaned.isEmpty {
                await NoteMemoryStore.recordGeneratedNote(
                    cleaned,
                    project: project,
                    recordingName: recordingName,
                    durationText: durationText
                )
                return cleaned
            }
        } catch {
            print("AI note generation error: \(error)")
        }

        return fallback
    }

    private static func fallbackNote(
        project: Project?,
        recordingName: String,
        durationText: String?,
        existingNotes: String
    ) -> String {
        let trimmedExisting = existingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedExisting.isEmpty {
            return trimmedExisting
        }

        let scope = project?.scope.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let projectName = project?.name ?? "dieses Projekt"
        let duration = durationText.map { " fuer \($0)" } ?? ""

        if !scope.isEmpty {
            return "An \(projectName)\(duration) gearbeitet, mit Fokus auf \(scope)."
        }

        return "An \(recordingName)\(duration) gearbeitet."
    }
}

private enum NoteLLMProvider: String {
    case openRouter
    case inceptionLabs
    case google
    case anthropic
    case openAI
    case kimi
    case xAI
    case deepSeek
    case lmStudio

    var credentialKey: String {
        "llm_provider_credential_\(rawValue)"
    }

    var displayName: String {
        switch self {
        case .openRouter:
            return "OpenRouter"
        case .inceptionLabs:
            return "Inception Labs"
        case .google:
            return "Google"
        case .anthropic:
            return "Anthropic"
        case .openAI:
            return "OpenAI"
        case .kimi:
            return "Kimi"
        case .xAI:
            return "xAI"
        case .deepSeek:
            return "DeepSeek"
        case .lmStudio:
            return "LM Studio"
        }
    }

    var chatCompletionsURL: URL? {
        switch self {
        case .openRouter:
            return URL(string: "https://openrouter.ai/api/v1/chat/completions")
        case .inceptionLabs:
            return URL(string: "https://api.inceptionlabs.ai/v1/chat/completions")
        case .openAI:
            return URL(string: "https://api.openai.com/v1/chat/completions")
        case .kimi:
            return URL(string: "https://api.moonshot.ai/v1/chat/completions")
        case .xAI:
            return URL(string: "https://api.x.ai/v1/chat/completions")
        case .deepSeek:
            return URL(string: "https://api.deepseek.com/v1/chat/completions")
        case .google, .anthropic, .lmStudio:
            return nil
        }
    }
}

private struct NoteLLMConfiguration {
    let provider: NoteLLMProvider
    let model: String
    let credential: String

    static func current() throws -> NoteLLMConfiguration {
        guard let identity = DatabaseManager.shared.appSetting(forKey: "llm_summarizer_model_selected")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !identity.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }

        let parts = identity.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let provider = NoteLLMProvider(rawValue: parts[0]) else {
            throw URLError(.badURL)
        }

        guard let credential = DatabaseManager.shared.appSetting(forKey: provider.credentialKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !credential.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }

        return NoteLLMConfiguration(provider: provider, model: parts[1], credential: credential)
    }
}

enum NoteMemoryStore {
    static let defaultLimit = 6_000

    private static let memoryKey = "llm_note_memory"
    private static let memoryLimitKey = "llm_note_memory_limit"
    private static let minimumLimit = 1_500
    private static let maximumLimit = 24_000

    static var compactionThreshold: Int {
        Int(Double(limit()) * 0.85)
    }

    static func limit() -> Int {
        guard let saved = DatabaseManager.shared.appSetting(forKey: memoryLimitKey),
              let value = Int(saved) else {
            return defaultLimit
        }

        return min(max(value, minimumLimit), maximumLimit)
    }

    static func setLimit(_ value: Int) {
        let clamped = min(max(value, minimumLimit), maximumLimit)
        DatabaseManager.shared.setAppSetting("\(clamped)", forKey: memoryLimitKey)
    }

    static func memoryForPrompt() -> String {
        let memory = DatabaseManager.shared.appSetting(forKey: memoryKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return memory
    }

    static func displayMemory() -> String {
        memoryForPrompt()
    }

    static func clear() {
        DatabaseManager.shared.setAppSetting(nil, forKey: memoryKey)
    }

    static func recordGeneratedNote(
        _ note: String,
        project: Project?,
        recordingName: String,
        durationText: String?
    ) async {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = memoryEntry(
            note: trimmed,
            project: project,
            recordingName: recordingName,
            durationText: durationText
        )
        let current = memoryForPrompt()
        let updated = [current, entry]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")

        DatabaseManager.shared.setAppSetting(updated, forKey: memoryKey)
        await compactIfNeeded()
    }

    static func compactIfNeeded(force: Bool = false) async {
        let current = memoryForPrompt()
        let currentLimit = limit()
        guard !current.isEmpty else { return }
        guard force || current.count >= Int(Double(currentLimit) * 0.85) else { return }

        let target = max(minimumLimit, Int(Double(currentLimit) * 0.55))

        do {
            let compacted = try await NoteLLMClient.compactMemoryText(current, targetCharacters: target)
            let trimmed = enforceLimit(compacted, limit: currentLimit)
            DatabaseManager.shared.setAppSetting(trimmed, forKey: memoryKey)
        } catch {
            let compacted = localCompact(current, targetCharacters: target)
            DatabaseManager.shared.setAppSetting(enforceLimit(compacted, limit: currentLimit), forKey: memoryKey)
        }
    }

    private static func memoryEntry(
        note: String,
        project: Project?,
        recordingName: String,
        durationText: String?
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let projectName = project?.name ?? "Kein Projekt"
        let duration = durationText.map { " · \($0)" } ?? ""

        return """
        [\(formatter.string(from: Date()))] \(projectName) · \(recordingName)\(duration)
        \(note)
        """
    }

    private static func localCompact(_ memory: String, targetCharacters: Int) -> String {
        let entries = memory
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var kept: [String] = []
        var count = 0

        for entry in entries.reversed() {
            let projected = count + entry.count + 2
            if projected > targetCharacters { break }
            kept.insert(entry, at: 0)
            count = projected
        }

        let droppedCount = max(0, entries.count - kept.count)
        let prefix = droppedCount > 0
            ? "\(droppedCount) aeltere AI-Notiz\(droppedCount == 1 ? "" : "en") wurden verdichtet, damit Memory unter dem Limit bleibt."
            : ""

        return ([prefix] + kept)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func enforceLimit(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }

        let suffix = trimmed.suffix(limit)
        return "Memory wurde auf das harte Limit gekuerzt; der neueste Kontext bleibt erhalten.\n\(suffix)"
    }
}

private enum NoteLLMClient {
    private struct OpenAIChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }

    private struct OpenAIChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }

            let message: Message?
        }

        let choices: [Choice]
    }

    private struct AnthropicRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let max_tokens: Int
        let temperature: Double
        let system: String
        let messages: [Message]
    }

    private struct AnthropicResponse: Decodable {
        struct Content: Decodable {
            let text: String?
        }

        let content: [Content]
    }

    private struct GoogleRequest: Encodable {
        struct Content: Encodable {
            let role: String
            let parts: [Part]
        }

        struct Part: Encodable {
            let text: String
        }

        struct GenerationConfig: Encodable {
            let temperature: Double
            let maxOutputTokens: Int
        }

        let systemInstruction: Content
        let contents: [Content]
        let generationConfig: GenerationConfig
    }

    private struct GoogleResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String?
                }

                let parts: [Part]?
            }

            let content: Content?
        }

        let candidates: [Candidate]?
    }

    static func generateNote(
        project: Project?,
        recordingName: String,
        durationText: String?,
        existingNotes: String
    ) async throws -> String {
        let configuration = try NoteLLMConfiguration.current()
        let messages = noteMessages(
            project: project,
            recordingName: recordingName,
            durationText: durationText,
            existingNotes: existingNotes
        )
        let rawResponse: String

        switch configuration.provider {
        case .anthropic:
            rawResponse = try await generateAnthropic(configuration: configuration, messages: messages, maxTokens: 320)
        case .google:
            rawResponse = try await generateGoogle(configuration: configuration, messages: messages, maxTokens: 320)
        case .lmStudio:
            rawResponse = try await generateOpenAICompatible(
                configuration: configuration,
                url: try localChatCompletionsURL(from: configuration.credential),
                messages: messages,
                maxTokens: 320
            )
        default:
            guard let url = configuration.provider.chatCompletionsURL else {
                throw URLError(.badURL)
            }

            rawResponse = try await generateOpenAICompatible(configuration: configuration, url: url, messages: messages, maxTokens: 320)
        }

        let cleaned = cleanNoteText(rawResponse)
        guard needsGermanRepair(cleaned) else {
            return cleaned
        }

        return try await repairGermanNote(
            cleaned,
            configuration: configuration,
            project: project,
            recordingName: recordingName,
            durationText: durationText,
            existingNotes: existingNotes
        )
    }

    static func compactMemoryText(_ memory: String, targetCharacters: Int) async throws -> String {
        let configuration = try NoteLLMConfiguration.current()
        let messages = (
            system: """
            Du bist der Memory-Compactor fuer eine Zeiterfassungs-App.
            Verdichte die Memory auf hoechstens \(targetCharacters) Zeichen.
            Behalte Projektbegriffe, wiederkehrende Themen, erledigte Scope-Teile und Schreibstil.
            Entferne Wiederholungen und Details, die fuer zukuenftige Kurznotizen nicht mehr wichtig sind.
            Schreibe nur die kompakte Memory auf Deutsch, keine Erklaerung.
            """,
            user: memory
        )
        let maxTokens = min(1_000, max(260, targetCharacters / 3))

        switch configuration.provider {
        case .anthropic:
            return try await generateAnthropic(configuration: configuration, messages: messages, maxTokens: maxTokens)
        case .google:
            return try await generateGoogle(configuration: configuration, messages: messages, maxTokens: maxTokens)
        case .lmStudio:
            return try await generateOpenAICompatible(
                configuration: configuration,
                url: try localChatCompletionsURL(from: configuration.credential),
                messages: messages,
                maxTokens: maxTokens
            )
        default:
            guard let url = configuration.provider.chatCompletionsURL else {
                throw URLError(.badURL)
            }

            return try await generateOpenAICompatible(
                configuration: configuration,
                url: url,
                messages: messages,
                maxTokens: maxTokens
            )
        }
    }

    private static func noteMessages(
        project: Project?,
        recordingName: String,
        durationText: String?,
        existingNotes: String
    ) -> (system: String, user: String) {
        let projectName = project?.name ?? "Kein Projekt"
        let scope = project?.scope.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let notes = existingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let memory = NoteMemoryStore.memoryForPrompt()
        let rawSystemPrompt = NoteAISettings.systemPrompt()
        let resolvedSystemPrompt = rawSystemPrompt.replacingOccurrences(
            of: "@memory",
            with: memory.isEmpty ? "Keine Memory vorhanden." : memory
        )
        let mode = notes.isEmpty
            ? "Neue Notiz schreiben: Nutze Scope, Systemprompt und Memory."
            : "Vorhandene Notiz verbessern: Behalte Fakten, uebersetze bei Bedarf ins Deutsche und mache sie klarer."

        let system = """
        \(resolvedSystemPrompt)

        Harte Regeln fuer die AI-Notiz:
        - Ausgabe ausschliesslich auf Deutsch.
        - Kein Englisch, auch nicht einzelne Saetze oder Labels.
        - Wenn vorhandene Notizen Englisch enthalten, uebersetze und verbessere sie auf Deutsch.
        - Gib nur die fertige Notiz aus, ohne Ueberschrift, ohne Erklaerung, ohne Anfuehrungszeichen.
        """

        let user = """
        Aufgabe: \(mode)
        Aufzeichnungsname: \(recordingName)
        Projekt: \(projectName)
        Projekt-Scope: \(scope.isEmpty ? "Kein Scope hinterlegt." : scope)
        Dauer: \(durationText ?? "Unbekannt")
        Vorhandene Notiz: \(notes.isEmpty ? "Keine vorhandene Notiz." : notes)

        Schreibe jetzt nur die fertige deutsche Notiz.
        """

        return (system, user)
    }

    static func cleanNoteText(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```markdown", with: "")
                .replacingOccurrences(of: "```text", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let prefixes = [
            "Notiz:",
            "AI-Notiz:",
            "Statusnotiz:",
            "Note:",
            "Generated note:",
            "Here is the note:",
            "Output:"
        ]

        for prefix in prefixes where cleaned.lowercased().hasPrefix(prefix.lowercased()) {
            cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\"' \n\t"))
    }

    private static func needsGermanRepair(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        guard !lowercased.isEmpty else { return false }

        let englishPhrases = [
            "worked on",
            "focused on",
            "existing note",
            "project scope",
            "recording name",
            "generated note",
            "here is",
            "completed",
            "implemented",
            "updated",
            "improved",
            "reviewed",
            "fixed"
        ]

        if englishPhrases.contains(where: { lowercased.contains($0) }) {
            return true
        }

        let englishWords = [
            "the", "and", "with", "for", "from", "this", "that", "work", "worked",
            "project", "scope", "task", "tasks", "note", "notes", "duration", "recording"
        ]
        let tokens = lowercased
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let englishHits = tokens.filter { englishWords.contains($0) }.count

        return englishHits >= 3
    }

    private static func repairGermanNote(
        _ note: String,
        configuration: NoteLLMConfiguration,
        project: Project?,
        recordingName: String,
        durationText: String?,
        existingNotes: String
    ) async throws -> String {
        let projectName = project?.name ?? "Kein Projekt"
        let scope = project?.scope.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let messages = (
            system: """
            Du korrigierst AI-Notizen fuer eine Zeiterfassung.
            Die Ausgabe MUSS vollstaendig Deutsch sein.
            Uebersetze englische Teile, entferne Meta-Kommentare und gib nur die fertige Notiz aus.
            Bleibe sachlich, kurz und in der Vergangenheit.
            """,
            user: """
            Projekt: \(projectName)
            Projekt-Scope: \(scope.isEmpty ? "Kein Scope hinterlegt." : scope)
            Aufzeichnungsname: \(recordingName)
            Dauer: \(durationText ?? "Unbekannt")
            Vorhandene Notiz: \(existingNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Keine vorhandene Notiz." : existingNotes)
            Zu korrigierende Ausgabe: \(note)
            """
        )
        let repaired: String

        switch configuration.provider {
        case .anthropic:
            repaired = try await generateAnthropic(configuration: configuration, messages: messages, maxTokens: 260)
        case .google:
            repaired = try await generateGoogle(configuration: configuration, messages: messages, maxTokens: 260)
        case .lmStudio:
            repaired = try await generateOpenAICompatible(
                configuration: configuration,
                url: try localChatCompletionsURL(from: configuration.credential),
                messages: messages,
                maxTokens: 260
            )
        default:
            guard let url = configuration.provider.chatCompletionsURL else {
                throw URLError(.badURL)
            }
            repaired = try await generateOpenAICompatible(
                configuration: configuration,
                url: url,
                messages: messages,
                maxTokens: 260
            )
        }

        let cleaned = cleanNoteText(repaired)
        return cleaned.isEmpty ? note : cleaned
    }

    private static func generateOpenAICompatible(
        configuration: NoteLLMConfiguration,
        url: URL,
        messages: (system: String, user: String),
        maxTokens: Int
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if configuration.provider != .lmStudio {
            request.setValue("Bearer \(configuration.credential)", forHTTPHeaderField: "Authorization")
        }

        if configuration.provider == .openRouter {
            request.setValue("TimeTracker", forHTTPHeaderField: "X-Title")
        }

        request.httpBody = try JSONEncoder().encode(
            OpenAIChatRequest(
                model: normalizedModelID(configuration.model, provider: configuration.provider),
                messages: [
                    .init(role: "system", content: messages.system),
                    .init(role: "user", content: messages.user)
                ],
                temperature: 0.1,
                max_tokens: maxTokens
            )
        )

        let data = try await perform(request)
        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        return decoded.choices.first?.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func generateAnthropic(
        configuration: NoteLLMConfiguration,
        messages: (system: String, user: String),
        maxTokens: Int
    ) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(configuration.credential, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(
            AnthropicRequest(
                model: configuration.model,
                max_tokens: maxTokens,
                temperature: 0.1,
                system: messages.system,
                messages: [.init(role: "user", content: messages.user)]
            )
        )

        let data = try await perform(request)
        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return decoded.content.compactMap(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func generateGoogle(
        configuration: NoteLLMConfiguration,
        messages: (system: String, user: String),
        maxTokens: Int
    ) async throws -> String {
        let escapedModel = configuration.model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? configuration.model
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(escapedModel):generateContent?key=\(configuration.credential)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            GoogleRequest(
                systemInstruction: .init(role: "system", parts: [.init(text: messages.system)]),
                contents: [.init(role: "user", parts: [.init(text: messages.user)])],
                generationConfig: .init(temperature: 0.1, maxOutputTokens: maxTokens)
            )
        )

        let data = try await perform(request)
        let decoded = try JSONDecoder().decode(GoogleResponse.self, from: data)
        return decoded.candidates?
            .compactMap { $0.content?.parts?.compactMap(\.text).joined(separator: "\n") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }

    private static func localChatCompletionsURL(from endpoint: String) throws -> URL {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else {
            throw URLError(.badURL)
        }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("chat/completions") {
            guard let url = components.url else { throw URLError(.badURL) }
            return url
        }

        let base = path.hasSuffix("v1") ? path : [path, "v1"].filter { !$0.isEmpty }.joined(separator: "/")
        components.path = "/" + [base, "chat/completions"].filter { !$0.isEmpty }.joined(separator: "/")

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        return url
    }

    private static func normalizedModelID(_ modelID: String, provider: NoteLLMProvider) -> String {
        switch provider {
        case .lmStudio where modelID.hasPrefix("lmstudio/"):
            return "local-model"
        default:
            return modelID
        }
    }
}

enum NoteAISettings {
    private static let selectedModelKey = "llm_summarizer_model_selected"
    private static let systemPromptKey = "llm_note_system_prompt"
    private static let memoryKey = "llm_note_memory"

    static func systemPrompt() -> String {
        let saved = DatabaseManager.shared.appSetting(forKey: systemPromptKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return saved?.isEmpty == false ? saved! : NotePromptDefaults.systemPrompt
    }

    static func memory() -> String {
        NoteMemoryStore.memoryForPrompt()
    }

    static func currentModelHelpText() -> String {
        let identity = DatabaseManager.shared.appSetting(forKey: selectedModelKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let identity, !identity.isEmpty else {
            return "AI-Notiz · Kein externes Modell ausgewaehlt"
        }

        let parts = identity.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return "AI-Notiz · Modell: \(identity)"
        }

        return "AI-Notiz verbessern oder neu schreiben · Modell: \(displayProvider(parts[0])) / \(parts[1])"
    }

    private static func displayProvider(_ rawValue: String) -> String {
        switch rawValue {
        case "openRouter":
            return "OpenRouter"
        case "inceptionLabs":
            return "Inception Labs"
        case "google":
            return "Google"
        case "anthropic":
            return "Anthropic"
        case "openAI":
            return "OpenAI"
        case "kimi":
            return "Kimi"
        case "xAI":
            return "xAI"
        case "deepSeek":
            return "DeepSeek"
        case "lmStudio":
            return "LM Studio"
        default:
            return rawValue
        }
    }
}
