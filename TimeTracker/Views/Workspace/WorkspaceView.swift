import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = WorkspaceViewModel()
    @State private var editingTarget: ProjectEditorTarget?
    @State private var projectPendingDeletion: Project?
    @ObservedObject private var updater = Updater.shared
    @AppStorage(DisplayPreferenceKeys.dateFormat) private var dateFormatRawValue = DateDisplayFormat.dayMonthYear.rawValue
    @AppStorage(DisplayPreferenceKeys.timeFormat) private var timeFormatRawValue = TimeDisplayFormat.twentyFourHour.rawValue

    var body: some View {
        ZStack {
            AppTheme.primary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    formattingSection
                    projectsSection
                    updatesSection
                }
                .padding(AppTheme.spacingLG)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $editingTarget) { target in
            ProjectEditorSheet(project: target.project) { project in
                viewModel.saveProject(project)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workspaceDidChange)) { _ in
            viewModel.loadData()
        }
        .confirmationDialog(
            "Delete \u{201C}\(projectPendingDeletion?.name ?? "")\u{201D}?",
            isPresented: Binding(
                get: { projectPendingDeletion != nil },
                set: { if !$0 { projectPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Project and Recordings", role: .destructive) {
                if let project = projectPendingDeletion {
                    viewModel.deleteProject(project)
                }
                projectPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                projectPendingDeletion = nil
            }
        } message: {
            Text("All recordings in this project are deleted too. This can\u{2019}t be undone.")
        }
        .alert("Settings", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var formattingSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
            AppTheme.sectionLabel("Formatting")

            HStack(spacing: AppTheme.spacingLG) {
                VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                    Text("Date Format")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)

                    GlassSegmentedControl(
                        options: DateDisplayFormat.allCases,
                        title: \.title,
                        selection: Binding(
                            get: { selectedDateFormat },
                            set: { dateFormatRawValue = $0.rawValue }
                        )
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                    Text("Time Format")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary)

                    GlassSegmentedControl(
                        options: TimeDisplayFormat.allCases,
                        title: \.title,
                        selection: Binding(
                            get: { selectedTimeFormat },
                            set: { timeFormatRawValue = $0.rawValue }
                        )
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppTheme.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: AppTheme.cornerRadiusXL)
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
            HStack {
                AppTheme.sectionLabel("Projects")

                Spacer()

                Button {
                    editingTarget = ProjectEditorTarget(project: nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glassCircle())
                .help("New Project")
            }

            VStack(spacing: AppTheme.spacingSM) {
                ForEach(viewModel.projects) { project in
                    projectRow(project)
                }
            }
        }
        .padding(AppTheme.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: AppTheme.cornerRadiusXL)
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
            AppTheme.sectionLabel("Updates")

            HStack(spacing: AppTheme.spacingMD) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TimeTracker \(updater.currentVersion?.description ?? "")")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Signed updates from GitHub, installed in place.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Button {
                    Task { await updater.check(userInitiated: true) }
                } label: {
                    Text("Check Now")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.horizontal, AppTheme.spacingMD)
                        .frame(height: 32)
                }
                .buttonStyle(.glassCapsule())
                .disabled(updater.isBusy)
            }

            Toggle(isOn: $updater.checksAutomatically) {
                Text("Check for updates automatically")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .toggleStyle(.switch)
            .tint(AppTheme.success)
        }
        .padding(AppTheme.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: AppTheme.cornerRadiusXL)
    }

    private func projectRow(_ project: Project) -> some View {
        let tint = Color(hex: project.colorHex)

        return Button {
            edit(project)
        } label: {
            HStack(spacing: AppTheme.spacingMD) {
                Circle()
                    .fill(tint)
                    .frame(width: 14, height: 14)
                    .shadow(color: tint.opacity(0.7), radius: 5)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    if !project.scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(project.scope)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 44)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            DeleteProjectButton {
                projectPendingDeletion = project
            }
        }
        .padding(.leading, AppTheme.spacingSM)
        .padding(.trailing, AppTheme.spacingSM)
        .padding(.vertical, AppTheme.spacingSM)
        .cardSurface(cornerRadius: AppTheme.cornerRadiusLarge, fill: AppTheme.surface.opacity(0.7))
        .hoverHighlight(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private func edit(_ project: Project) {
        editingTarget = ProjectEditorTarget(project: project)
    }

    private var selectedDateFormat: DateDisplayFormat {
        DateDisplayFormat(rawValue: dateFormatRawValue) ?? .dayMonthYear
    }

    private var selectedTimeFormat: TimeDisplayFormat {
        TimeDisplayFormat(rawValue: timeFormatRawValue) ?? .twentyFourHour
    }
}

/// Segmented control matching the app's glass chrome, with a sliding selection pill.
private struct GlassSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let title: KeyPath<Option, String>
    @Binding var selection: Option

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selection = option
                    }
                } label: {
                    Text(option[keyPath: title])
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? AppTheme.onAccent : AppTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(AppTheme.accent)
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .glassSurface(in: Capsule(style: .continuous))
        .fixedSize()
    }
}

/// Trash button that only turns red while hovered, so the list stays calm.
private struct DeleteProjectButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isHovered ? AppTheme.danger : AppTheme.textSecondary)
                .frame(width: 30, height: 30)
                .background(isHovered ? AppTheme.danger.opacity(0.14) : Color.clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Delete Project")
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

struct ProjectEditorTarget: Identifiable {
    let id = UUID()
    let project: Project?
}
