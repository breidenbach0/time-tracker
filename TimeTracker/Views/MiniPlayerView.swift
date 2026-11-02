import AppKit
import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject private var viewModel = TimerViewModel.shared
    @Environment(\.openWindow) private var openWindow
    @State private var showingProjectPicker = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                recordingField

                projectSelector

                TimelineView(.periodic(from: viewModel.startDate, by: 1)) { context in
                    Text(viewModel.formattedElapsedTime(at: context.date))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .monospacedDigit()
                        .fixedSize()
                }

                Button(action: toggleRecording) {
                    Image(systemName: viewModel.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(AppTheme.primary)
                        .frame(width: 28, height: 28)
                        .background(Color(hex: "#2DA9F7"))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canStartTimer && !viewModel.isRunning)

                Button(action: showMainWindow) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open full window")
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .frame(width: 650, height: 48)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.surfaceAlt.opacity(0.96))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .frame(width: 680, height: 74)
        .configureMiniPlayerWindow()
        .onAppear {
            viewModel.loadWorkspace()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workspaceDidChange)) { _ in
            viewModel.loadWorkspace()
        }
        .onChange(of: viewModel.entryName) { _ in
            viewModel.persistRunningTimerStateIfNeeded()
        }
    }

    private var recordingField: some View {
        TextField(
            "",
            text: $viewModel.entryName,
            prompt: Text(viewModel.recordingPreviewName).foregroundColor(AppTheme.textSecondary)
        )
        .textFieldStyle(.plain)
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundColor(AppTheme.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var projectSelector: some View {
        Button {
            showingProjectPicker.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(projectTint)
                    .frame(width: 6, height: 6)

                Text(viewModel.selectedProject?.name ?? "Noch kein Projekt")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: 140, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(projectTint.opacity(0.24))
            .clipShape(Capsule(style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .popover(isPresented: $showingProjectPicker, arrowEdge: .bottom) {
            MiniPlayerProjectPicker(
                projects: viewModel.projects,
                selectedProjectId: viewModel.selectedProjectId,
                onSelect: { projectId in
                    viewModel.selectProject(projectId)
                    showingProjectPicker = false
                }
            )
        }
    }

    private var projectTint: Color {
        Color(hex: viewModel.selectedProject?.colorHex ?? "#8A8A8A")
    }

    private func toggleRecording() {
        if viewModel.isRunning {
            _ = viewModel.stopTimer()
        } else {
            viewModel.startTimer()
        }
    }

    private func showMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.windows
                .filter { $0.identifier?.rawValue == "TimeTrackerMiniPlayer" }
                .forEach { $0.close() }
        }
    }
}

private struct MiniPlayerProjectPicker: View {
    let projects: [Project]
    let selectedProjectId: Int64?
    let onSelect: (Int64?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            ForEach(projects) { project in
                Button {
                    onSelect(project.id)
                } label: {
                    HStack(spacing: AppTheme.spacingSM) {
                        Circle()
                            .fill(Color(hex: project.colorHex))
                            .frame(width: 8, height: 8)

                        Text(project.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: AppTheme.spacingMD)

                        if project.id == selectedProjectId {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingMD)
                    .frame(height: 34)
                    .background(project.id == selectedProjectId ? AppTheme.surfaceAlt : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.spacingSM)
        .frame(width: 220)
        .background(AppTheme.surface)
    }
}
