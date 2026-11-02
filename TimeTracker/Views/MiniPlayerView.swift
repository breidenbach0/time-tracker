import AppKit
import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject private var viewModel = TimerViewModel.shared
    @Environment(\.openWindow) private var openWindow
    @State private var showingProjectPicker = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                PulsingDot(isActive: viewModel.isRunning, size: 7)

                recordingField

                projectSelector

                TimelineView(.periodic(from: viewModel.startDate, by: 1)) { context in
                    Text(viewModel.formattedElapsedTime(at: context.date))
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(viewModel.isRunning ? AppTheme.textPrimary : AppTheme.textSecondary)
                        .monospacedDigit()
                        .numericTextTransition()
                        .animation(.easeInOut(duration: 0.25), value: context.date)
                        .fixedSize()
                }

                Button(action: toggleRecording) {
                    Image(systemName: viewModel.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(viewModel.isRunning ? .white : AppTheme.onAccent)
                        .frame(width: 30, height: 30)
                        // Solid fill: glass nested inside the glass capsule loses its tint.
                        .background(viewModel.isRunning ? AppTheme.recording : AppTheme.accent, in: Circle())
                        .shadow(color: (viewModel.isRunning ? AppTheme.recording : Color.black).opacity(0.35), radius: 4, y: 1)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canStartTimer && !viewModel.isRunning)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isRunning)

                Button(action: showMainWindow) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverHighlight(cornerRadius: 15)
                .help("Open full window")
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .frame(width: 650, height: 48)
            .background(
                // The window is borderless and clear, so blur the desktop ourselves under the glass.
                WindowGlassBackground(material: .hudWindow)
                    .overlay(AppTheme.canvas.opacity(0.45))
                    .clipShape(Capsule(style: .continuous))
            )
            .glassSurface(in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.edgeHighlight, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 5)
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
            prompt: Text(viewModel.recordingPreviewName).foregroundColor(AppTheme.textTertiary)
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
                    .frame(width: 7, height: 7)
                    .shadow(color: projectTint.opacity(0.8), radius: 3)

                Text(viewModel.selectedProject?.name ?? "No Project")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: 140, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(projectTint.opacity(0.2), in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).strokeBorder(projectTint.opacity(0.35), lineWidth: 1))
            .contentShape(Capsule(style: .continuous))
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
        VStack(alignment: .leading, spacing: 2) {
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
                    .background(
                        project.id == selectedProjectId ? AppTheme.surfaceAlt : Color.clear,
                        in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverHighlight(cornerRadius: AppTheme.cornerRadiusSmall)
            }
        }
        .padding(AppTheme.spacingSM)
        .frame(width: 220)
    }
}
