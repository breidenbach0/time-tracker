import SwiftUI

/// A recording's notes, folded away until there are some.
struct RecordingNotesEditor: View {
    @Binding var notes: String
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                TextEditor(text: $notes)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 96, maxHeight: 118)
                    .fieldSurface(cornerRadius: AppTheme.cornerRadiusLarge)
                    .padding(.top, AppTheme.spacingXS)
            },
            label: {
                HStack(spacing: AppTheme.spacingXS) {
                    AppTheme.sectionLabel("Notes")

                    if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Added")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.surfaceAlt, in: Capsule())
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
}
