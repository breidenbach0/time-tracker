import SwiftUI

struct TimerView: View {
    @ObservedObject private var viewModel = TimerViewModel.shared
    @State private var showingAddSheet = false
    @State private var showingNotesEditor = false
    @FocusState private var isNameFocused: Bool
    @AppStorage(DisplayPreferenceKeys.timeFormat) private var timeFormatRawValue = TimeDisplayFormat.twentyFourHour.rawValue

    var body: some View {
        GeometryReader { geometry in
            let isCompactLayout = geometry.size.width < 720
            let contentPadding = isCompactLayout ? AppTheme.spacingMD : AppTheme.spacingLG
            let availableWidth = max(320, geometry.size.width - (contentPadding * 2))
            let workspaceWidth = min(isCompactLayout ? 420 : 760, availableWidth)

            ZStack {
                ambientGlow

                Group {
                    if isCompactLayout {
                        compactWorkspace(width: workspaceWidth)
                    } else {
                        regularWorkspace(width: workspaceWidth)
                    }
                }
                .padding(contentPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEntrySheet()
                .frame(minWidth: 680, minHeight: 520)
        }
        .onAppear {
            showingNotesEditor = !viewModel.entryNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .onChange(of: viewModel.entryNotes) { _ in
            if !viewModel.entryNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showingNotesEditor = true
            }
            viewModel.persistRunningTimerStateIfNeeded()
        }
        .onChange(of: viewModel.entryName) { _ in
            viewModel.persistRunningTimerStateIfNeeded()
        }
        .onChange(of: viewModel.selectedProjectId) { _ in
            viewModel.persistRunningTimerStateIfNeeded()
        }
    }

    /// Soft light in the project's color behind the glass; brighter while recording.
    private var ambientGlow: some View {
        RadialGradient(
            colors: [
                (viewModel.isRunning ? AppTheme.recording : projectTint).opacity(viewModel.isRunning ? 0.22 : 0.16),
                .clear
            ],
            center: UnitPoint(x: 0.5, y: 0.42),
            startRadius: 0,
            endRadius: 460
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.6), value: viewModel.isRunning)
        .animation(.easeInOut(duration: 0.6), value: viewModel.selectedProjectId)
    }

    private func compactWorkspace(width: CGFloat) -> some View {
        timerCard(showContext: true)
            .frame(width: width)
    }

    private func regularWorkspace(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
            timerCard(showContext: true)
        }
        .frame(width: width)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func timerCard(showContext: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
            if showContext {
                HStack {
                    Spacer()
                    contextRow
                }
            }

            recordingNameHeader
            notesSection

            clock
                .padding(.vertical, AppTheme.spacingSM)

            HStack(spacing: AppTheme.spacingMD) {
                Button(action: toggleRecording) {
                    Label(viewModel.isRunning ? "Stop" : "Start", systemImage: viewModel.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(viewModel.isRunning ? .white : AppTheme.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.glassCapsule(
                    tint: viewModel.isRunning ? AppTheme.recording.opacity(0.85) : AppTheme.accent.opacity(0.92)
                ))
                .disabled(!viewModel.canStartTimer && !viewModel.isRunning)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isRunning)

                Button(action: { showingAddSheet = true }) {
                    Label("Manual", systemImage: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.glassCapsule())
            }
            .glassGroup(spacing: AppTheme.spacingMD)
        }
        .padding(AppTheme.spacingXL)
        .cardSurface(cornerRadius: AppTheme.cornerRadiusXL + 6, fill: AppTheme.surface.opacity(0.7))
    }

    private var clock: some View {
        VStack(spacing: AppTheme.spacingSM) {
            statusLine

            TimelineView(.periodic(from: viewModel.startDate, by: 1)) { context in
                Text(viewModel.formattedElapsedTime(at: context.date))
                    .font(.system(size: 80, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(viewModel.isRunning ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .numericTextTransition()
                    .animation(.easeInOut(duration: 0.25), value: context.date)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var statusLine: some View {
        HStack(spacing: AppTheme.spacingSM) {
            PulsingDot(isActive: viewModel.isRunning, size: 7)

            Text(viewModel.isRunning ? "Recording since \(startTimeText)" : "Ready to record")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundColor(viewModel.isRunning ? AppTheme.textPrimary.opacity(0.85) : AppTheme.textSecondary)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isRunning)
    }

    private var recordingNameHeader: some View {
        TextField(
            "",
            text: $viewModel.entryName,
            prompt: Text(viewModel.recordingPreviewName).foregroundColor(AppTheme.textTertiary)
        )
        .textFieldStyle(.plain)
        .font(.system(size: 20, weight: .semibold, design: .rounded))
        .foregroundColor(AppTheme.textPrimary)
        .focused($isNameFocused)
        .padding(.horizontal, AppTheme.spacingMD)
        .frame(height: 50)
        .fieldSurface(cornerRadius: AppTheme.cornerRadiusLarge, isFocused: isNameFocused)
    }

    private var notesSection: some View {
        RecordingNotesEditor(
            notes: $viewModel.entryNotes,
            isExpanded: $showingNotesEditor
        )
    }

    private var contextRow: some View {
        HStack(spacing: AppTheme.spacingSM) {
            projectMenuPill
        }
    }

    private var projectMenuPill: some View {
        Menu {
            ForEach(viewModel.projects) { project in
                Button {
                    viewModel.selectProject(project.id)
                } label: {
                    Label(
                        project.name,
                        systemImage: project.id == viewModel.selectedProjectId ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        } label: {
            contextPill(
                text: viewModel.selectedProject?.name ?? "No Project",
                tint: projectTint
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    private func contextPill(text: String, tint: Color) -> some View {
        HStack(spacing: AppTheme.spacingSM) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .shadow(color: tint.opacity(0.8), radius: 4)

            Text(text)
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppTheme.textSecondary)
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundColor(AppTheme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, AppTheme.spacingSM)
        .glassSurface(in: Capsule(style: .continuous), tint: tint.opacity(0.16), interactive: true)
    }

    private var projectTint: Color {
        Color(hex: viewModel.selectedProject?.colorHex ?? "#6F6F6F")
    }

    private var startTimeText: String {
        let format = TimeDisplayFormat(rawValue: timeFormatRawValue) ?? .twentyFourHour
        return DisplayFormatter.timeFormatter(for: format).string(from: viewModel.startDate)
    }

    private func toggleRecording() {
        if viewModel.isRunning {
            _ = viewModel.stopTimer()
        } else {
            viewModel.startTimer()
        }
    }
}
