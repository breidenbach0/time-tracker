import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = WorkspaceViewModel()
    @State private var editingTarget: ProjectEditorTarget?
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
                }
                .padding(AppTheme.spacingLG)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            Text("Formatting")
                .font(.title3.weight(.bold))
                .foregroundColor(AppTheme.textPrimary)

            HStack(spacing: AppTheme.spacingMD) {
                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text("Date Format")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)

                    Picker("", selection: Binding(
                        get: { selectedDateFormat },
                        set: { dateFormatRawValue = $0.rawValue }
                    )) {
                        ForEach(DateDisplayFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text("Time Format")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)

                    Picker("", selection: Binding(
                        get: { selectedTimeFormat },
                        set: { timeFormatRawValue = $0.rawValue }
                    )) {
                        ForEach(TimeDisplayFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppTheme.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            HStack {
                Text("Projects")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button {
                    editingTarget = ProjectEditorTarget(project: nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            ForEach(viewModel.projects) { project in
                Button {
                    edit(project)
                } label: {
                    HStack(spacing: AppTheme.spacingMD) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: project.colorHex))
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.name)
                                .font(.title3.weight(.semibold))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)

                            if !project.scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(project.scope)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteProject(project)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.trailing, AppTheme.spacingMD)
                }
                .padding(.horizontal, AppTheme.spacingMD)
                .padding(.vertical, AppTheme.spacingSM)
                .background(AppTheme.surfaceMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
        }
        .padding(AppTheme.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
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

struct ProjectEditorTarget: Identifiable {
    let id = UUID()
    let project: Project?
}
