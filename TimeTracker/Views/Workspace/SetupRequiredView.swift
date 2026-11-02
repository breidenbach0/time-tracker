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
                    Text("Start with a project")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
                    setupStep(title: "1. Create your first project")
                    setupStep(title: "2. Start recording")
                    setupStep(title: "3. Review recordings as a list or calendar")
                }
                .padding(AppTheme.spacingLG)
                .background(AppTheme.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))

                Button("Create Project") {
                    showingProjectSheet = true
                }
                .buttonStyle(.plain)
                .font(.headline)
                .foregroundColor(AppTheme.primary)
                .padding(.horizontal, AppTheme.spacingLG)
                .padding(.vertical, AppTheme.spacingMD)
                .background(AppTheme.accentBlue)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusFull))

                Spacer()
            }
            .padding(AppTheme.spacingXL)
        }
        .sheet(isPresented: $showingProjectSheet) {
            ProjectEditorSheet(project: nil) { project in
                viewModel.saveProject(project)
            }
        }
    }

    private func setupStep(title: String) -> some View {
        HStack(spacing: AppTheme.spacingSM) {
            Image(systemName: "checkmark.circle")
                .foregroundColor(AppTheme.textSecondary)
            Text(title)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}
