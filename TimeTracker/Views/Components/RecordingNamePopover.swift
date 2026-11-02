import SwiftUI

struct RecordingNamePopover: View {
    let title: String
    @Binding var text: String
    let autoName: String
    let onUseAutoName: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Leave it blank and TimeTracker will save this as \(autoName).")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }

            TextField("Recording name", text: $text)
                .textFieldStyle(.plain)
                .padding(AppTheme.spacingMD)
                .background(AppTheme.surfaceMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
                .focused($isFocused)
                .onSubmit(onSave)

            HStack {
                Button("Use Auto Name", action: onUseAutoName)
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.accentWarm)

                Spacer()

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppTheme.spacingLG)
        .frame(width: 360)
        .background(AppTheme.primary)
        .onAppear {
            DispatchQueue.main.async {
                isFocused = true
            }
        }
    }
}
