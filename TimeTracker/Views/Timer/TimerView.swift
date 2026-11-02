import SwiftUI

struct TimerView: View {
    @ObservedObject private var viewModel = TimerViewModel.shared
    @State private var showingAddSheet = false
    @State private var showingNotesEditor = false

    var body: some View {
        GeometryReader { geometry in
            let isCompactLayout = geometry.size.width < 720
            let contentPadding = isCompactLayout ? AppTheme.spacingMD : AppTheme.spacingLG
            let availableWidth = max(320, geometry.size.width - (contentPadding * 2))
            let workspaceWidth = min(isCompactLayout ? 420 : 860, availableWidth)

            ZStack {
                AppTheme.primary.ignoresSafeArea()

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
            AddEntrySheet {
                viewModel.loadWorkspace()
            }
            .frame(minWidth: 680, minHeight: 520)
        }
        .onAppear {
            viewModel.loadWorkspace()
            showingNotesEditor = !viewModel.entryNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .onReceive(NotificationCenter.default.publisher(for: .workspaceDidChange)) { _ in
            viewModel.loadWorkspace()
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

            TimelineView(.periodic(from: viewModel.startDate, by: 1)) { context in
                Text(viewModel.formattedElapsedTime(at: context.date))
                    .font(.system(size: 68, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(spacing: AppTheme.spacingMD) {
                Button(action: toggleRecording) {
                    Label(viewModel.isRunning ? "Stop" : "Start", systemImage: viewModel.isRunning ? "stop.fill" : "play.fill")
                        .font(.headline)
                        .foregroundColor(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(viewModel.isRunning ? AppTheme.accentWarm : AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusFull))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canStartTimer && !viewModel.isRunning)

                Button(action: { showingAddSheet = true }) {
                    Label("Manual", systemImage: "square.and.pencil")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusFull)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusFull))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.spacingLG)
    }

    private var recordingNameHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(
                "",
                text: $viewModel.entryName,
                prompt: Text(viewModel.recordingPreviewName).foregroundColor(AppTheme.textSecondary)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 19, weight: .semibold, design: .rounded))
            .padding(.horizontal, AppTheme.spacingMD)
            .frame(height: 42)
            .background(AppTheme.surfaceMuted)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        }
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
                systemImage: "folder",
                text: viewModel.selectedProject?.name ?? "No Project",
                tint: Color(hex: viewModel.selectedProject?.colorHex ?? "#6F6F6F")
            )
        }
        .buttonStyle(.plain)
    }

    private func contextPill(systemImage: String, text: String, tint: Color) -> some View {
        HStack(spacing: AppTheme.spacingXS) {
            Image(systemName: systemImage)
            Text(text)
                .lineLimit(1)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundColor(AppTheme.textPrimary)
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.vertical, AppTheme.spacingSM)
        .background(tint.opacity(0.34))
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.8), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private func toggleRecording() {
        if viewModel.isRunning {
            _ = viewModel.stopTimer()
        } else {
            viewModel.startTimer()
        }
    }
}
