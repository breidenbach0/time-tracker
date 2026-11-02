import SwiftUI

struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: Category?
    let onSave: (Category) -> Void

    @State private var name = ""
    @State private var selectedColorHex = AppTheme.colorPalette.dropFirst().first ?? "#38D2AE"

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primary.ignoresSafeArea()

                VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
                    TextField("Category name", text: $name)
                        .font(.title3.weight(.semibold))
                        .textFieldStyle(.plain)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding()
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))

                    VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                        Text("Color")
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: AppTheme.spacingSM) {
                            ForEach(AppTheme.colorPalette, id: \.self) { colorHex in
                                Button {
                                    selectedColorHex = colorHex
                                } label: {
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                        .fill(Color(hex: colorHex))
                                        .frame(height: 34)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                                .stroke(
                                                    selectedColorHex == colorHex ? AppTheme.textPrimary : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(AppTheme.spacingLG)
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(category == nil ? "Create" : "Save") {
                        persistCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if let category {
                name = category.name
                selectedColorHex = category.colorHex
            }
        }
    }

    private func persistCategory() {
        onSave(Category(
            id: category?.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: selectedColorHex,
            isDefault: false,
            sourceCalendarIdentifier: category?.sourceCalendarIdentifier
        ))
        dismiss()
    }
}
