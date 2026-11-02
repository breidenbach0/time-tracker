import AppKit
import SwiftUI

private enum AppSection: String, CaseIterable, Identifiable {
    case record
    case recordings
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .record:
            return "Record"
        case .recordings:
            return "Recordings"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .record:
            return "record.circle"
        case .recordings:
            return "list.bullet.rectangle"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

struct MainTabView: View {
    @State private var selectedSection: AppSection = .record
    @State private var hasProjects = false
    @ObservedObject private var updater = Updater.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 640

            ZStack {
                AppBackdrop()

                if hasProjects {
                    VStack(spacing: 0) {
                        AppChromeBar(
                            selectedSection: $selectedSection,
                            isCompact: isCompact,
                            openMiniPlayer: openMiniPlayer
                        )
                        currentSectionView
                            .id(selectedSection)
                            .transition(.opacity)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .animation(.easeInOut(duration: 0.18), value: selectedSection)
                } else {
                    SetupRequiredView()
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            UpdateCard(updater: updater)
        }
        .alert("You’re Up to Date", isPresented: $updater.isShowingUpToDate) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("TimeTracker \(updater.currentVersion?.description ?? "") is the newest version.")
        }
        .onAppear(perform: refreshProjects)
        .onReceive(NotificationCenter.default.publisher(for: .workspaceDidChange)) { _ in
            refreshProjects()
        }
    }

    @ViewBuilder
    private var currentSectionView: some View {
        switch selectedSection {
        case .record:
            TimerView()
        case .recordings:
            EntriesListView()
        case .settings:
            SettingsView()
        }
    }

    private func refreshProjects() {
        hasProjects = !DatabaseManager.shared.fetchAllProjects().isEmpty
    }

    private func openMiniPlayer() {
        let mainWindow = NSApp.keyWindow
        openWindow(id: "miniplayer")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            mainWindow?.close()
        }
    }
}

private struct AppChromeBar: View {
    @Binding var selectedSection: AppSection
    let isCompact: Bool
    let openMiniPlayer: () -> Void

    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: AppTheme.spacingMD) {
            if !isCompact {
                miniPlayerButton
            }

            Spacer()

            if !isCompact {
                sectionSwitcher
            }

            if isCompact {
                miniPlayerButton

                Menu {
                    ForEach(AppSection.allCases) { section in
                        Button {
                            selectedSection = section
                        } label: {
                            Label(section.title, systemImage: section.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 34, height: 34)
                        .glassSurface(in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.top, AppTheme.spacingXS)
        .padding(.bottom, AppTheme.spacingSM)
    }

    private var sectionSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(AppSection.allCases) { section in
                let isSelected = selectedSection == section

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedSection = section
                    }
                } label: {
                    Image(systemName: section.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? AppTheme.onAccent : AppTheme.textSecondary)
                        .frame(width: 40, height: 30)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(AppTheme.accent)
                                    .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                            }
                        }
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .help(section.title)
            }
        }
        .padding(4)
        .glassSurface(in: Capsule(style: .continuous))
    }

    private var miniPlayerButton: some View {
        Button(action: openMiniPlayer) {
            Image(systemName: "pip.enter")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.glassCircle())
        .help("Mini Player")
    }
}
