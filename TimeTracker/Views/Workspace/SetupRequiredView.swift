import SwiftUI

struct SetupRequiredView: View {
    @StateObject private var viewModel = WorkspaceViewModel()
    @State private var showingProjectSheet = false

    var body: some View {
        ZStack {
            AppTheme.primary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
                Spacer()

                VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
                    Image(systemName: "timer")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 60, height: 60)
                        .glassSurface(in: Circle())

                    Text("Start with a project")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Recordings belong to a project. Create one to get going.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
                    setupStep(number: 1, title: "Create your first project")
                    setupStep(number: 2, title: "Start recording")
                    setupStep(number: 3, title: "Review recordings as a list or calendar")
                }
                .padding(AppTheme.spacingLG)
                .frame(maxWidth: 460, alignment: .leading)
                .cardSurface(cornerRadius: AppTheme.cornerRadiusXL)

                Button {
                    showingProjectSheet = true
                } label: {
                    Label("Create Project", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.onAccent)
                        .padding(.horizontal, AppTheme.spacingLG)
                        .frame(height: 46)
                }
                .buttonStyle(.glassCapsule(tint: AppTheme.accent.opacity(0.92)))
                .keyboardShortcut(.defaultAction)

                Spacer()
            }
            .padding(AppTheme.spacingXL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showingProjectSheet) {
            ProjectEditorSheet(project: nil) { project in
                viewModel.saveProject(project)
            }
        }
    }

    private func setupStep(number: Int, title: String) -> some View {
        HStack(spacing: AppTheme.spacingMD) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 26, height: 26)
                .background(AppTheme.surfaceAlt, in: Circle())
                .overlay(Circle().strokeBorder(AppTheme.border, lineWidth: 1))

            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}
