import SwiftUI

struct ProjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let project: Project?
    let onSave: (Project) -> Void

    @State private var name = ""
    @State private var scope = ""
    @State private var selectedColorHex = AppTheme.colorPalette.first ?? "#4A90D9"
    @State private var customColor = Color(hex: AppTheme.colorPalette.first ?? "#4A90D9")
    @State private var showingInlineColorWheel = false
    @State private var showingScopeEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
                    HStack(spacing: AppTheme.spacingMD) {
                        Circle()
                            .fill(Color(hex: selectedColorHex))
                            .frame(width: 14, height: 14)
                            .shadow(color: Color(hex: selectedColorHex).opacity(0.7), radius: 5)

                        TextField("Project name", text: $name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .textFieldStyle(.plain)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(AppTheme.spacingMD)
                    .fieldSurface(cornerRadius: AppTheme.cornerRadiusLarge)

                    DisclosureGroup(isExpanded: $showingScopeEditor) {
                        TextEditor(text: $scope)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(minHeight: 120)
                            .fieldSurface(cornerRadius: AppTheme.cornerRadiusLarge)
                            .padding(.top, AppTheme.spacingXS)
                    } label: {
                        HStack(spacing: AppTheme.spacingXS) {
                            AppTheme.sectionLabel("Scope")

                            if !scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                            showingScopeEditor.toggle()
                        }
                    }

                    VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
                        AppTheme.sectionLabel("Accent Color")

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: AppTheme.spacingSM) {
                            ForEach(AppTheme.colorPalette, id: \.self) { colorHex in
                                Button {
                                    selectedColorHex = colorHex
                                    customColor = Color(hex: colorHex)
                                    showingInlineColorWheel = false
                                } label: {
                                    Circle()
                                        .fill(Color(hex: colorHex))
                                        .frame(width: 34, height: 34)
                                        .shadow(color: Color(hex: colorHex).opacity(selectedColorHex == colorHex ? 0.6 : 0), radius: 6)
                                        .padding(4)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    selectedColorHex == colorHex ? AppTheme.textPrimary : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                        .animation(.easeOut(duration: 0.15), value: selectedColorHex)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                customColor = Color(hex: selectedColorHex)
                                showingInlineColorWheel.toggle()
                            } label: {
                                Circle()
                                    .fill(
                                        AngularGradient(
                                            colors: [
                                                .red,
                                                .orange,
                                                .yellow,
                                                .green,
                                                .blue,
                                                .purple,
                                                .pink,
                                                .red
                                            ],
                                            center: .center
                                        )
                                    )
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: "eyedropper.halffull")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .padding(4)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                showingInlineColorWheel || isCustomColorSelected
                                                    ? AppTheme.textPrimary
                                                    : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if showingInlineColorWheel {
                            InlineColorWheelPicker(color: $customColor)
                                .padding(.top, AppTheme.spacingSM)
                        }
                    }

                    Spacer()
                }
                .padding(AppTheme.spacingLG)
            }
            .navigationTitle(project == nil ? "New Project" : "Edit Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(project == nil ? "Create" : "Save") {
                        persistProject()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if let project {
                name = project.name
                scope = project.scope
                selectedColorHex = project.colorHex
            }
            customColor = Color(hex: selectedColorHex)
            showingInlineColorWheel = isCustomColorSelected
            showingScopeEditor = !scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .onChange(of: customColor) { value in
            selectedColorHex = value.hexString
        }
    }

    private var isCustomColorSelected: Bool {
        !AppTheme.colorPalette.contains(where: { $0.caseInsensitiveCompare(selectedColorHex) == .orderedSame })
    }

    private func persistProject() {
        let now = Date()
        let updatedProject = Project(
            id: project?.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            scope: scope.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: selectedColorHex,
            createdAt: project?.createdAt ?? now,
            updatedAt: now
        )

        onSave(updatedProject)
        dismiss()
    }
}

struct InlineColorWheelPicker: View {
    @Binding var color: Color

    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    @State private var isUpdatingFromPicker = false

    private let wheelSize: CGFloat = 168

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let radius = size / 2
                let indicator = indicatorOffset(radius: radius)

                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    .red,
                                    .yellow,
                                    .green,
                                    .cyan,
                                    .blue,
                                    .purple,
                                    .red
                                ],
                                center: .center
                            )
                        )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: radius
                            )
                        )

                    Circle()
                        .fill(Color.black.opacity(1 - brightness))

                    Circle()
                        .stroke(AppTheme.border, lineWidth: 1)

                    Circle()
                        .fill(color)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                        )
                        .offset(x: indicator.width, y: indicator.height)
                }
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateHueAndSaturation(
                                location: value.location,
                                size: CGSize(width: size, height: size)
                            )
                        }
                )
            }
            .frame(width: wheelSize, height: wheelSize)

            HStack(spacing: AppTheme.spacingSM) {
                Image(systemName: "sun.min.fill")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)

                Slider(value: Binding(
                    get: { brightness },
                    set: { newValue in
                        brightness = newValue
                        applyColorFromPicker()
                    }
                ), in: 0...1)

                Image(systemName: "sun.max.fill")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: 260)
        }
        .onAppear {
            syncFromColor(color)
        }
        .onChange(of: color) { newValue in
            if !isUpdatingFromPicker {
                syncFromColor(newValue)
            }
        }
    }

    private func indicatorOffset(radius: CGFloat) -> CGSize {
        let angle = hue * .pi * 2
        let distance = CGFloat(saturation) * radius
        return CGSize(
            width: cos(angle) * distance,
            height: sin(angle) * distance
        )
    }

    private func updateHueAndSaturation(location: CGPoint, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y

        let radius = min(size.width, size.height) / 2
        let distance = min(sqrt(dx * dx + dy * dy), radius)

        var angle = atan2(dy, dx)
        if angle < 0 {
            angle += (.pi * 2)
        }

        hue = angle / (.pi * 2)
        saturation = Double(distance / radius)
        applyColorFromPicker()
    }

    private func applyColorFromPicker() {
        isUpdatingFromPicker = true
        color = Color(
            hue: hue,
            saturation: saturation,
            brightness: brightness
        )
        DispatchQueue.main.async {
            isUpdatingFromPicker = false
        }
    }

    private func syncFromColor(_ source: Color) {
        guard let hsb = source.hsbComponents else {
            return
        }
        hue = Double(hsb.hue)
        saturation = Double(hsb.saturation)
        brightness = Double(hsb.brightness)
    }
}
