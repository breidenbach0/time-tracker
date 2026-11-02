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
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 640

            ZStack {
                AppTheme.primary.ignoresSafeArea()

                if hasProjects {
                    VStack(spacing: 0) {
                        AppChromeBar(
                            selectedSection: $selectedSection,
                            isCompact: isCompact,
                            openMiniPlayer: openMiniPlayer
                        )
                        currentSectionView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    SetupRequiredView()
                }
            }
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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppTheme.spacingMD) {
                if !isCompact {
                    miniPlayerButton
                }

                Spacer()

                if !isCompact {
                    HStack(spacing: AppTheme.spacingSM) {
                        ForEach(AppSection.allCases) { section in
                            Button(action: { selectedSection = section }) {
                                Image(systemName: section.systemImage)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(
                                        selectedSection == section
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary
                                    )
                                    .frame(width: 34, height: 34)
                                    .background(
                                        selectedSection == section
                                            ? AppTheme.accent
                                            : AppTheme.surface
                                    )
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, AppTheme.spacingMD)
            .padding(.trailing, AppTheme.spacingMD)
            .padding(.top, AppTheme.spacingSM)
            .padding(.bottom, AppTheme.spacingSM)

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
        .background(AppTheme.primary)
    }

    private var miniPlayerButton: some View {
        Button(action: openMiniPlayer) {
            Image(systemName: "pip.enter")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 34, height: 34)
                .background(AppTheme.surface)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Mini Player")
    }
}
